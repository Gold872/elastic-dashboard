import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/swerve_module_state_struct.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/struct_swerve.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class YAGSLSwerveDriveModel extends MultiTopicNTWidgetModel {
  @override
  String type = YAGSLSwerveDrive.widgetType;

  String get measuredStatesTopic => '$topic/measuredStates';
  String get desiredStatesTopic => '$topic/desiredStates';
  String get robotRotationTopic => '$topic/robotRotation';
  String get maxSpeedTopic => '$topic/maxSpeed';
  String get robotWidthTopic => '$topic/sizeLeftRight';
  String get robotLengthTopic => '$topic/sizeFrontBack';
  String get rotationUnitTopic => '$topic/rotationUnit';

  late NT4Subscription measuredStatesSubscription;
  late NT4Subscription desiredStatesSubscription;
  late NT4Subscription robotRotationSubscription;
  late NT4Subscription maxSpeedSubscription;
  late NT4Subscription robotWidthSubscription;
  late NT4Subscription robotLengthSubscription;
  late NT4Subscription rotationUnitSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        measuredStatesSubscription,
        desiredStatesSubscription,
        robotRotationSubscription,
        maxSpeedSubscription,
        robotWidthSubscription,
        robotLengthSubscription,
        rotationUnitSubscription,
      ];

  bool _showRobotRotation = true;
  bool _showDesiredStates = true;
  double _angleOffset =
      0; // Modifiable angle offset to allow all kinds of swerve libraries setups

  bool get showRobotRotation => _showRobotRotation;

  set showRobotRotation(value) {
    _showRobotRotation = value;
    refresh();
  }

  bool get showDesiredStates => _showDesiredStates;

  set showDesiredStates(value) {
    _showDesiredStates = value;
    refresh();
  }

  double get angleOffset => _angleOffset;

  set angleOffset(double value) {
    _angleOffset = value;
    refresh();
  }

  YAGSLSwerveDriveModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showRobotRotation = true,
    bool showDesiredStates = true,
    double angleOffset = 0.0,
    super.dataType,
    super.period,
  })  : _showDesiredStates = showDesiredStates,
        _showRobotRotation = showRobotRotation,
        _angleOffset = angleOffset,
        super();

  YAGSLSwerveDriveModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showRobotRotation = tryCast(jsonData['show_robot_rotation']) ?? true;
    _showDesiredStates = tryCast(jsonData['show_desired_states']) ?? true;
    _angleOffset = tryCast(jsonData['angle_offset']) ?? 0.0;
  }

  @override
  void initializeSubscriptions() {
    measuredStatesSubscription =
        ntConnection.subscribe(measuredStatesTopic, super.period);
    desiredStatesSubscription =
        ntConnection.subscribe(desiredStatesTopic, super.period);
    robotRotationSubscription =
        ntConnection.subscribe(robotRotationTopic, super.period);
    maxSpeedSubscription = ntConnection.subscribe(maxSpeedTopic, super.period);
    robotWidthSubscription =
        ntConnection.subscribe(robotWidthTopic, super.period);
    robotLengthSubscription =
        ntConnection.subscribe(robotLengthTopic, super.period);
    rotationUnitSubscription =
        ntConnection.subscribe(rotationUnitTopic, super.period);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'show_robot_rotation': _showRobotRotation,
      'show_desired_states': _showDesiredStates,
      'angle_offset': _angleOffset,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        children: [
          Flexible(
            child: DialogToggleSwitch(
              initialValue: _showRobotRotation,
              label: 'Show Robot Rotation',
              onToggle: (value) {
                showRobotRotation = value;
              },
            ),
          ),
          Flexible(
            child: DialogToggleSwitch(
              initialValue: _showDesiredStates,
              label: 'Show Desired States',
              onToggle: (value) {
                showDesiredStates = value;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              initialText: angleOffset.toString(),
              label: 'Angle Offset (Degrees)',
              onSubmit: (String value) {
                double? doubleValue = double.tryParse(value);

                if (doubleValue != null) {
                  angleOffset = doubleValue;
                }
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
            ),
          ),
        ],
      ),
    ];
  }
}

class YAGSLSwerveDrive extends NTWidget {
  static const String widgetType = 'YAGSL Swerve Drive';

  const YAGSLSwerveDrive({super.key});

  List<SwerveModuleStateStruct> _toStructList(List<double> modules) {
    List<SwerveModuleStateStruct> structList = [];

    if (modules.length % 2 != 0) {
      modules.removeLast();
    }

    int moduleCount = modules.length ~/ 2;

    for (int i = 0; i < moduleCount; i++) {
      structList.add(SwerveModuleStateStruct(
        speed: modules[i * 2],
        angle: radians(modules[i * 2 + 1]),
      ));
    }

    return structList;
  }

  @override
  Widget build(BuildContext context) {
    YAGSLSwerveDriveModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) {
        // The side length for a 2x2 grid size
        const double normalSideLength = 170;
        double maxSideLength =
            min(constraints.maxWidth, constraints.maxHeight) * 0.85;

        return ListenableBuilder(
          listenable: Listenable.merge(model.subscriptions),
          builder: (context, snapshot) {
            List<Object?> measuredStatesRaw =
                tryCast(model.measuredStatesSubscription.value) ?? [];
            List<Object?> desiredStatesRaw =
                tryCast(model.desiredStatesSubscription.value) ?? [];

            List<double> measuredStates =
                measuredStatesRaw.whereType<double>().toList();
            List<double> desiredStates =
                desiredStatesRaw.whereType<double>().toList();

            double width = tryCast(model.robotWidthSubscription.value) ?? 1.0;
            double length =
                tryCast(model.robotLengthSubscription.value) ?? width;

            if (width <= 0.0) {
              width = 1.0;
            }
            if (length <= 0.0) {
              length = 0.0;
            }

            double sizeRatio = min(length, width) / max(length, width);
            double lengthWidthRatio = length / width;

            String rotationUnit =
                tryCast(model.rotationUnitSubscription.value) ?? 'radians';

            double robotAngle =
                tryCast(model.robotRotationSubscription.value) ?? 0.0;

            if (rotationUnit == 'degrees') {
              robotAngle = radians(robotAngle);
            } else if (rotationUnit == 'rotations') {
              robotAngle *= 2 * pi;
            }

            robotAngle -= radians(model.angleOffset);

            double maxSpeed = tryCast(model.maxSpeedSubscription.value) ?? 4.5;

            if (maxSpeed <= 0.0) {
              maxSpeed = 4.5;
            }

            return Transform.rotate(
              angle: (model.showRobotRotation) ? -robotAngle : 0.0,
              child: Transform.scale(
                scale: sizeRatio * maxSideLength / normalSideLength,
                child: CustomPaint(
                  size: Size(
                    sizeRatio * normalSideLength / lengthWidthRatio,
                    sizeRatio * normalSideLength * lengthWidthRatio,
                  ),
                  painter: SwerveDrivePainter(
                    maxSpeed: maxSpeed,
                    moduleStates: _toStructList(measuredStates),
                    desiredStates: (model.showDesiredStates)
                        ? _toStructList(desiredStates)
                        : [],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
