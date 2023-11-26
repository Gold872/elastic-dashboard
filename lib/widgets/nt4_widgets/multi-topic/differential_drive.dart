import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class DifferentialDrive extends StatelessWidget with NT4Widget {
  @override
  String type = 'DifferentialDrive';

  late String leftSpeedTopicName;
  late String rightSpeedTopicName;

  NT4Topic? leftSpeedTopic;
  NT4Topic? rightSpeedTopic;

  double leftSpeedPreviousValue = 0.0;
  double rightSpeedPreviousValue = 0.0;

  double leftSpeedCurrentValue = 0.0;
  double rightSpeedCurrentValue = 0.0;

  DifferentialDrive({
    super.key,
    required topic,
    period = Globals.defaultPeriod,
  }) {
    super.topic = topic;
    super.period = period;

    init();
  }

  DifferentialDrive.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    leftSpeedTopicName = '$topic/Left Motor Speed';
    rightSpeedTopicName = '$topic/Right Motor Speed';
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    leftSpeedTopicName = '$topic/Left Motor Speed';
    rightSpeedTopicName = '$topic/Right Motor Speed';

    leftSpeedTopic = null;
    rightSpeedTopic = null;

    leftSpeedPreviousValue = 0.0;
    leftSpeedCurrentValue = 0.0;

    rightSpeedPreviousValue = 0.0;
    rightSpeedCurrentValue = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        double leftSpeed =
            tryCast(nt4Connection.getLastAnnouncedValue(leftSpeedTopicName)) ??
                0.0;
        double rightSpeed =
            tryCast(nt4Connection.getLastAnnouncedValue(rightSpeedTopicName)) ??
                0.0;

        if (leftSpeed != leftSpeedPreviousValue) {
          leftSpeedCurrentValue = leftSpeed;
        }
        leftSpeedPreviousValue = leftSpeed;

        if (rightSpeed != rightSpeedPreviousValue) {
          rightSpeedCurrentValue = rightSpeed;
        }
        rightSpeedPreviousValue = rightSpeed;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left speed gauge
            SfLinearGauge(
              key: UniqueKey(),
              maximum: 1.0,
              minimum: -1.0,
              labelPosition: LinearLabelPosition.inside,
              tickPosition: LinearElementPosition.inside,
              markerPointers: [
                LinearShapePointer(
                  value: leftSpeedCurrentValue.clamp(-1.0, 1.0),
                  color: Theme.of(context).colorScheme.primary,
                  height: 12.5,
                  width: 12.5,
                  animationDuration: 0,
                  shapeType: LinearShapePointerType.invertedTriangle,
                  position: LinearElementPosition.outside,
                  dragBehavior: LinearMarkerDragBehavior.free,
                  onChanged: (value) {
                    leftSpeedCurrentValue = value;
                  },
                  onChangeEnd: (value) {
                    bool publishTopic = leftSpeedTopic == null;

                    leftSpeedTopic ??=
                        nt4Connection.getTopicFromName(leftSpeedTopicName);

                    if (leftSpeedTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      nt4Connection.nt4Client.publishTopic(leftSpeedTopic!);
                    }

                    nt4Connection.updateDataFromTopic(leftSpeedTopic!, value);

                    leftSpeedPreviousValue = value;
                  },
                ),
              ],
              axisTrackStyle: const LinearAxisTrackStyle(
                thickness: 7.5,
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
              orientation: LinearGaugeOrientation.vertical,
              interval: 0.5,
              minorTicksPerInterval: 2,
            ),
            const SizedBox(width: 5),
            // Robot
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double sideLength =
                      min(constraints.maxWidth, constraints.maxHeight);

                  return SizedBox(
                    width: sideLength,
                    height: sideLength,
                    child: CustomPaint(
                      painter: DifferentialDrivePainter(
                        leftSpeed: leftSpeedCurrentValue.clamp(-1.0, 1.0),
                        rightSpeed: rightSpeedCurrentValue.clamp(-1.0, 1.0),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 5),
            // Right speed gauge
            SfLinearGauge(
              key: UniqueKey(),
              maximum: 1.0,
              minimum: -1.0,
              labelPosition: LinearLabelPosition.outside,
              tickPosition: LinearElementPosition.outside,
              markerPointers: [
                LinearShapePointer(
                  value: rightSpeedCurrentValue.clamp(-1.0, 1.0),
                  color: Theme.of(context).colorScheme.primary,
                  height: 12.5,
                  width: 12.5,
                  animationDuration: 0,
                  shapeType: LinearShapePointerType.triangle,
                  position: LinearElementPosition.inside,
                  dragBehavior: LinearMarkerDragBehavior.free,
                  onChanged: (value) {
                    rightSpeedCurrentValue = value;
                  },
                  onChangeEnd: (value) {
                    bool publishTopic = rightSpeedTopic == null;

                    rightSpeedTopic ??=
                        nt4Connection.getTopicFromName(rightSpeedTopicName);

                    if (rightSpeedTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      nt4Connection.nt4Client.publishTopic(rightSpeedTopic!);
                    }

                    nt4Connection.updateDataFromTopic(rightSpeedTopic!, value);

                    rightSpeedPreviousValue = value;
                  },
                ),
              ],
              axisTrackStyle: const LinearAxisTrackStyle(
                thickness: 7.5,
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
              orientation: LinearGaugeOrientation.vertical,
              interval: 0.5,
            ),
          ],
        );
      },
    );
  }
}

