import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class Gyro extends StatelessWidget with NT4Widget {
  @override
  String type = 'Gyro';

  bool counterClockwisePositive = false;

  late String valueTopic;

  late NT4Subscription valueSubscription;

  Gyro({
    super.key,
    required topic,
    counterClockwisePositive,
    period = Globals.defaultPeriod,
  }) {
    super.topic = topic;
    super.period = period;

    init();
  }

  Gyro.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;
    counterClockwisePositive = jsonData['counter_clockwise_positive'] ?? false;

    init();
  }

  @override
  void init() {
    super.init();

    valueTopic = '$topic/Value';

    valueSubscription = nt4Connection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    nt4Connection.unSubscribe(valueSubscription);

    valueTopic = '$topic/Value';
    valueSubscription = nt4Connection.subscribe(valueTopic, super.period);
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    nt4Connection.unSubscribe(valueSubscription);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'counter_clockwise_positive': counterClockwisePositive,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Counter Clockwise Positive'),
            const SizedBox(width: 5),
            DialogToggleSwitch(
              initialValue: counterClockwisePositive,
              onToggle: (value) {
                counterClockwisePositive = value;

                refresh();
              },
            ),
          ],
        ),
      ),
    ];
  }

  double _wrapAngle(double angle) {
    if (angle < 0) {
      return ((angle % 360) + 360) % 360;
    } else {
      return angle % 360;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: valueSubscription.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(valueTopic),
      builder: (context, snapshot) {
        double value = (snapshot.data as double?) ?? 0.0;

        if (counterClockwisePositive) {
          value *= -1;
        }

        double angle = _wrapAngle(value);

        return Column(
          children: [
            Flexible(
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    pointers: [
                      NeedlePointer(
                        value: angle,
                        needleColor: Colors.red,
                        needleEndWidth: 5,
                        needleStartWidth: 1,
                        needleLength: 0.7,
                        knobStyle: const KnobStyle(
                          borderColor: Colors.grey,
                          borderWidth: 0.025,
                        ),
                      )
                    ],
                    axisLineStyle: const AxisLineStyle(
                      thickness: 5,
                    ),
                    axisLabelStyle: const GaugeTextStyle(
                      fontSize: 14,
                    ),
                    ticksPosition: ElementsPosition.outside,
                    labelsPosition: ElementsPosition.outside,
                    showTicks: true,
                    minorTicksPerInterval: 8,
                    interval: 45,
                    minimum: 0,
                    maximum: 360,
                    startAngle: 270,
                    endAngle: 270,
                  )
                ],
              ),
            ),
            Text(angle.toStringAsFixed(2),
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
      },
    );
  }
}
