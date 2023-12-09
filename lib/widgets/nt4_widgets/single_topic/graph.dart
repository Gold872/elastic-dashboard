import 'dart:async';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class GraphWidget extends NT4Widget {
  static const String widgetType = 'Graph';
  @override
  String type = widgetType;

  late double timeDisplayed;
  double? minValue;
  double? maxValue;
  late Color mainColor;

  List<double> _graphData = [];
  _GraphWidgetGraph? _graphWidget;

  GraphWidget({
    super.key,
    required super.topic,
    super.period = Settings.defaultGraphPeriod,
    this.timeDisplayed = 5.0,
    this.minValue,
    this.maxValue,
    this.mainColor = Colors.cyan,
  }) : super() {
    resetGraphData();
  }

  GraphWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    timeDisplayed = tryCast(jsonData['time_displayed']) ??
        tryCast(jsonData['visibleTime']) ??
        5.0;
    minValue = tryCast(jsonData['min_value']);
    maxValue = tryCast(jsonData['max_value']);
    mainColor = Color(tryCast(jsonData['color']) ?? Colors.cyan.value);

    resetGraphData();
  }

  @override
  void resetSubscription() {
    resetGraphData();

    super.resetSubscription();
  }

  void resetGraphData() {
    _graphData.clear();

    int graphSize = timeDisplayed ~/ period;

    for (int i = 0; i < graphSize; i++) {
      _graphData.add((minValue != null && minValue! > 0.0) ? minValue! : 0.0);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'time_displayed': timeDisplayed,
      'min_value': minValue,
      'max_value': maxValue,
      'color': mainColor.value,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogColorPicker(
                onColorPicked: (color) {
                  mainColor = color;

                  refresh();
                },
                label: 'Graph Color',
                initialColor: mainColor),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newTime = double.tryParse(value);

                if (newTime == null) {
                  return;
                }
                timeDisplayed = newTime;
                resetGraphData();
                refresh();
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.-]")),
              label: 'Time Displayed (Seconds)',
              initialText: timeDisplayed.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMinimum = double.tryParse(value);
                bool refreshGraph = newMinimum != minValue;

                minValue = newMinimum;

                if (refreshGraph) {
                  refresh();
                }
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.-]")),
              label: 'Minimum',
              initialText: minValue?.toString(),
              allowEmptySubmission: true,
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMaximum = double.tryParse(value);
                bool refreshGraph = newMaximum != maxValue;

                maxValue = newMaximum;

                if (refreshGraph) {
                  refresh();
                }
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
              label: 'Maximum',
              initialText: maxValue?.toString(),
              allowEmptySubmission: true,
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    resetGraphData();

    List<double>? currentGraphData = _graphWidget?.getCurrentData();

    if (currentGraphData != null &&
        currentGraphData.length == _graphData.length) {
      _graphData = currentGraphData;
    }

    _graphWidget = _GraphWidgetGraph(
      initialData: _graphData,
      subscription: subscription,
      mainColor: mainColor,
      minValue: minValue,
      maxValue: maxValue,
    );

    // Idk why this works but otherwise it doesn't ever rebuild ¯\_(ツ)_/¯
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        return _graphWidget!;
      },
    );
  }
}

class _GraphWidgetGraph extends StatefulWidget {
  final NT4Subscription? subscription;
  final double? minValue;
  final double? maxValue;
  final Color mainColor;

  final List<double> initialData;

  final List<_GraphPoint> _currentData = [];

  set currentData(List<_GraphPoint> data) {
    _currentData.clear();
    _currentData.addAll(data);
  }

  _GraphWidgetGraph({
    required this.initialData,
    required this.subscription,
    required this.mainColor,
    this.minValue,
    this.maxValue,
  });

  List<double> getCurrentData() {
    return _currentData.map((e) => e.y).toList();
  }

  @override
  State<_GraphWidgetGraph> createState() => _GraphWidgetGraphState();
}

class _GraphWidgetGraphState extends State<_GraphWidgetGraph> {
  ChartSeriesController? seriesController;
  late List<_GraphPoint> graphData;
  late StreamSubscription<Object?>? subscriptionListener;

  int fakeXIndex = 0;

  @override
  void initState() {
    super.initState();

    graphData = [];

    for (double y in widget.initialData) {
      graphData.add(_GraphPoint(x: fakeXIndex.toDouble(), y: y));
      fakeXIndex++;
    }

    widget.currentData = graphData;

    subscriptionListener = widget.subscription?.periodicStream().listen((data) {
      if (data != null) {
        graphData.add(
            _GraphPoint(x: fakeXIndex.toDouble(), y: tryCast(data) ?? 0.0));
        graphData.removeAt(0);

        widget.currentData = graphData;

        fakeXIndex++;

        seriesController?.updateDataSource(
          addedDataIndex: graphData.length - 1,
          removedDataIndex: 0,
        );
      }
    });
  }

  @override
  void dispose() {
    seriesController = null;
    subscriptionListener?.cancel();
    graphData.clear();

    super.dispose();
  }

  void resetGraphData() {
    graphData.clear();

    for (double y in widget.initialData) {
      graphData.add(_GraphPoint(x: fakeXIndex.toDouble(), y: y));
      fakeXIndex++;
    }
  }

  List<FastLineSeries<_GraphPoint, num>> getChartData() {
    return <FastLineSeries<_GraphPoint, num>>[
      FastLineSeries<_GraphPoint, num>(
        onRendererCreated: (controller) => seriesController = controller,
        color: widget.mainColor,
        width: 2.0,
        dataSource: graphData,
        xValueMapper: (value, index) {
          return value.x;
        },
        yValueMapper: (value, index) {
          return value.y;
        },
        animationDuration: 0.0,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialData.length != graphData.length) {
      resetGraphData();
    }
    return SfCartesianChart(
      series: getChartData(),
      margin: const EdgeInsets.only(top: 8.0),
      primaryXAxis: NumericAxis(
        labelStyle: const TextStyle(color: Colors.transparent),
        desiredIntervals: 5,
      ),
      primaryYAxis: NumericAxis(
        minimum: widget.minValue,
        maximum: widget.maxValue,
      ),
    );
  }
}

class _GraphPoint {
  final double x;
  final double y;

  const _GraphPoint({required this.x, required this.y});
}
