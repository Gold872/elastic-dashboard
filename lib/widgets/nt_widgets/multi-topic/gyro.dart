import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class GyroModel extends NTWidgetModel {
  @override
  String type = Gyro.widgetType;

  String get valueTopic => '$topic/Value';

  late NT4Subscription valueSubscription;

  bool _counterClockwisePositive = false;

  get counterClockwisePositive => _counterClockwisePositive;

  set counterClockwisePositive(value) {
    _counterClockwisePositive = value;
    refresh();
  }

  GyroModel(
      {required super.topic,
      bool counterClockwisePositive = false,
      super.dataType,
      super.period})
      : _counterClockwisePositive = counterClockwisePositive,
        super();

  GyroModel.fromJson({required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _counterClockwisePositive =
        tryCast(jsonData['counter_clockwise_positive']) ?? false;
  }

  @override
  void init() {
    super.init();

    valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(valueSubscription);

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
      'counter_clockwise_positive': _counterClockwisePositive,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: DialogToggleSwitch(
          initialValue: _counterClockwisePositive,
          label: 'Counter Clockwise Positive',
          onToggle: (value) {
            counterClockwisePositive = value;
          },
        ),
      ),
    ];
  }
}

class Gyro extends NTWidget {
  static const String widgetType = 'Gyro';

  const Gyro({super.key}) : super();

  double _wrapAngle(double angle) {
    if (angle < 0) {
      return ((angle % 360) + 360) % 360;
    } else {
      return angle % 360;
    }
  }

  @override
  Widget build(BuildContext context) {
    GyroModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.valueSubscription.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(model.valueTopic),
      builder: (context, snapshot) {
        double value = tryCast(snapshot.data) ?? 0.0;

        if (model.counterClockwisePositive) {
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
