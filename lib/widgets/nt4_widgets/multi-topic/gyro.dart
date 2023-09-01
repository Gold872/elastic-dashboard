import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class Gyro extends StatelessWidget with NT4Widget {
  @override
  String type = 'Gyro';

  late String valueTopic;

  late NT4Subscription valueSubscription;

  Gyro(
      {super.key, required topic, valueTopic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    if (valueTopic == null) {
      this.valueTopic = topic + '/Value';
    } else {
      this.valueTopic = valueTopic!;
    }

    init();
  }

  Gyro.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;
    valueTopic = jsonData['value_topic'] ?? '${super.topic}/Value';

    init();
  }

  @override
  void init() {
    super.init();

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
      'value_topic': valueTopic,
    };
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
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        double value = (snapshot.data as double?) ?? 0.0;

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
            Text(value.toStringAsFixed(3),
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
      },
    );
  }
}
