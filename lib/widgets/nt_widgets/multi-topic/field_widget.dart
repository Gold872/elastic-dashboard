import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class FieldWidgetModel extends NTWidgetModel {
  @override
  String type = 'Field';

  static const String _defaultGame = 'Crescendo';
  String _fieldGame = _defaultGame;
  late Field _field;

  double _robotWidthMeters = 0.85;
  double _robotLengthMeters = 0.85;

  bool _showOtherObjects = true;
  bool _showTrajectories = true;

  final double _otherObjectSize = 0.55;
  final double _trajectoryPointSize = 0.08;

  Size? _widgetSize;

  late String _robotTopicName;
  final List<String> _otherObjectTopics = [];

  bool rendered = false;

  late Function(NT4Topic topic) topicAnnounceListener;

  FieldWidgetModel({
    required super.topic,
    String? fieldName,
    bool showOtherObjects = true,
    bool showTrajectories = true,
    super.dataType,
    super.period,
  })  : _showTrajectories = showTrajectories,
        _showOtherObjects = showOtherObjects,
        super() {
    _fieldGame = fieldName ?? _fieldGame;

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    _field = FieldImages.getFieldFromGame(_fieldGame)!;
  }

  FieldWidgetModel.fromJson({required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _fieldGame = tryCast(jsonData['field_game']) ?? _fieldGame;

    _robotWidthMeters = tryCast(jsonData['robot_width']) ?? 0.85;
    _robotLengthMeters = tryCast(jsonData['robot_length']) ??
        tryCast(jsonData['robot_height']) ??
        0.85;

    _showOtherObjects = tryCast(jsonData['show_other_objects']) ?? true;
    _showTrajectories = tryCast(jsonData['show_trajectories']) ?? true;

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    _field = FieldImages.getFieldFromGame(_fieldGame)!;
  }

  @override
  void init() {
    super.init();

    _robotTopicName = '$topic/Robot';

    topicAnnounceListener = (nt4Topic) {
      if (nt4Topic.name.contains(topic) &&
          !nt4Topic.name.contains('Robot') &&
          !nt4Topic.name.contains('.') &&
          !_otherObjectTopics.contains(nt4Topic.name)) {
        _otherObjectTopics.add(nt4Topic.name);
      }
    };

    ntConnection.nt4Client.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void resetSubscription() {
    _robotTopicName = '$topic/Robot';
    _otherObjectTopics.clear();

    super.resetSubscription();
  }

  @override
  void disposeWidget({bool deleting = false}) {
    super.disposeWidget(deleting: deleting);

    if (deleting) {
      _field.dispose();
      ntConnection.nt4Client.removeTopicAnnounceListener(topicAnnounceListener);
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
      DialogDropdownChooser(
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
              formatter: Constants.decimalTextFormatter(),
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
              formatter: Constants.decimalTextFormatter(),
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
    ];
  }

  @override
  List<Object> getCurrentData() {
    List<Object> data = [];

    List<Object?> robotPositionRaw = ntConnection
            .getLastAnnouncedValue(_robotTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<double> robotPosition = robotPositionRaw.whereType<double>().toList();

    data.addAll(robotPosition);

    if (_showOtherObjects || _showTrajectories) {
      for (String objectTopic in _otherObjectTopics) {
        List<Object?>? objectPositionRaw = ntConnection
            .getLastAnnouncedValue(objectTopic)
            ?.tryCast<List<Object?>>();

        if (objectPositionRaw == null) {
          continue;
        }

        bool isTrajectory = objectPositionRaw.length > 24;

        if (isTrajectory && !_showTrajectories) {
          continue;
        } else if (!_showOtherObjects && !isTrajectory) {
          continue;
        }

        List<double> objectPosition =
            objectPositionRaw.whereType<double>().toList();

        data.addAll(objectPosition);
      }
    }

    return data;
  }

  @override
  Stream<Object> get multiTopicPeriodicStream async* {
    final Duration delayTime = Duration(
        microseconds: ((subscription?.options.periodicRateSeconds ??
                    Settings.defaultPeriod) *
                1e6)
            .round());

    yield Object();

    int previousHash = Object.hashAll(getCurrentData());

    while (true) {
      int currentHash = Object.hashAll(getCurrentData());

      if (previousHash != currentHash) {
        yield Object();
        previousHash = currentHash;
      } else if (!rendered) {
        yield Object();
      }

      await Future.delayed(delayTime);
    }
  }

  get robotWidthMeters => _robotWidthMeters;

  set robotWidthMeters(value) {
    _robotWidthMeters = value;
    refresh();
  }

  get robotLengthMeters => _robotLengthMeters;

  set robotLengthMeters(value) {
    _robotLengthMeters = value;
    refresh();
  }

  get showOtherObjects => _showOtherObjects;

  set showOtherObjects(value) {
    _showOtherObjects = value;
    refresh();
  }

  get showTrajectories => _showTrajectories;

  set showTrajectories(value) {
    _showTrajectories = value;
    refresh();
  }

  get otherObjectSize => _otherObjectSize;

  get trajectoryPointSize => _trajectoryPointSize;

  get widgetSize => _widgetSize;

  set widgetSize(value) {
    _widgetSize = value;
  }

  get field => _field;
}

class FieldWidget extends NTWidget {
  static const String widgetType = 'Field';

  const FieldWidget({super.key});

  double _getBackgroundFitWidth(FieldWidgetModel model, Size size) {
    double fitWidth = size.width;
    double fitHeight = size.height;

    return min(
        fitWidth,
        fitHeight /
            ((model._field.fieldImageHeight ?? 0) /
                (model._field.fieldImageWidth ?? 1)));
  }

  Widget _getTransformedFieldObject(
      FieldWidgetModel model,
      List<double> objectPosition,
      Offset center,
      Offset fieldCenter,
      double scaleReduction,
      {Size? objectSize}) {
    for (int i = 0; i < objectPosition.length; i++) {
      if (!objectPosition[i].isFinite) {
        objectPosition[i] = 0.0;
      }
    }

    double xFromCenter =
        (objectPosition[0]) * model.field.pixelsPerMeterHorizontal -
            fieldCenter.dx;

    double yFromCenter = fieldCenter.dy -
        (objectPosition[1]) * model.field.pixelsPerMeterVertical;

    Offset positionOffset = center +
        (Offset(xFromCenter + model.field.topLeftCorner.dx,
                yFromCenter - model.field.topLeftCorner.dy)) *
            scaleReduction;

    double width = (objectSize?.width ?? model.otherObjectSize) *
        model.field.pixelsPerMeterHorizontal *
        scaleReduction;

    double length = (objectSize?.height ?? model.otherObjectSize) *
        model.field.pixelsPerMeterVertical *
        scaleReduction;

    Matrix4 transform = Matrix4.translationValues(
        positionOffset.dx - length / 2, positionOffset.dy - width / 2, 0.0)
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

  Offset _getTransformedTrajectoryPoint(
      FieldWidgetModel model,
      List<double> objectPosition,
      Offset center,
      Offset fieldCenter,
      double scaleReduction) {
    for (int i = 0; i < objectPosition.length; i++) {
      if (!objectPosition[i].isFinite) {
        objectPosition[i] = 0.0;
      }
    }

    double xFromCenter =
        (objectPosition[0]) * model.field.pixelsPerMeterHorizontal -
            fieldCenter.dx;

    double yFromCenter = fieldCenter.dy -
        (objectPosition[1]) * model.field.pixelsPerMeterVertical;

    Offset positionOffset = center +
        (Offset(xFromCenter + model.field.topLeftCorner.dx,
                yFromCenter - model.field.topLeftCorner.dy)) *
            scaleReduction;

    return positionOffset;
  }

  @override
  Widget build(BuildContext context) {
    FieldWidgetModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        List<Object?> robotPositionRaw = ntConnection
                .getLastAnnouncedValue(model._robotTopicName)
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
            ? model.widgetSize ?? const Size(0, 0)
            : renderBox.size;

        if (size != const Size(0, 0)) {
          model.widgetSize = size;
        }

        Offset center = Offset(size.width / 2, size.height / 2);
        Offset fieldCenter = Offset(
                (model.field.fieldImageWidth?.toDouble() ?? 0.0),
                (model.field.fieldImageHeight?.toDouble() ?? 0.0)) /
            2;

        double scaleReduction = (_getBackgroundFitWidth(model, size)) /
            (model.field.fieldImageWidth ?? 1);

        if (!model.rendered &&
            renderBox != null &&
            model.widgetSize != null &&
            size != const Size(0, 0) &&
            size.width > 100.0 &&
            scaleReduction != 0.0 &&
            fieldCenter != const Offset(0.0, 0.0) &&
            model.field.fieldImageLoaded) {
          model.rendered = true;
        }

        Widget robot = _getTransformedFieldObject(
            model,
            robotPosition ?? [0.0, 0.0, 0.0],
            center,
            fieldCenter,
            scaleReduction,
            objectSize: Size(model.robotWidthMeters, model.robotLengthMeters));

        List<Widget> otherObjects = [];
        List<List<Offset>> trajectoryPoints = [];

        if (model.showOtherObjects || model.showTrajectories) {
          for (String objectTopic in model._otherObjectTopics) {
            List<Object?>? objectPositionRaw = ntConnection
                .getLastAnnouncedValue(objectTopic)
                ?.tryCast<List<Object?>>();

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
                  _getTransformedTrajectoryPoint(
                    model,
                    objectPosition.sublist(i, i + 2),
                    center,
                    fieldCenter,
                    scaleReduction,
                  ),
                );
              } else {
                otherObjects.add(
                  _getTransformedFieldObject(
                    model,
                    objectPosition.sublist(i, i + 3),
                    center,
                    fieldCenter,
                    scaleReduction,
                  ),
                );
              }
            }
          }
        }

        return Stack(
          children: [
            model.field.fieldImage,
            for (List<Offset> points in trajectoryPoints)
              CustomPaint(
                painter: TrajectoryPainter(
                  points: points,
                  strokeWidth: model.trajectoryPointSize *
                      model.field.pixelsPerMeterHorizontal *
                      scaleReduction,
                ),
              ),
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

class TrajectoryPainter extends CustomPainter {
  final List<Offset> points;
  final double strokeWidth;

  TrajectoryPainter({
    required this.points,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    Paint trajectoryPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path trajectoryPath = Path();

    trajectoryPath.moveTo(points[0].dx, points[0].dy);

    for (Offset point in points) {
      trajectoryPath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(trajectoryPath, trajectoryPaint);
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
