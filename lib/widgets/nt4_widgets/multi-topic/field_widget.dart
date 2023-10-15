import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart'
    show Matrix3, Quaternion, Vector3, radians;

class FieldWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Field';

  String fieldGame = 'Charged Up';
  late Field? field;

  double robotWidthMeters = 0.82;
  double robotLengthMeters = 1.00;

  bool showOtherObjects = true;
  bool showTrajectories = true;

  final double otherObjectSize = 0.55;
  final double trajectoryPointSize = 0.10;

  Size? widgetSize;

  late String robotTopicName;
  List<String> otherObjectTopics = [];

  FieldWidget({
    super.key,
    required topic,
    String? fieldName,
    this.showOtherObjects = true,
    this.showTrajectories = true,
    period = Globals.defaultPeriod,
  }) {
    super.topic = topic;
    super.period = period;

    fieldGame = fieldName ?? fieldGame;

    init();
  }

  FieldWidget.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    fieldGame = tryCast(jsonData['field_game']) ?? fieldGame;

    robotWidthMeters = tryCast(jsonData['robot_width']) ?? 0.82;
    robotLengthMeters = tryCast(jsonData['robot_length']) ?? 1.00;

    showOtherObjects = tryCast(jsonData['show_other_objects']) ?? true;
    showTrajectories = tryCast(jsonData['show_trajectories']) ?? true;

    init();
  }

  @override
  void init() {
    super.init();

    robotTopicName = '$topic/Robot';

    field = FieldImages.getFieldFromGame(fieldGame);
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    robotTopicName = '$topic/Robot';
  }

  @override
  void dispose() {
    super.dispose();

    field?.dispose();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'field_game': fieldGame,
      'robot_width': robotWidthMeters,
      'robot_length': robotLengthMeters,
      'show_other_objects': showOtherObjects,
      'show_trajectories': showTrajectories,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      const Center(child: Text('Game')),
      DialogDropdownChooser(
        onSelectionChanged: (value) {
          if (value == null) {
            return;
          }

          Field? newField = FieldImages.getFieldFromGame(value);

          if (newField == null) {
            return;
          }

          fieldGame = value;

          field?.dispose();

          field = newField;

          refresh();
        },
        choices: FieldImages.fields.map((e) => e.game).toList(),
        initialValue: field!.game,
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newWidth = double.tryParse(value);

                if (newWidth == null) {
                  return;
                }
                robotWidthMeters = newWidth;
                refresh();
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
              label: 'Robot Width (meters)',
              initialText: robotWidthMeters.toString(),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newLength = double.tryParse(value);

                if (newLength == null) {
                  return;
                }
                robotLengthMeters = newLength;
                refresh();
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
              label: 'Robot Length (meters)',
              initialText: robotLengthMeters.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Non-Robot Objects',
              initialValue: showOtherObjects,
              onToggle: (value) {
                showOtherObjects = value;

                refresh();
              },
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Trajectories',
              initialValue: showTrajectories,
              onToggle: (value) {
                showTrajectories = value;

                refresh();
              },
            ),
          ),
        ],
      ),
    ];
  }

  double getBackgroundFitWidth(Size size) {
    double fitWidth = size.width;
    double fitHeight = size.height;

    return min(
        fitWidth,
        fitHeight /
            ((field!.fieldImageHeight ?? 0) / (field!.fieldImageWidth ?? 1)));
  }

  double getBackgroundFitHeight(Size size) {
    double fitWidth = size.width;
    double fitHeight = size.height;

    return min(
        fitHeight,
        fitWidth *
            ((field!.fieldImageHeight ?? 0) / (field!.fieldImageWidth ?? 1)));
  }

  Widget getTransformedFieldObject(List<double> objectPosition, Offset center,
      Offset fieldCenter, double scaleReduction,
      {Size? objectSize}) {
    double xFromCenter =
        (objectPosition[0]) * field!.pixelsPerMeterHorizontal - fieldCenter.dx;

    double yFromCenter =
        fieldCenter.dy - (objectPosition[1]) * field!.pixelsPerMeterVertical;

    Offset positionOffset = center +
        (Offset(xFromCenter + field!.topLeftCorner.dx,
                yFromCenter - field!.topLeftCorner.dy)) *
            scaleReduction;

    double width = (objectSize?.width ?? otherObjectSize) *
        field!.pixelsPerMeterHorizontal *
        scaleReduction;

    double length = (objectSize?.height ?? otherObjectSize) *
        field!.pixelsPerMeterVertical *
        scaleReduction;

    Matrix4 transform = Matrix4.compose(
      Vector3(positionOffset.dx - length / 2, positionOffset.dy - width / 2, 0),
      Quaternion.fromRotation(Matrix3.rotationZ(-radians(objectPosition[2]))),
      Vector3(1, 1, 1),
    );

    Widget otherObject = Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(
        minWidth: 4.0,
        minHeight: 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        border: Border.all(
          color: Colors.red,
          width: 4.0,
        ),
      ),
      width: length,
      height: width,
      child: CustomPaint(
        size: Size(width * 0.25, width * 0.25),
        painter:
            TrianglePainter(strokeColor: const Color.fromARGB(255, 0, 255, 0)),
      ),
    );

    return Transform(
      origin: Offset(length, width) / 2,
      transform: transform,
      child: otherObject,
    );
  }

  Widget getTrajectoryPoint(List<double> objectPosition, Offset center,
      Offset fieldCenter, double scaleReduction) {
    double xFromCenter =
        (objectPosition[0]) * field!.pixelsPerMeterHorizontal - fieldCenter.dx;

    double yFromCenter =
        fieldCenter.dy - (objectPosition[1]) * field!.pixelsPerMeterVertical;

    Offset positionOffset = center +
        (Offset(xFromCenter + field!.topLeftCorner.dx,
                yFromCenter - field!.topLeftCorner.dy)) *
            scaleReduction;

    double size =
        trajectoryPointSize * field!.pixelsPerMeterHorizontal * scaleReduction;

    Widget otherObject = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      width: size,
      height: size,
    );

    return Positioned(
      left: positionOffset.dx - size / 2,
      top: positionOffset.dy - size / 2,
      child: otherObject,
    );
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        if (showOtherObjects || showTrajectories) {
          for (NT4Topic nt4Topic
              in nt4Connection.nt4Client.announcedTopics.values) {
            if (nt4Topic.name.contains(topic) &&
                !nt4Topic.name.contains('Robot') &&
                !nt4Topic.name.contains('.') &&
                !otherObjectTopics.contains(nt4Topic.name)) {
              otherObjectTopics.add(nt4Topic.name);
            }
          }
        }

        List<Object?> robotPositionRaw = nt4Connection
                .getLastAnnouncedValue(robotTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<double>? robotPosition = [];
        if (robotPositionRaw.isEmpty) {
          robotPosition = null;
        } else {
          robotPosition = robotPositionRaw.whereType<double>().toList();
        }

        RenderBox? renderBox =
            context.findAncestorRenderObjectOfType<RenderBox>();

        Size size = (renderBox == null || !renderBox.hasSize)
            ? widgetSize ?? const Size(0, 0)
            : renderBox.size;

        if (size != const Size(0, 0)) {
          widgetSize = size;
        }

        Offset center = Offset(size.width / 2, size.height / 2);
        Offset fieldCenter = Offset((field!.fieldImageWidth?.toDouble() ?? 0.0),
                (field!.fieldImageHeight?.toDouble() ?? 0.0)) /
            2;

        double scaleReduction =
            (getBackgroundFitWidth(size)) / (field!.fieldImageWidth ?? 1);

        Widget robot = getTransformedFieldObject(
            robotPosition ?? [0.0, 0.0, 0.0],
            center,
            fieldCenter,
            scaleReduction,
            objectSize: Size(robotWidthMeters, robotLengthMeters));

        List<Widget> otherObjects = [];
        List<Widget> trajectoryPoints = [];

        if (showOtherObjects || showTrajectories) {
          for (String objectTopic in otherObjectTopics) {
            List<Object?>? objectPositionRaw = nt4Connection
                .getLastAnnouncedValue(objectTopic)
                ?.tryCast<List<Object?>>();

            if (objectPositionRaw == null) {
              continue;
            }

            if (objectPositionRaw.length > 24 && !showTrajectories) {
              continue;
            } else if (!showOtherObjects) {
              continue;
            }

            List<double> objectPosition =
                objectPositionRaw.whereType<double>().toList();

            for (int i = 0; i < objectPosition.length - 2; i += 3) {
              if (objectPosition.length > 24) {
                trajectoryPoints.add(getTrajectoryPoint(
                    objectPosition.sublist(i, i + 3),
                    center,
                    fieldCenter,
                    scaleReduction));
              } else {
                otherObjects.add(getTransformedFieldObject(
                    objectPosition.sublist(i, i + 3),
                    center,
                    fieldCenter,
                    scaleReduction));
              }
            }
          }
        }

        return Stack(
          children: [
            field!.fieldImage,
            ...trajectoryPoints,
            robot,
            ...otherObjects,
          ],
        );
      },
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  TrianglePainter(
      {this.strokeColor = Colors.white,
      this.strokeWidth = 3,
      this.paintingStyle = PaintingStyle.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = paintingStyle;

    canvas.drawPath(getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(x, y / 2)
      ..lineTo(0, y)
      ..lineTo(0, 0)
      ..lineTo(x, y / 2);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.paintingStyle != paintingStyle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
