import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GraphWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Graph';

  final Color color;
  late double timeDisplayed;
  double? minValue;
  double? maxValue;
  late final List<double> _graphData;

  GraphWidget({
    super.key,
    required topic,
    period = Globals.defaultPeriod,
    this.timeDisplayed = 5.0,
    this.minValue,
    this.maxValue,
    this.color = Colors.lightBlue,
  }) {
    super.topic = topic;
    super.period = period;

    init();
  }

  GraphWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : color = Colors.lightBlue {
    topic = jsonData['topic'] ?? '';
    period = jsonData['period'] ?? Globals.defaultPeriod;
    timeDisplayed = jsonData['time_displayed'] ?? 5.0;
    minValue = jsonData['min_value'];
    maxValue = jsonData['max_value'];

    init();
  }

  @override
  void init() {
    super.init();

    _graphData = [];

    for (int i = 0; i < 5 ~/ period; i++) {
      _graphData.add(0.0);
    }
  }

  @override
  void resetSubscription() {
    resetGraphData();

    super.resetSubscription();
  }

  void resetGraphData() {
    _graphData.clear();

    for (int i = 0; i < timeDisplayed ~/ period; i++) {
      _graphData.add(0.0);
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
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogTextInput(
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

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          double value = snapshot.data as double;
          _graphData.add(value);
          _graphData.removeAt(0);
        }

        List<FlSpot> data = [];
        for (int i = 0; i < _graphData.length; i++) {
          data.add(FlSpot(period * i, _graphData[i]));
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              drawHorizontalLine: true,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.3),
                  strokeWidth: 1,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.3),
                  strokeWidth: 1,
                );
              },
            ),
            lineTouchData: const LineTouchData(
              enabled: false,
            ),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: Text('Time (Seconds)'),
                axisNameSize: 20,
                drawBelowEverything: true,
                sideTitles: SideTitles(showTitles: false, reservedSize: 26),
              ),
            ),
            minY: minValue,
            maxY: maxValue,
            minX: 0,
            lineBarsData: [
              LineChartBarData(
                spots: data,
                isStrokeCapRound: false,
                dotData: const FlDotData(show: false),
                color: Colors.cyan,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.lightBlueAccent.withOpacity(0.3)
                  ]),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 0),
        );
      },
    );
  }
}
