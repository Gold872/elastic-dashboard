import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class GraphWidget extends NTWidget {
  static const String widgetType = 'Graph';
  @override
  String type = widgetType;

  late double timeDisplayed;
  double? minValue;
  double? maxValue;
  late Color mainColor;

  List<_GraphPoint> _graphData = [];
  _GraphWidgetGraph? _graphWidget;

  GraphWidget({
    super.key,
    required super.topic,
    this.timeDisplayed = 5.0,
    this.minValue,
    this.maxValue,
    this.mainColor = Colors.cyan,
    super.dataType,
    super.period = Settings.defaultGraphPeriod,
  }) : super();

  GraphWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    timeDisplayed = tryCast(jsonData['time_displayed']) ??
        tryCast(jsonData['visibleTime']) ??
        5.0;
    minValue = tryCast(jsonData['min_value']);
    maxValue = tryCast(jsonData['max_value']);
    mainColor = Color(tryCast(jsonData['color']) ?? Colors.cyan.value);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
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
    notifier = context.watch<NTWidgetNotifier?>();

    List<_GraphPoint>? currentGraphData = _graphWidget?.getCurrentData();

    if (currentGraphData != null) {
      _graphData = currentGraphData;
    }

    _graphWidget = _GraphWidgetGraph(
      initialData: _graphData,
      subscription: subscription,
      timeDisplayed: timeDisplayed,
      mainColor: mainColor,
      minValue: minValue,
      maxValue: maxValue,
    );

    // Idk why this works but otherwise it doesn't ever rebuild ¯\_(ツ)_/¯
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

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
  final double timeDisplayed;

  final List<_GraphPoint> initialData;

  final List<_GraphPoint> _currentData = [];

  set currentData(List<_GraphPoint> data) {
    _currentData.clear();
    _currentData.addAll(data);
  }

  _GraphWidgetGraph({
    required this.initialData,
    required this.subscription,
    required this.timeDisplayed,
    required this.mainColor,
    this.minValue,
    this.maxValue,
  });

  List<_GraphPoint> getCurrentData() {
    return _currentData;
  }

  @override
  State<_GraphWidgetGraph> createState() => _GraphWidgetGraphState();
}

class _GraphWidgetGraphState extends State<_GraphWidgetGraph> {
  ChartSeriesController? seriesController;
  late List<_GraphPoint> graphData;
  late StreamSubscription<Object?>? subscriptionListener;

  @override
  void initState() {
    super.initState();

    graphData = widget.initialData;

    if (graphData.isEmpty) {
      graphData.add(const _GraphPoint(x: 0, y: 0));
    }

    widget.currentData = graphData;

    initializeListener();
  }

  @override
  void dispose() {
    seriesController = null;
    subscriptionListener?.cancel();

    super.dispose();
  }

  @override
  void didUpdateWidget(_GraphWidgetGraph oldWidget) {
    subscriptionListener?.cancel();
    initializeListener();

    super.didUpdateWidget(oldWidget);
  }

  void initializeListener() {
    subscriptionListener =
        widget.subscription?.timestampedStream(yieldAll: true).listen((data) {
      if (data.key != null) {
        List<int> addedIndexes = [];
        List<int> removedIndexes = [];

        graphData.add(
            _GraphPoint(x: data.value.toDouble(), y: tryCast(data.key) ?? 0.0));

        graphData.sort((a, b) => a.x.compareTo(b.x));

        int indexOffset = 0;

        while (data.value - graphData[0].x > widget.timeDisplayed * 1e6 &&
            graphData.length > 1) {
          graphData.removeAt(0);
          removedIndexes.add(indexOffset++);
        }

        int existingIndex = graphData.indexWhere((e) => e.x == data.value);
        while (existingIndex != -1 &&
            existingIndex != graphData.length - 1 &&
            graphData.length > 1) {
          removedIndexes.add(existingIndex + indexOffset++);
          graphData.removeAt(existingIndex);

          existingIndex = graphData.indexWhere((e) => e.x == data.value);
        }

        if (graphData.last.x - graphData.first.x < widget.timeDisplayed * 1e6) {
          graphData.insert(
              0,
              _GraphPoint(
                x: graphData.last.x - widget.timeDisplayed * 1e6,
                y: graphData.first.y,
              ));
          addedIndexes.add(0);
        }

        addedIndexes.add(graphData.length - 1);

        widget.currentData = graphData;

        seriesController?.updateDataSource(
          addedDataIndexes: addedIndexes,
          removedDataIndexes: removedIndexes,
        );
      }
    });
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
