import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/swerve_module_state_struct.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/struct_swerve.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class BasicSwerveModel extends MultiTopicNTWidgetModel {
  @override
  String type = SwerveDriveWidget.widgetType;

  get frontLeftAngleTopic => '$topic/Front Left Angle';

  get frontLeftVelocityTopic => '$topic/Front Left Velocity';

  get frontRightAngleTopic => '$topic/Front Right Angle';

  get frontRightVelocityTopic => '$topic/Front Right Velocity';

  get backLeftAngleTopic => '$topic/Back Left Angle';

  get backLeftVelocityTopic => '$topic/Back Left Velocity';

  get backRightAngleTopic => '$topic/Back Right Angle';

  get backRightVelocityTopic => '$topic/Back Right Velocity';

  get robotAngleTopic => '$topic/Robot Angle';

  late NT4Subscription frontLeftAngleSubscription;
  late NT4Subscription frontLeftVelocitySubscription;
  late NT4Subscription frontRightAngleSubscription;
  late NT4Subscription frontRightVelocitySubscription;
  late NT4Subscription backLeftAngleSubscription;
  late NT4Subscription backLeftVelocitySubscription;
  late NT4Subscription backRightAngleSubscription;
  late NT4Subscription backRightVelocitySubscription;

  late NT4Subscription robotAngleSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        frontLeftAngleSubscription,
        frontLeftVelocitySubscription,
        frontRightAngleSubscription,
        frontRightVelocitySubscription,
        backLeftAngleSubscription,
        backLeftVelocitySubscription,
        backRightAngleSubscription,
        backRightVelocitySubscription,
        robotAngleSubscription,
      ];

  bool _showRobotRotation = true;

  String _rotationUnit = 'Radians';

  BasicSwerveModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showRobotRotation = true,
    String rotationUnit = 'Radians',
    super.period,
    super.dataType,
  })  : _rotationUnit = rotationUnit,
        _showRobotRotation = showRobotRotation,
        super();

  BasicSwerveModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showRobotRotation = tryCast(jsonData['show_robot_rotation']) ?? true;
    _rotationUnit = tryCast(jsonData['rotation_unit']) ?? 'Degrees';
  }

  @override
  void init() {
    initSubscriptions();

    super.init();
  }

  void initSubscriptions() {
    frontLeftAngleSubscription =
        ntConnection.subscribe(frontLeftAngleTopic, super.period);
    frontLeftVelocitySubscription =
        ntConnection.subscribe(frontLeftVelocityTopic, super.period);
    frontRightAngleSubscription =
        ntConnection.subscribe(frontRightAngleTopic, super.period);
    frontRightVelocitySubscription =
        ntConnection.subscribe(frontRightVelocityTopic, super.period);
    backLeftAngleSubscription =
        ntConnection.subscribe(backLeftAngleTopic, super.period);
    backLeftVelocitySubscription =
        ntConnection.subscribe(backLeftVelocityTopic, super.period);
    backRightAngleSubscription =
        ntConnection.subscribe(backRightAngleTopic, super.period);
    backRightVelocitySubscription =
        ntConnection.subscribe(backRightVelocityTopic, super.period);

    robotAngleSubscription =
        ntConnection.subscribe(robotAngleTopic, super.period);
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initSubscriptions();

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'show_robot_rotation': _showRobotRotation,
      'rotation_unit': _rotationUnit,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: DialogToggleSwitch(
          initialValue: _showRobotRotation,
          label: 'Show Robot Rotation',
          onToggle: (value) {
            showRobotRotation = value;
          },
        ),
      ),
      const SizedBox(height: 5),
      const Text('Rotation Unit'),
      StatefulBuilder(builder: (context, setState) {
        return Column(
          children: [
            ListTile(
              title: const Text('Radians'),
              dense: true,
              leading: Radio<String>(
                value: 'Radians',
                groupValue: _rotationUnit,
                onChanged: (value) {
                  rotationUnit = 'Radians';

                  setState(() {});
                },
              ),
            ),
            ListTile(
              title: const Text('Degrees'),
              dense: true,
              leading: Radio<String>(
                value: 'Degrees',
                groupValue: _rotationUnit,
                onChanged: (value) {
                  rotationUnit = 'Degrees';

                  setState(() {});
                },
              ),
            ),
            ListTile(
              title: const Text('Rotations'),
              dense: true,
              leading: Radio<String>(
                value: 'Rotations',
                groupValue: _rotationUnit,
                onChanged: (value) {
                  rotationUnit = 'Rotations';

                  setState(() {});
                },
              ),
            ),
          ],
        );
      }),
    ];
  }

  bool get showRobotRotation => _showRobotRotation;

  set showRobotRotation(bool value) {
    _showRobotRotation = value;
    refresh();
  }

  String get rotationUnit => _rotationUnit;

  set rotationUnit(String value) {
    _rotationUnit = value;
    refresh();
  }
}

