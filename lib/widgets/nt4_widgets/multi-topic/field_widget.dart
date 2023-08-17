import 'dart:math';

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
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
  double robotSize = 50.0;

  double robotWidthMeters = 0.82;
  double robotLengthMeters = 1.00;

  late String robotTopicName;

  FieldWidget(
      {super.key,
      required topic,
      String? fieldName,
      period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    fieldGame = fieldName ?? fieldGame;

    init();
  }

  FieldWidget.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    fieldGame = jsonData['field_name'] ?? fieldGame;

    robotWidthMeters = jsonData['robot_width'] ?? 0.82;
    robotLengthMeters = jsonData['robot_length'] ?? 1.00;

    init();
  }

  @override
  void init() {
    super.init();

    robotTopicName = '$topic/Robot';

    field = FieldImages.getFieldFromGame(fieldGame);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'field_name': fieldGame,
      'robot_width': robotWidthMeters,
      'robot_length': robotLengthMeters,
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
          field = newField;

          refresh();
        },
        choices: FieldImages.fields.map((e) => e.game).toList(),
        initialValue: field!.game,
      ),
      const SizedBox(height: 5),
      DialogTextInput(
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
      const SizedBox(height: 5),
      DialogTextInput(
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

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        List<Object?> robotPositionRaw = nt4Connection
                .getLastAnnouncedValue(robotTopicName) as List<Object?>? ??
            [];

        List<double>? robotPosition = [];
        for (Object? object in robotPositionRaw) {
          if (object == null || object is! double) {
            robotPosition = null;
            break;
          }

          robotPosition?.add(object);
        }
        if (robotPositionRaw.isEmpty) {
          robotPosition = null;
        }

        RenderBox? renderBox =
            context.findAncestorRenderObjectOfType<RenderBox>();

        Size size = (renderBox == null || !renderBox.hasSize)
            ? const Size(0, 0)
            : renderBox.size;

        Offset center = Offset(size.width / 2, size.height / 2);
        Offset fieldCenter = Offset((field!.fieldImageWidth?.toDouble() ?? 0.0),
                (field!.fieldImageHeight?.toDouble() ?? 0.0)) /
            2;

        double scaleReduction =
            (getBackgroundFitWidth(size)) / (field!.fieldImageWidth ?? 1);

        double xFromCenter =
            (robotPosition?[0] ?? 0) * field!.pixelsPerMeterHorizontal -
                fieldCenter.dx;

        double yFromCenter = fieldCenter.dy -
            (robotPosition?[1] ?? 0) * field!.pixelsPerMeterVertical;

        Offset robotPositionOffset = center +
            (Offset(xFromCenter + field!.topLeftCorner.dx,
                    yFromCenter - field!.topLeftCorner.dy)) *
                scaleReduction;

        double robotWidth =
            robotWidthMeters * field!.pixelsPerMeterHorizontal * scaleReduction;
        double robotLength =
            robotLengthMeters * field!.pixelsPerMeterVertical * scaleReduction;

        Matrix4 transform = Matrix4.compose(
          Vector3(robotPositionOffset.dx - robotLength / 2,
              robotPositionOffset.dy - robotWidth / 2, 0),
          Quaternion.fromRotation(
              Matrix3.rotationZ(-radians(robotPosition?[2] ?? 0.0))),
          Vector3(1, 1, 1),
        );

        Widget robot = Container(
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
          width: robotLength,
          height: robotWidth,
          child: CustomPaint(
            size: Size(robotLength * 0.25, robotWidth * 0.25),
            painter: TrianglePainter(
                strokeColor: const Color.fromARGB(255, 0, 255, 0)),
          ),
        );

        return Stack(children: [
          field!.fieldImage,
          Transform(
            origin: Offset(robotLength, robotWidth) / 2,
            transform: transform,
            child: robot,
          ),
        ]);
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
