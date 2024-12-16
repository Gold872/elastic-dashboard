import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class GyroModel extends MultiTopicNTWidgetModel {
  @override
  String type = Gyro.widgetType;

  String get valueTopic => '$topic/Value';

  late NT4Subscription valueSubscription;

  @override
  List<NT4Subscription> get subscriptions => [valueSubscription];

  bool _counterClockwisePositive = false;

  get counterClockwisePositive => _counterClockwisePositive;

  set counterClockwisePositive(value) {
    _counterClockwisePositive = value;
    refresh();
  }

  GyroModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool counterClockwisePositive = false,
    super.dataType,
    super.period,
  })  : _counterClockwisePositive = counterClockwisePositive,
        super();

  GyroModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _counterClockwisePositive =
        tryCast(jsonData['counter_clockwise_positive']) ?? false;
  }

  @override
  void initializeSubscriptions() {
    valueSubscription = ntConnection.subscribe(valueTopic, super.period);
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

    return ValueListenableBuilder(
      valueListenable: model.valueSubscription,
      builder: (context, data, child) {
        double value = tryCast(data) ?? 0.0;

        if (model.counterClockwisePositive) {
          value *= -1;
        }

        double angle = _wrapAngle(value);

        return Column(
          children: [
            Flexible(
              child: LayoutBuilder(builder: (context, constraints) {
                double squareSide =
                    min(constraints.maxWidth, constraints.maxHeight);

                // Formula taken from radial gauge source code
                final maxNeedleHeight = squareSide / (2 * 0.65) - (2 * 7.5);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    RadialGauge(
                      radiusFactor: 0.65,
                      track: RadialTrack(
                        thickness: 7.5,
                        start: 0,
                        end: 360,
                        startAngle: 90,
                        endAngle: 90 + 360,
                        steps: 360 ~/ 45,
                        color: const Color.fromRGBO(97, 97, 97, 1),
                        trackStyle: TrackStyle(
                            primaryRulerColor: Colors.grey,
                            secondaryRulerColor:
                                const Color.fromRGBO(97, 97, 97, 1),
                            labelStyle: Theme.of(context).textTheme.bodySmall,
                            primaryRulersHeight: 7.5,
                            primaryRulersWidth: 2,
                            secondaryRulersHeight: 7.5,
                            rulersOffset: -18,
                            labelOffset: -57.5,
                            showLastLabel: false,
                            secondaryRulerPerInterval: 8,
                            inverseRulers: true),
                        trackLabelFormater: (value) => value.toStringAsFixed(0),
                      ),
                      needlePointer: [
                        NeedlePointer(
                          needleWidth: squareSide * 0.03,
                          needleEndWidth: squareSide * 0.005,
                          needleHeight: maxNeedleHeight * 0.52 -
                              (squareSide - 175.875) * 0.075,
                          tailColor: Colors.grey,
                          tailRadius: squareSide * 0.1,
                          value: value,
                        ),
                      ],
                    ),
                    Container(
                      width: squareSide * 0.07,
                      height: squareSide * 0.07,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300]!,
                      ),
                    ),
                  ],
                );
              }),
            ),
            Text(angle.toStringAsFixed(2),
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        );
      },
    );
  }
}
