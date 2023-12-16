import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class Gyro extends NTWidget {
  static const String widgetType = 'Gyro';
  @override
  String type = widgetType;

  bool counterClockwisePositive = false;

  late String valueTopic;

  late NT4Subscription valueSubscription;

  Gyro({
    super.key,
    required super.topic,
    counterClockwisePositive,
    super.dataType,
    super.period,
  }) : super() {
    if (counterClockwisePositive != null) {
      this.counterClockwisePositive = counterClockwisePositive;
    }
  }

  Gyro.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    counterClockwisePositive =
        tryCast(jsonData['counter_clockwise_positive']) ?? false;
  }

  @override
  void init() {
    super.init();

    valueTopic = '$topic/Value';

    valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(valueSubscription);

    valueTopic = '$topic/Value';
    valueSubscription = ntConnection.subscribe(valueTopic, super.period);

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    ntConnection.unSubscribe(valueSubscription);

    super.unSubscribe();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'counter_clockwise_positive': counterClockwisePositive,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: DialogToggleSwitch(
          initialValue: counterClockwisePositive,
          label: 'Counter Clockwise Positive',
          onToggle: (value) {
            counterClockwisePositive = value;

            refresh();
          },
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
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: valueSubscription.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(valueTopic),
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        double value = tryCast(snapshot.data) ?? 0.0;

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
