import 'dart:async';

import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class GraphWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Graph';

  late double timeDisplayed;
  double? minValue;
  double? maxValue;
  late Color mainColor;

  late final List<double> _graphData;

  GraphWidget({
    super.key,
    required topic,
    period = Globals.defaultPeriod,
    this.timeDisplayed = 5.0,
    this.minValue,
    this.maxValue,
    this.mainColor = Colors.cyan,
  }) {
    super.topic = topic;
    super.period = period;

    init();
  }

  GraphWidget.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    topic = jsonData['topic'] ?? '';
    period = jsonData['period'] ?? Globals.defaultPeriod;
    timeDisplayed = jsonData['time_displayed'] ?? 5.0;
    minValue = jsonData['min_value'];
    maxValue = jsonData['max_value'];
    mainColor = Color(jsonData['color'] ?? Colors.cyan.value);

    init();
  }

  @override
  void init() {
    super.init();

    _graphData = [];

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

    return GraphWidgetGraph(
      initialData: _graphData,
      subscription: subscription,
      mainColor: mainColor,
      minValue: minValue,
      maxValue: maxValue,
    );
  }
}

class GraphWidgetGraph extends StatefulWidget {
  final NT4Subscription? subscription;
  final double? minValue;
  final double? maxValue;
  final Color mainColor;

  final List<double> initialData;

  const GraphWidgetGraph({
    super.key,
    required this.initialData,
    required this.subscription,
    required this.mainColor,
    this.minValue,
    this.maxValue,
  });

  @override
  State<GraphWidgetGraph> createState() => _GraphWidgetGraphState();
}

class _GraphWidgetGraphState extends State<GraphWidgetGraph> {
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

    subscriptionListener = widget.subscription?.periodicStream().listen((data) {
      if (data != null && data is double) {
        graphData.add(_GraphPoint(x: fakeXIndex.toDouble(), y: data));
        graphData.removeAt(0);

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
