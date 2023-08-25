import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GraphWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Graph';

  late double timeDisplayed;
  double? minValue;
  double? maxValue;
  late bool showFillBelowLine;
  late bool showLineGradient;
  late Color mainColor;
  late Color secondaryColor;

  late final List<double> _graphData;

  GraphWidget({
    super.key,
    required topic,
    period = Globals.defaultPeriod,
    this.timeDisplayed = 5.0,
    this.minValue,
    this.maxValue,
    this.showFillBelowLine = true,
    this.showLineGradient = true,
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
    showFillBelowLine = jsonData['fill_below_line'] ?? true;
    showLineGradient = jsonData['line_gradient'] ?? true;
    mainColor = Color(jsonData['color'] ?? Colors.cyan.value);

    init();
  }

  @override
  void init() {
    super.init();

    _graphData = [];

    resetGraphData();

    initColors();
  }

  @override
  void resetSubscription() {
    resetGraphData();

    super.resetSubscription();
  }

  void resetGraphData() {
    _graphData.clear();

    for (int i = 0; i < timeDisplayed ~/ period; i++) {
      _graphData.add((minValue != null && minValue! > 0.0) ? minValue! : 0.0);
    }
  }

  double wrapHue(double hue) {
    if (hue < 0) {
      return ((hue % 360) + 360) % 360;
    } else {
      return hue % 360;
    }
  }

  void initColors() {
    HSLColor baseColor = HSLColor.fromColor(mainColor);

    HSLColor lightColor = HSLColor.fromAHSL(
      baseColor.alpha,
      wrapHue(baseColor.hue + 20),
      baseColor.saturation,
      baseColor.lightness,
    );

    secondaryColor = lightColor.toColor();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'time_displayed': timeDisplayed,
      'min_value': minValue,
      'max_value': maxValue,
      'fill_below_line': showFillBelowLine,
      'line_gradient': showLineGradient,
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

                  initColors();

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
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogToggleSwitch(
              initialValue: showFillBelowLine,
              label: 'Show Fill Below Line',
              onToggle: (value) {
                showFillBelowLine = value;

                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogToggleSwitch(
              initialValue: showLineGradient,
              label: 'Show Line Gradient',
              onToggle: (value) {
                showLineGradient = value;

                refresh();
              },
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
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                color: (!showLineGradient) ? mainColor : null,
                gradient: (showLineGradient)
                    ? LinearGradient(colors: [
                        mainColor,
                        secondaryColor,
                      ])
                    : null,
                belowBarData: BarAreaData(
                  show: showFillBelowLine,
                  color:
                      (!showLineGradient) ? mainColor.withOpacity(0.3) : null,
                  gradient: (showLineGradient)
                      ? LinearGradient(colors: [
                          mainColor.withOpacity(0.3),
                          secondaryColor.withOpacity(0.3)
                        ])
                      : null,
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