class SwerveDriveWidget extends NTWidget {
  static const String widgetType = 'SwerveDrive';

  const SwerveDriveWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    BasicSwerveModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) {
        // The side length for a 2x2 grid size
        const double normalSideLength = 170;
        double sideLength =
            min(constraints.maxWidth, constraints.maxHeight) * 0.85;
        return ListenableBuilder(
          listenable: Listenable.merge(model.subscriptions),
          builder: (context, child) {
            double frontLeftAngle =
                tryCast(model.frontLeftAngleSubscription.value) ?? 0.0;
            double frontLeftVelocity =
                tryCast(model.frontLeftVelocitySubscription.value) ?? 0.0;

            double frontRightAngle =
                tryCast(model.frontRightAngleSubscription.value) ?? 0.0;
            double frontRightVelocity =
                tryCast(model.frontRightVelocitySubscription.value) ?? 0.0;

            double backLeftAngle =
                tryCast(model.backLeftAngleSubscription.value) ?? 0.0;
            double backLeftVelocity =
                tryCast(model.backLeftVelocitySubscription.value) ?? 0.0;

            double backRightAngle =
                tryCast(model.backRightAngleSubscription.value) ?? 0.0;
            double backRightVelocity =
                tryCast(model.backRightVelocitySubscription.value) ?? 0.0;

            double robotAngle =
                tryCast(model.robotAngleSubscription.value) ?? 0.0;

            if (model.rotationUnit == 'Degrees') {
              frontLeftAngle = radians(frontLeftAngle);
              frontRightAngle = radians(frontRightAngle);
              backLeftAngle = radians(backLeftAngle);
              backRightAngle = radians(backRightAngle);

              robotAngle = radians(robotAngle);
            } else if (model.rotationUnit == 'Rotations') {
              frontLeftAngle *= 2 * pi;
              frontRightAngle *= 2 * pi;
              backLeftAngle *= 2 * pi;
              backRightAngle *= 2 * pi;

              robotAngle *= 2 * pi;
            }

            return Transform.rotate(
              angle: (model.showRobotRotation) ? -robotAngle : 0.0,
              child: Transform.scale(
                scale: sideLength / normalSideLength,
                child: CustomPaint(
                  size: const Size(normalSideLength, normalSideLength),
                  painter: SwerveDrivePainter(
                    moduleStates: [
                      SwerveModuleStateStruct(
                        speed: frontLeftVelocity,
                        angle: frontLeftAngle,
                      ),
                      SwerveModuleStateStruct(
                        speed: frontRightVelocity,
                        angle: frontRightAngle,
                      ),
                      SwerveModuleStateStruct(
                        speed: backLeftVelocity,
                        angle: backLeftAngle,
                      ),
                      SwerveModuleStateStruct(
                        speed: backRightVelocity,
                        angle: backRightAngle,
                      ),
                    ],
                    maxSpeed: 4.5,
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