class DifferentialDrivePainter extends CustomPainter {
  final double leftSpeed;
  final double rightSpeed;

  DifferentialDrivePainter({
    required this.leftSpeed,
    required this.rightSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    drawRobotFrame(canvas, size);
    drawMotionVector(
        canvas, size * 7 / 8, Offset(size.width / 2, size.height / 2));
  }

  void drawRobotFrame(Canvas canvas, Size size) {
    Paint outlinePainter = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double wheelWidth = size.width / 8;
    double wheelHeight = size.height / 3.25;

    Rect frontLeftWheel = Rect.fromCenter(
        center: Offset(wheelWidth / 2, wheelHeight / 2),
        width: wheelWidth,
        height: wheelHeight);

    Rect frontRightWheel = Rect.fromCenter(
        center: Offset(size.width - wheelWidth / 2, wheelHeight / 2),
        width: wheelWidth,
        height: wheelHeight);

    Rect backLeftWheel = Rect.fromCenter(
        center: Offset(wheelWidth / 2, size.height - wheelHeight / 2),
        width: wheelWidth,
        height: wheelHeight);

    Rect backRightWheel = Rect.fromCenter(
        center:
            Offset(size.width - wheelWidth / 2, size.height - wheelHeight / 2),
        width: wheelWidth,
        height: wheelHeight);

    Rect body = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width - wheelWidth * 2,
      height: size.height,
    );

    canvas.drawRect(frontLeftWheel, outlinePainter);
    canvas.drawRect(frontRightWheel, outlinePainter);
    canvas.drawRect(backLeftWheel, outlinePainter);
    canvas.drawRect(backRightWheel, outlinePainter);
    canvas.drawRect(body, outlinePainter);
  }

