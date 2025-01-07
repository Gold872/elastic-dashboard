import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/swerve_module_state_struct.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class StructSwerveModel extends MultiTopicNTWidgetModel {
  @override
  String type = StructSwerve.widgetType;

  String get measuredStatesTopic => '$topic/measuredStates';
  String get desiredStatesTopic => '$topic/desiredStates';
  String get robotRotationTopic => '$topic/robotRotation';
  String get maxSpeedTopic => '$topic/maxModuleSpeed';
  String get robotWidthTopic => '$topic/chassisWidth';
  String get robotLengthTopic => '$topic/chassisLength';

  late NT4Subscription measuredStatesSubscription;
  late NT4Subscription desiredStatesSubscription;
  late NT4Subscription robotRotationSubscription;
  late NT4Subscription maxSpeedSubscription;
  late NT4Subscription robotWidthSubscription;
  late NT4Subscription robotLengthSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        measuredStatesSubscription,
        desiredStatesSubscription,
        robotRotationSubscription,
        maxSpeedSubscription,
        robotWidthSubscription,
        robotLengthSubscription,
      ];

  bool _showRobotRotation = true;
  bool _showDesiredStates = true;

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

  StructSwerveModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showRobotRotation = true,
    bool showDesiredStates = true,
    super.dataType,
    super.period,
  })  : _showDesiredStates = showDesiredStates,
        _showRobotRotation = showRobotRotation,
        super();

  StructSwerveModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showRobotRotation = tryCast(jsonData['show_robot_rotation']) ?? true;
    _showDesiredStates = tryCast(jsonData['show_desired_states']) ?? true;
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
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'show_robot_rotation': _showRobotRotation,
      'show_desired_states': _showDesiredStates,
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
    ];
  }
}

class StructSwerve extends NTWidget {
  static const String widgetType = 'Struct Swerve';

