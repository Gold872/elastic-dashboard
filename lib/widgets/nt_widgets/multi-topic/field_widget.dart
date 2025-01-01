import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

extension _SizeUtils on Size {
  Offset get toOffset => Offset(width, height);

  Size rotateBy(double angle) => Size(
        (width * cos(angle) - height * sin(angle)).abs(),
        (height * cos(angle) + width * sin(angle)).abs(),
      );
}

class FieldWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = 'Field';

  String get robotTopicName => '$topic/Robot';
  late NT4Subscription robotSubscription;

  final List<String> _otherObjectTopics = [];
  final List<NT4Subscription> _otherObjectSubscriptions = [];

  @override
  List<NT4Subscription> get subscriptions => [
        robotSubscription,
        ..._otherObjectSubscriptions,
      ];

  bool rendered = false;

  late Function(NT4Topic topic) topicAnnounceListener;

  static const String _defaultGame = 'Crescendo';
  String _fieldGame = _defaultGame;
  late Field _field;

  double _robotWidthMeters = 0.85;
  double _robotLengthMeters = 0.85;

  bool _showOtherObjects = true;
  bool _showTrajectories = true;

  double _fieldRotation = 0.0;

  Color _robotColor = Colors.red;
  Color _trajectoryColor = Colors.white;

  final double _otherObjectSize = 0.55;
  final double _trajectoryPointSize = 0.08;

  Size? _widgetSize;

  double get robotWidthMeters => _robotWidthMeters;

  set robotWidthMeters(double value) {
    _robotWidthMeters = value;
    refresh();
  }

  double get robotLengthMeters => _robotLengthMeters;

  set robotLengthMeters(double value) {
    _robotLengthMeters = value;
    refresh();
  }

  bool get showOtherObjects => _showOtherObjects;

  set showOtherObjects(bool value) {
    _showOtherObjects = value;
    refresh();
  }

  bool get showTrajectories => _showTrajectories;

  set showTrajectories(bool value) {
    _showTrajectories = value;
    refresh();
  }

  double get fieldRotation => _fieldRotation;

  set fieldRotation(double value) {
    _fieldRotation = value;
    refresh();
  }

  Color get robotColor => _robotColor;

  set robotColor(Color value) {
    _robotColor = value;
    refresh();
  }

  Color get trajectoryColor => _trajectoryColor;

  set trajectoryColor(Color value) {
    _trajectoryColor = value;
    refresh();
  }

  double get otherObjectSize => _otherObjectSize;

  double get trajectoryPointSize => _trajectoryPointSize;

  Size? get widgetSize => _widgetSize;

  set widgetSize(value) {
    _widgetSize = value;
  }

  Field get field => _field;

  FieldWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String? fieldGame,
    bool showOtherObjects = true,
    bool showTrajectories = true,
    double robotWidthMeters = 0.85,
    double robotLengthMeters = 0.85,
    double fieldRotation = 0.0,
    Color robotColor = Colors.red,
    Color trajectoryColor = Colors.white,
    super.dataType,
    super.period,
  })  : _showTrajectories = showTrajectories,
        _showOtherObjects = showOtherObjects,
        _robotWidthMeters = robotWidthMeters,
        _robotLengthMeters = robotLengthMeters,
        _fieldRotation = fieldRotation,
        _robotColor = robotColor,
        _trajectoryColor = trajectoryColor,
        super() {
    _fieldGame = fieldGame ?? _fieldGame;

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    _field = FieldImages.getFieldFromGame(_fieldGame)!;
  }

  FieldWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _fieldGame = tryCast(jsonData['field_game']) ?? _fieldGame;

    _robotWidthMeters = tryCast(jsonData['robot_width']) ?? 0.85;
    _robotLengthMeters = tryCast(jsonData['robot_length']) ??
        tryCast(jsonData['robot_height']) ??
        0.85;

    _showOtherObjects = tryCast(jsonData['show_other_objects']) ?? true;
    _showTrajectories = tryCast(jsonData['show_trajectories']) ?? true;

    _fieldRotation = tryCast(jsonData['field_rotation']) ?? 0.0;

    _robotColor = Color(tryCast(jsonData['robot_color']) ?? Colors.red.value);
    _trajectoryColor =
        Color(tryCast(jsonData['trajectory_color']) ?? Colors.white.value);

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    _field = FieldImages.getFieldFromGame(_fieldGame)!;
  }

  @override
  void init() {
    super.init();

    topicAnnounceListener = (nt4Topic) {
      if (nt4Topic.name.contains(topic) &&
          !nt4Topic.name.contains('Robot') &&
          !nt4Topic.name.contains('.') &&
          !_otherObjectTopics.contains(nt4Topic.name)) {
        _otherObjectTopics.add(nt4Topic.name);
        _otherObjectSubscriptions
            .add(ntConnection.subscribe(nt4Topic.name, super.period));
        refresh();
      }
    };

    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void initializeSubscriptions() {
    _otherObjectSubscriptions.clear();

    robotSubscription = ntConnection.subscribe(robotTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _otherObjectTopics.clear();

    super.resetSubscription();

    // If the topic changes the other objects need to be found under the new root table
    ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void disposeWidget({bool deleting = false}) {
    super.disposeWidget(deleting: deleting);

    if (deleting) {
      _field.dispose();
      ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    }

    _widgetSize = null;
    rendered = false;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'field_game': _fieldGame,
      'robot_width': _robotWidthMeters,
      'robot_length': _robotLengthMeters,
      'show_other_objects': _showOtherObjects,
      'show_trajectories': _showTrajectories,
      'field_rotation': _fieldRotation,
      'robot_color': robotColor.value,
      'trajectory_color': trajectoryColor.value,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: RichText(
          text: TextSpan(
            text: 'Field Image (',
            children: [
              WidgetSpan(
                child: Tooltip(
                  waitDuration: const Duration(milliseconds: 750),
                  richMessage: WidgetSpan(
                    // Builder is used so the message updates when the field image is changed
                    child: Builder(
                      builder: (context) {
                        return Text(
                          _field.sourceURL ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: Colors.black),
                        );
                      },
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: 'Source',
                      style: const TextStyle(color: Colors.blue),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          if (_field.sourceURL == null) {
                            return;
                          }
                          Uri? url = Uri.tryParse(_field.sourceURL!);
                          if (url == null) {
                            return;
                          }
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ')'),
            ],
          ),
        ),
      ),
      DialogDropdownChooser<String?>(
        onSelectionChanged: (value) {
          if (value == null) {
            return;
          }

          Field? newField = FieldImages.getFieldFromGame(value);

          if (newField == null) {
            return;
          }

          _fieldGame = value;
          _field.dispose();
          _field = newField;

          widgetSize = null;
          rendered = false;

          refresh();
        },
        choices: FieldImages.fields.map((e) => e.game).toList(),
        initialValue: _field.game,
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
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Robot Width (meters)',
              initialText: _robotWidthMeters.toString(),
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newLength = double.tryParse(value);

                if (newLength == null) {
                  return;
                }
                robotLengthMeters = newLength;
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Robot Length (meters)',
              initialText: _robotLengthMeters.toString(),
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
              initialValue: _showOtherObjects,
              onToggle: (value) {
                showOtherObjects = value;
              },
            ),
          ),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Trajectories',
              initialValue: _showTrajectories,
              onToggle: (value) {
                showTrajectories = value;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
                label: const Text('Rotate Left'),
                icon: const Icon(Icons.rotate_90_degrees_ccw),
                onPressed: () {
                  double newRotation = fieldRotation - 90;
                  if (newRotation < -180) {
                    newRotation += 360;
                  }
                  fieldRotation = newRotation;
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
                label: const Text('Rotate Right'),
                icon: const Icon(Icons.rotate_90_degrees_cw),
                onPressed: () {
                  double newRotation = fieldRotation + 90;
                  if (newRotation > 180) {
                    newRotation -= 360;
                  }
                  fieldRotation = newRotation;
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: DialogColorPicker(
                onColorPicked: (color) {
                  robotColor = color;
                },
                label: 'Robot Color',
                initialColor: robotColor,
                defaultColor: Colors.red,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: DialogColorPicker(
                onColorPicked: (color) {
                  trajectoryColor = color;
                },
                label: 'Trajectory Color',
                initialColor: trajectoryColor,
                defaultColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

class FieldWidget extends NTWidget {
  static const String widgetType = 'Field';

  const FieldWidget({super.key});

  Widget _getTransformedFieldObject(
    FieldWidgetModel model, {
    required List<double> objectPosition,
    required Offset fieldCenter,
    required double scaleReduction,
    Size? objectSize,
  }) {
    for (int i = 0; i < objectPosition.length; i++) {
      if (!objectPosition[i].isFinite) {
        objectPosition[i] = 0.0;
      }
    }

    double xFromCenter =
        (objectPosition[0] * model.field.pixelsPerMeterHorizontal -
                fieldCenter.dx) *
            scaleReduction;

    double yFromCenter = (fieldCenter.dy -
            (objectPosition[1] * model.field.pixelsPerMeterVertical)) *
        scaleReduction;

    double width = (objectSize?.width ?? model.otherObjectSize) *
        model.field.pixelsPerMeterHorizontal *
        scaleReduction;

    double length = (objectSize?.height ?? model.otherObjectSize) *
        model.field.pixelsPerMeterVertical *
        scaleReduction;

    Matrix4 transform = Matrix4.translationValues(xFromCenter, yFromCenter, 0.0)
      ..rotateZ(-radians(objectPosition[2]));

    Widget otherObject = Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(
        minWidth: 4.0,
        minHeight: 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        border: Border.all(
          color: model.robotColor,
          width: 0.125 * min(width, length),
        ),
      ),
      width: length,
      height: width,
      child: CustomPaint(
        size: Size(length * 0.275, width * 0.275),
        painter: TrianglePainter(
          strokeWidth: 0.08 * min(width, length),
        ),
      ),
    );

    return Transform(
      origin: Offset(length, width) / 2,
      transform: transform,
      child: otherObject,
    );
  }

  Offset _getTrajectoryPointOffset(
    FieldWidgetModel model, {
    required List<double> objectPosition,
    required Offset fieldCenter,
    required double scaleReduction,
  }) {
    for (int i = 0; i < objectPosition.length; i++) {
      if (!objectPosition[i].isFinite) {
        objectPosition[i] = 0.0;
      }
    }

    double xFromCenter =
        (objectPosition[0] * model.field.pixelsPerMeterHorizontal -
                fieldCenter.dx) *
            scaleReduction;

    double yFromCenter = (fieldCenter.dy -
            (objectPosition[1] * model.field.pixelsPerMeterVertical)) *
        scaleReduction;

    return Offset(xFromCenter, yFromCenter);
  }

  @override
  Widget build(BuildContext context) {
    FieldWidgetModel model = cast(context.watch<NTWidgetModel>());

    List<NT4Subscription> listeners = [];
    listeners.add(model.robotSubscription);
    if (model._showOtherObjects || model._showTrajectories) {
      listeners.addAll(model._otherObjectSubscriptions);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: Listenable.merge(listeners),
          child: model.field.fieldImage,
          builder: (context, child) {
            List<Object?> robotPositionRaw =
                model.robotSubscription.value?.tryCast<List<Object?>>() ?? [];

            List<double>? robotPosition = [];
            if (robotPositionRaw.isEmpty) {
              robotPosition = null;
            } else {
              robotPosition = robotPositionRaw.whereType<double>().toList();
            }

            Size size = Size(constraints.maxWidth, constraints.maxHeight);

            model.widgetSize = size;

            FittedSizes fittedSizes = applyBoxFit(
              BoxFit.contain,
              model.field.fieldImageSize ?? const Size(0, 0),
              size,
            );

            FittedSizes rotatedFittedSizes = applyBoxFit(
              BoxFit.contain,
              model.field.fieldImageSize
                      ?.rotateBy(-radians(model.fieldRotation)) ??
                  const Size(0, 0),
              size,
            );

            Offset fittedCenter = fittedSizes.destination.toOffset / 2;
            Offset fieldCenter = model.field.center;

            double scaleReduction =
                (fittedSizes.destination.width / fittedSizes.source.width);
            double rotatedScaleReduction =
                (rotatedFittedSizes.destination.width /
                    rotatedFittedSizes.source.width);

            if (!model.rendered &&
                model.widgetSize != null &&
                size != const Size(0, 0) &&
                size.width > 100.0 &&
                scaleReduction != 0.0 &&
                fieldCenter != const Offset(0.0, 0.0) &&
                model.field.fieldImageLoaded) {
              model.rendered = true;
            }

            // Try rebuilding again if the image isn't fully rendered
            // Can't do it if it's in a unit test cause it causes issues with timers running
            if (!model.rendered &&
                !Platform.environment.containsKey('FLUTTER_TEST')) {
              Future.delayed(const Duration(milliseconds: 100), model.refresh);
            }

            Widget robot = _getTransformedFieldObject(
              model,
              objectPosition: robotPosition ?? [0.0, 0.0, 0.0],
              fieldCenter: fieldCenter,
              scaleReduction: scaleReduction,
              objectSize: Size(model.robotWidthMeters, model.robotLengthMeters),
            );

            List<Widget> otherObjects = [];
            List<List<Offset>> trajectoryPoints = [];

            if (model.showOtherObjects || model.showTrajectories) {
              for (NT4Subscription objectSubscription
                  in model._otherObjectSubscriptions) {
                List<Object?>? objectPositionRaw =
                    objectSubscription.value?.tryCast<List<Object?>>();

                if (objectPositionRaw == null) {
                  continue;
                }

                bool isTrajectory = objectPositionRaw.length > 24;

                if (isTrajectory && !model.showTrajectories) {
                  continue;
                } else if (!model.showOtherObjects && !isTrajectory) {
                  continue;
                }

                List<double> objectPosition =
                    objectPositionRaw.whereType<double>().toList();

                if (isTrajectory) {
                  trajectoryPoints.add([]);
                }

                for (int i = 0; i < objectPosition.length - 2; i += 3) {
                  if (isTrajectory) {
                    trajectoryPoints.last.add(
                      _getTrajectoryPointOffset(
                        model,
                        objectPosition: objectPosition.sublist(i, i + 2),
                        fieldCenter: fieldCenter,
                        scaleReduction: scaleReduction,
                      ),
                    );
                  } else {
                    otherObjects.add(
                      _getTransformedFieldObject(
                        model,
                        objectPosition: objectPosition.sublist(i, i + 3),
                        fieldCenter: fieldCenter,
                        scaleReduction: scaleReduction,
                      ),
                    );
                  }
                }
              }
            }

            return Transform.scale(
              scale: rotatedScaleReduction / scaleReduction,
              child: Transform.rotate(
                angle: radians(model.fieldRotation),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: fittedSizes.destination.width,
                      height: fittedSizes.destination.height,
                      child: child!,
                    ),
                    for (List<Offset> points in trajectoryPoints)
                      CustomPaint(
                        size: fittedSizes.destination,
                        painter: TrajectoryPainter(
                          center: fittedCenter,
                          color: model.trajectoryColor,
                          points: points,
                          strokeWidth: model.trajectoryPointSize *
                              model.field.pixelsPerMeterHorizontal *
                              scaleReduction,
                        ),
                      ),
                    robot,
                    ...otherObjects,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  TrianglePainter({
    this.strokeColor = Colors.white,
    this.strokeWidth = 3,
    this.paintingStyle = PaintingStyle.stroke,
  });

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

class TrajectoryPainter extends CustomPainter {
  final Offset center;
  final List<Offset> points;
  final double strokeWidth;
  final Color color;

  TrajectoryPainter({
    required this.center,
    required this.points,
    required this.strokeWidth,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    Paint trajectoryPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path trajectoryPath = Path();

    trajectoryPath.moveTo(points[0].dx + center.dx, points[0].dy + center.dy);

    for (Offset point in points) {
      trajectoryPath.lineTo(point.dx + center.dx, point.dy + center.dy);
    }
    canvas.drawPath(trajectoryPath, trajectoryPaint);
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