  void drawMotionVector(Canvas canvas, Size size, Offset center) {
    Paint vectorArc = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final double forwardSpeed = (leftSpeed + rightSpeed) / 2;
    final double turnSpeed = (leftSpeed - rightSpeed) / 2;

    // Math calculations taken from WPILib's Shuffleboard
    if (forwardSpeed.abs() < 0.05 && turnSpeed.abs() < 0.05) {
      // Draw an X since the robot isn't really moving
      Size xSize = size / 3;

      Path xPath = Path()
        ..moveTo(center.dx, center.dy)
        ..relativeMoveTo(-xSize.width / 2, -xSize.height / 2)
        ..relativeLineTo(xSize.width, xSize.height)
        ..relativeMoveTo(0, -xSize.height)
        ..relativeLineTo(-xSize.width, xSize.height);

      canvas.drawPath(xPath, vectorArc);
      return;
    }

    const double arrowSize = 16.0;
    const double arrowAngle = 40 * pi / 180;
    final double maxRadius = min(size.width, size.height) / 2 - arrowSize;

    final double moment = (rightSpeed - leftSpeed) / 2;
    final double avgSpeed = (leftSpeed + rightSpeed) / 2;
    final double turnRadius = avgSpeed / moment;

    // Mostly forward/backward with a bit of turn
    if (turnRadius.abs() >= 1) {
      final double arcSign = -(turnRadius.sign);
      double radius = (turnRadius * maxRadius).abs();

      final double forwardSpeedSign = forwardSpeed.sign;

      double vectorX = forwardSpeedSign * turnSpeed * maxRadius;
      double vectorY = -forwardSpeed * maxRadius;

      if (vectorX.abs() > maxRadius || vectorY.abs() > maxRadius) {
        double vectorMax = max(vectorX.abs(), vectorY.abs());

        vectorX /= vectorMax;
        vectorY /= vectorMax;

        vectorX *= maxRadius;
        vectorY *= maxRadius;
      }

      Path vectorPath = Path()
        ..moveTo(center.dx, center.dy)
        ..relativeArcToPoint(Offset(vectorX, vectorY),
            radius: (radius != double.infinity)
                ? Radius.circular(radius)
                : Radius.zero,
            clockwise: arcSign * forwardSpeedSign == 1);

      canvas.drawPath(vectorPath, vectorArc);

      // Draw curved arrow
      final double arcLength = sqrt(vectorX * vectorX + vectorY * vectorY);

      final double scaleFactor = (7.50 * arcLength / maxRadius).clamp(0.0, 1.1);

      final double base = scaleFactor * arrowSize / 2;

      final double arrowRotation = atan2(vectorY, vectorX) +
          forwardSpeedSign * arcSign * arcLength / radius;

      drawArrowHead(
          canvas, center, vectorX, vectorY, arrowRotation, arrowAngle, base);
    } else {
      final double turnSign = (leftSpeed - rightSpeed).sign;

      // Turning from the center of the robot
      if (turnRadius == 0) {
        double radius = max(leftSpeed, rightSpeed) * maxRadius;
        double angle = turnSign * pi;
        double startAngle = (moment < 0) ? pi : 0;

        Rect arcOval =
            Rect.fromCenter(center: center, width: radius, height: radius);

        canvas.drawArc(arcOval, startAngle, angle, false, vectorArc);

        final double scaleFactor =
            (2.0 * angle.abs() * radius / maxRadius).clamp(0.75, 1.1);

        final double base = scaleFactor * arrowSize / 2;

        const double arrowRotation = pi / 2;

        drawArrowHead(canvas, center, turnSign * radius / 2, 0, arrowRotation,
            arrowAngle, base);
      } else {
        // Turning from inside the robot
        double dominant = turnRadius < 0 ? leftSpeed : rightSpeed;
        double secondary = turnRadius < 0 ? rightSpeed : leftSpeed;
        double radius = dominant.abs() * maxRadius;
        double angle = turnSign * _map(secondary / dominant, 0, -1, 0.5, pi);
        double startAngle = turnRadius < 0 ? pi : 0;

        Rect arcOval =
            Rect.fromCenter(center: center, width: radius, height: radius);

        canvas.drawArc(arcOval, startAngle, angle, false, vectorArc);

        final double scaleFactor =
            (2.0 * angle.abs() * radius / maxRadius).clamp(0.75, 1.1);

        final double base = scaleFactor * arrowSize / 2;

        double tipX = 0.5 * radius * cos(angle + startAngle);
        double tipY = 0.5 * radius * sin(angle + startAngle);

        double arrowRotation = angle + startAngle + (pi / 2) * turnSign;

        drawArrowHead(
            canvas, center, tipX, tipY, arrowRotation, arrowAngle, base);
      }
    }
  }

  void drawArrowHead(Canvas canvas, Offset center, double tipX, double tipY,
      double arrowRotation, double arrowAngle, double base) {
    Paint arrowHead = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    double triangleHeight = base / (2 * tan(arrowAngle / 2));

    double xOffset = cos(arrowRotation) * triangleHeight / 2;
    double yOffset = sin(arrowRotation) * triangleHeight / 2;

    Path arrowPath = Path()
      ..moveTo(
          center.dx + tipX + xOffset - base * cos(arrowRotation - arrowAngle),
          center.dy + tipY + yOffset - base * sin(arrowRotation - arrowAngle))
      ..lineTo(center.dx + tipX + xOffset, center.dy + tipY + yOffset)
      ..lineTo(
          center.dx + tipX + xOffset - base * cos(arrowRotation + arrowAngle),
          center.dy + tipY + yOffset - base * sin(arrowRotation + arrowAngle))
      ..close();

    canvas.drawPath(arrowPath, arrowHead);
  }

  double _map(double x, double minInput, double maxInput, double minOutput,
      double maxOutput) {
    return (x - minInput) * (maxOutput - minOutput) / (maxInput - minInput) +
        minOutput;
  }

  @override
  bool shouldRepaint(DifferentialDrivePainter oldDelegate) {
    return oldDelegate.leftSpeed != leftSpeed ||
        oldDelegate.rightSpeed != rightSpeed;
  }
}