  const StructSwerve({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    StructSwerveModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) {
        // The side length for a 2x2 grid size
        const double normalSideLength = 170;
        double maxSideLength =
            min(constraints.maxWidth, constraints.maxHeight) * 0.85;
        return ListenableBuilder(
          listenable: Listenable.merge(model.subscriptions),
          builder: (context, child) {
            List<Object?> measuredStatesRaw =
                tryCast(model.measuredStatesSubscription.value) ?? [];
            List<Object?> desiredStatesRaw =
                tryCast(model.desiredStatesSubscription.value) ?? [];
            List<Object?> rotationRaw =
                tryCast(model.robotRotationSubscription.value) ?? [];

            List<int> measuredStatesBytes =
                measuredStatesRaw.whereType<int>().toList();
            List<int> desiredStatesBytes =
                desiredStatesRaw.whereType<int>().toList();
            List<int> rotationBytes = rotationRaw.whereType<int>().toList();

            List<SwerveModuleStateStruct> measuredStates =
                SwerveModuleStateStruct.listFromBytes(
                    Uint8List.fromList(measuredStatesBytes));

            List<SwerveModuleStateStruct> desiredStates =
                SwerveModuleStateStruct.listFromBytes(
                    Uint8List.fromList(desiredStatesBytes));

            double robotAngle = 0.0;

            if (rotationBytes.length >= 8) {
              ByteBuffer buffer = Uint8List.fromList(rotationBytes).buffer;
              ByteData view = ByteData.view(buffer);

              robotAngle = view.getFloat64(0, Endian.little);
            }

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

            double maxSpeed = tryCast(model.maxSpeedSubscription.value) ?? 4.5;

            if (maxSpeed <= 0.0) {
              maxSpeed = 4.5;
            }

            return Transform.rotate(
              angle: (model.showRobotRotation) ? -robotAngle : 0.0,
              child: Transform.scale(
                scale: maxSideLength / (normalSideLength * sizeRatio),
                child: CustomPaint(
                  size: Size(
                    sizeRatio * normalSideLength / lengthWidthRatio,
                    sizeRatio * normalSideLength * lengthWidthRatio,
                  ),
                  painter: SwerveDrivePainter(
                    maxSpeed: maxSpeed,
                    moduleStates: measuredStates,
                    desiredStates:
                        (model.showDesiredStates) ? desiredStates : [],
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

class SwerveDrivePainter extends CustomPainter {
  final List<SwerveModuleStateStruct> moduleStates;
  final List<SwerveModuleStateStruct> desiredStates;
  final double maxSpeed;

  const SwerveDrivePainter({
    required this.moduleStates,
    this.desiredStates = const [],
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double robotFrameScale = 0.75;
    const double arrowScale = robotFrameScale * 0.45;

    drawRobotFrame(
        canvas,
        size * robotFrameScale,
        Offset(size.width - size.width * robotFrameScale,
                size.height - size.height * robotFrameScale) /
            2);

    drawRobotDirectionArrow(
        canvas,
        size * arrowScale,
        Offset(size.width - size.width * arrowScale,
                size.height - size.height * arrowScale) /
            2);

    if (desiredStates.length >= 4) {
      drawMotionArrows(
        canvas,
        size * robotFrameScale,
        Offset(size.width - size.width * robotFrameScale,
                size.height - size.height * robotFrameScale) /
            2,
        const Color.fromARGB(255, 0, 0, 255),
        frontLeft: desiredStates[0],
        frontRight: desiredStates[1],
        backLeft: desiredStates[2],
        backRight: desiredStates[3],
        drawXIfZero: false,
      );
    }

    if (moduleStates.length < 4) {
      moduleStates.addAll(Iterable.generate(4 - moduleStates.length,
          (_) => const SwerveModuleStateStruct(speed: 0, angle: 0)));
    }

    drawMotionArrows(
      canvas,
      size * robotFrameScale,
      Offset(size.width - size.width * robotFrameScale,
              size.height - size.height * robotFrameScale) /
          2,
      Colors.red,
      frontLeft: moduleStates[0],
      frontRight: moduleStates[1],
      backLeft: moduleStates[2],
      backRight: moduleStates[3],
    );
  }

  void drawRobotFrame(Canvas canvas, Size size, Offset offset) {
    final double circleRadius = min(size.width, size.height) / 8;

    Paint framePainter = Paint()
      ..strokeWidth = 1.75
      ..color = Colors.grey
      ..style = PaintingStyle.stroke;

    // Front left circle
    canvas.drawCircle(Offset(circleRadius, circleRadius) + offset, circleRadius,
        framePainter);

    // Front right circle
    canvas.drawCircle(Offset(size.width - circleRadius, circleRadius) + offset,
        circleRadius, framePainter);

    // Back left circle
    canvas.drawCircle(Offset(circleRadius, size.height - circleRadius) + offset,
        circleRadius, framePainter);

    // Back right circle
    canvas.drawCircle(
        Offset(offset.dx + size.width - circleRadius,
            offset.dy + size.height - circleRadius),
        circleRadius,
        framePainter);

    // Top line
    canvas.drawLine(
        Offset(circleRadius * 2, circleRadius) + offset,
        Offset(size.width - circleRadius * 2, circleRadius) + offset,
        framePainter);

    // Right line
    canvas.drawLine(
        Offset(size.width - circleRadius, circleRadius * 2) + offset,
        Offset(size.width - circleRadius, size.height - circleRadius * 2) +
            offset,
        framePainter);

    // Bottom line
    canvas.drawLine(
        Offset(circleRadius * 2, size.height - circleRadius) + offset,
        Offset(size.width - circleRadius * 2, size.height - circleRadius) +
            offset,
        framePainter);

    // Left line
    canvas.drawLine(
        Offset(circleRadius, circleRadius * 2) + offset,
        Offset(circleRadius, size.height - circleRadius * 2) + offset,
        framePainter);
  }

  void drawMotionArrows(
    Canvas canvas,
    Size size,
    Offset offset,
    Color color, {
    required SwerveModuleStateStruct frontLeft,
    required SwerveModuleStateStruct frontRight,
    required SwerveModuleStateStruct backLeft,
    required SwerveModuleStateStruct backRight,
    bool drawXIfZero = true,
  }) {
    double frontLeftAngle = frontLeft.angle;
    double frontRightAngle = frontRight.angle;
    double backLeftAngle = backLeft.angle;
    double backRightAngle = backRight.angle;

    final double circleRadius = min(size.width, size.height) / 8;
    const double arrowAngle = 40 * pi / 180;

    final double pixelsPerMPS = (9.0 / 1.0) * (4.5 / maxSpeed);

    const double minArrowBase = 6.5;
    const double maxArrowBase = 16.0;

    Paint arrowPaint = Paint()
      ..strokeWidth = 2.5
      ..color = color
      ..style = PaintingStyle.stroke;

    Paint anglePaint = Paint()
      ..strokeWidth = 3.5
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Front left angle indicator thing
    Rect frontLeftWheel = Rect.fromCenter(
        center: Offset(circleRadius, circleRadius) + offset,
        width: circleRadius * 2,
        height: circleRadius * 2);

    canvas.drawArc(frontLeftWheel, -(frontLeftAngle + radians(22.5)) - pi / 2,
        radians(45), false, anglePaint);

    // Front left vector arrow
    if (frontLeft.speed.abs() >= 0.05) {
      frontLeftAngle += pi / 2;
      frontLeftAngle *= -1;

      if (frontLeft.speed < 0) {
        frontLeftAngle -= pi;
      }

      double frontLeftArrowLength = frontLeft.speed.abs() * pixelsPerMPS;
      double frontLeftArrowBase =
          (frontLeftArrowLength / 3.0).clamp(minArrowBase, maxArrowBase);

      canvas.drawLine(
          Offset(circleRadius, circleRadius) + offset,
          Offset(frontLeftArrowLength * cos(frontLeftAngle),
                  frontLeftArrowLength * sin(frontLeftAngle)) +
              Offset(circleRadius, circleRadius) +
              offset,
          arrowPaint);

      drawArrowHead(
          canvas,
          Offset(circleRadius, circleRadius) / 2 + offset,
          frontLeftArrowLength * cos(frontLeftAngle) + circleRadius / 2,
          frontLeftArrowLength * sin(frontLeftAngle) + circleRadius / 2,
          frontLeftAngle,
          arrowAngle,
          frontLeftArrowBase,
          arrowPaint);
    } else if (drawXIfZero) {
      // Draw an X
      drawX(canvas, Offset(circleRadius, circleRadius) + offset, circleRadius,
          arrowPaint);
    }

    // Front right angle indicator thing
    Rect frontRightWheel = Rect.fromCenter(
        center: Offset(size.width - circleRadius, circleRadius) + offset,
        width: circleRadius * 2,
        height: circleRadius * 2);

    canvas.drawArc(frontRightWheel, -(frontRightAngle + radians(22.5)) - pi / 2,
        radians(45), false, anglePaint);

    // Front right vector arrow
    if (frontRight.speed.abs() >= 0.05) {
      frontRightAngle += pi / 2;
      frontRightAngle *= -1;

      if (frontRight.speed < 0) {
        frontRightAngle -= pi;
      }

      double frontRightArrowLength = frontRight.speed.abs() * pixelsPerMPS;
      double frontRightArrowBase =
          (frontRightArrowLength / 3.0).clamp(minArrowBase, maxArrowBase);

      canvas.drawLine(
          Offset(size.width - circleRadius, circleRadius) + offset,
          Offset(frontRightArrowLength * cos(frontRightAngle),
                  frontRightArrowLength * sin(frontRightAngle)) +
              Offset(size.width - circleRadius, circleRadius) +
              offset,
          arrowPaint);

      drawArrowHead(
          canvas,
          Offset(size.width - circleRadius / 2, circleRadius / 2) + offset,
          frontRightArrowLength * cos(frontRightAngle) - circleRadius / 2,
          frontRightArrowLength * sin(frontRightAngle) + circleRadius / 2,
          frontRightAngle,
          arrowAngle,
          frontRightArrowBase,
          arrowPaint);
    } else if (drawXIfZero) {
      // Draw an X
      drawX(canvas, Offset(size.width - circleRadius, circleRadius) + offset,
          circleRadius, arrowPaint);
    }

    // Back left angle indicator thing
    Rect backLeftWheel = Rect.fromCenter(
        center: Offset(circleRadius, size.height - circleRadius) + offset,
        width: circleRadius * 2,
        height: circleRadius * 2);

    canvas.drawArc(backLeftWheel, -(backLeftAngle + radians(22.5)) - pi / 2,
        radians(45), false, anglePaint);

    // Back left vector arrow
    if (backLeft.speed.abs() >= 0.05) {
      backLeftAngle += pi / 2;
      backLeftAngle *= -1;

      if (backLeft.speed < 0) {
        backLeftAngle -= pi;
      }

      double backLeftArrowLength = backLeft.speed.abs() * pixelsPerMPS;
      double backLeftArrowBase =
          (backLeftArrowLength / 3.0).clamp(minArrowBase, maxArrowBase);

      canvas.drawLine(
          Offset(circleRadius, size.height - circleRadius) + offset,
          Offset(backLeftArrowLength * cos(backLeftAngle),
                  backLeftArrowLength * sin(backLeftAngle)) +
              Offset(circleRadius, size.height - circleRadius) +
              offset,
          arrowPaint);

      drawArrowHead(
          canvas,
          Offset(circleRadius / 2, size.height - circleRadius / 2) + offset,
          backLeftArrowLength * cos(backLeftAngle) + circleRadius / 2,
          backLeftArrowLength * sin(backLeftAngle) - circleRadius / 2,
          backLeftAngle,
          arrowAngle,
          backLeftArrowBase,
          arrowPaint);
    } else if (drawXIfZero) {
      // Draw an X
      drawX(canvas, Offset(circleRadius, size.height - circleRadius) + offset,
          circleRadius, arrowPaint);
    }

    // Back right angle indicator thing
    Rect backRightWheel = Rect.fromCenter(
        center: Offset(size.width - circleRadius, size.height - circleRadius) +
            offset,
        width: circleRadius * 2,
        height: circleRadius * 2);

    canvas.drawArc(backRightWheel, -(backRightAngle + radians(22.5)) - pi / 2,
        radians(45), false, anglePaint);

    // Back right vector arrow
    if (backRight.speed.abs() >= 0.05) {
      backRightAngle += pi / 2;
      backRightAngle *= -1;

      if (backRight.speed < 0) {
        backRightAngle -= pi;
      }

      double backRightArrowLength = backRight.speed.abs() * pixelsPerMPS;
      double backRightArrowBase =
          (backRightArrowLength / 3.0).clamp(minArrowBase, maxArrowBase);

      canvas.drawLine(
          Offset(size.width - circleRadius, size.height - circleRadius) +
              offset,
          Offset(backRightArrowLength * cos(backRightAngle),
                  backRightArrowLength * sin(backRightAngle)) +
              Offset(size.width - circleRadius, size.height - circleRadius) +
              offset,
          arrowPaint);

      drawArrowHead(
          canvas,
          Offset(size.width - circleRadius / 2,
                  size.height - circleRadius / 2) +
              offset,
          backRightArrowLength * cos(backRightAngle) - circleRadius / 2,
          backRightArrowLength * sin(backRightAngle) - circleRadius / 2,
          backRightAngle,
          arrowAngle,
          backRightArrowBase,
          arrowPaint);
    } else if (drawXIfZero) {
      // Draw an X
      drawX(
          canvas,
          Offset(size.width - circleRadius, size.height - circleRadius) +
              offset,
          circleRadius,
          arrowPaint);
    }
  }

  void drawX(Canvas canvas, Offset offset, double circleRadius, Paint xPaint) {
    canvas.drawLine(Offset(circleRadius / 2, circleRadius / 2) * 0.75 + offset,
        -Offset(circleRadius / 2, circleRadius / 2) * 0.75 + offset, xPaint);

    canvas.drawLine(
        -Offset(-circleRadius / 2, circleRadius / 2) * 0.75 + offset,
        Offset(-circleRadius / 2, circleRadius / 2) * 0.75 + offset,
        xPaint);
  }

  void drawArrowHead(Canvas canvas, Offset center, double tipX, double tipY,
      double arrowRotation, double arrowAngle, double base, Paint arrowPaint) {
    Path arrowPath = Path()
      ..moveTo(center.dx + tipX - base * cos(arrowRotation - arrowAngle),
          center.dy + tipY - base * sin(arrowRotation - arrowAngle))
      ..lineTo(center.dx + tipX, center.dy + tipY)
      ..lineTo(center.dx + tipX - base * cos(arrowRotation + arrowAngle),
          center.dy + tipY - base * sin(arrowRotation + arrowAngle));

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void drawRobotDirectionArrow(Canvas canvas, Size size, Offset offset) {
    const double arrowAngle = 40 * pi / 180;
    final double base = size.width * 0.45;
    const double arrowRotation = -pi / 2;
    const double tipX = 0;
    final double tipY = -size.height / 2;

    Offset center = Offset(size.width, size.height) / 2 + offset;

    Paint arrowPainter = Paint()
      ..strokeWidth = 3.5
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    Path arrowHead = Path()
      ..moveTo(center.dx + tipX - base * cos(arrowRotation - arrowAngle),
          center.dy + tipY - base * sin(arrowRotation - arrowAngle))
      ..lineTo(center.dx + tipX, center.dy + tipY)
      ..lineTo(center.dx + tipX - base * cos(arrowRotation + arrowAngle),
          center.dy + tipY - base * sin(arrowRotation + arrowAngle));

    canvas.drawPath(arrowHead, arrowPainter);
    canvas.drawLine(Offset(tipX, tipY) + center, Offset(tipX, -tipY) + center,
        arrowPainter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
