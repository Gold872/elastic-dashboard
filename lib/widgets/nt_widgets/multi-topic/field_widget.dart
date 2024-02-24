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

class FieldWidget extends NTWidget {
  static const String widgetType = 'Field';
  @override
  String type = widgetType;

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

  bool _rendered = false;

  FieldWidget({
    super.key,
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

  FieldWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
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
  }

  @override
  void resetSubscription() {
    _robotTopicName = '$topic/Robot';
    _otherObjectTopics.clear();

    super.resetSubscription();
  }

  @override
  void dispose({bool deleting = false}) {
    super.dispose(deleting: deleting);

    if (deleting) {
      _field.dispose();
    }

    _widgetSize = null;
    _rendered = false;
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

          _widgetSize = null;
          _rendered = false;

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
                _robotWidthMeters = newWidth;
                refresh();
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
                _robotLengthMeters = newLength;
                refresh();
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
                _showOtherObjects = value;

                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Trajectories',
              initialValue: _showTrajectories,
              onToggle: (value) {
                _showTrajectories = value;

                refresh();
              },
            ),
          ),
        ],
      ),
    ];
  }

  double _getBackgroundFitWidth(Size size) {
    double fitWidth = size.width;
    double fitHeight = size.height;

    return min(
        fitWidth,
        fitHeight /
            ((_field.fieldImageHeight ?? 0) / (_field.fieldImageWidth ?? 1)));
  }

  Widget _getTransformedFieldObject(List<double> objectPosition, Offset center,
      Offset fieldCenter, double scaleReduction,
      {Size? objectSize}) {
    for (int i = 0; i < objectPosition.length; i++) {
      if (!objectPosition[i].isFinite) {
        objectPosition[i] = 0.0;
      }
    }

    double xFromCenter =
        (objectPosition[0]) * _field.pixelsPerMeterHorizontal - fieldCenter.dx;

    double yFromCenter =
        fieldCenter.dy - (objectPosition[1]) * _field.pixelsPerMeterVertical;

    Offset positionOffset = center +
        (Offset(xFromCenter + _field.topLeftCorner.dx,
                yFromCenter - _field.topLeftCorner.dy)) *
            scaleReduction;

    double width = (objectSize?.width ?? _otherObjectSize) *
        _field.pixelsPerMeterHorizontal *
        scaleReduction;

    double length = (objectSize?.height ?? _otherObjectSize) *
        _field.pixelsPerMeterVertical *
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

  Offset _getTransformedTrajectoryPoint(List<double> objectPosition,
      Offset center, Offset fieldCenter, double scaleReduction) {
    for (int i = 0; i < objectPosition.length; i++) {
      if (!objectPosition[i].isFinite) {
        objectPosition[i] = 0.0;
      }
    }

    double xFromCenter =
        (objectPosition[0]) * _field.pixelsPerMeterHorizontal - fieldCenter.dx;

    double yFromCenter =
        fieldCenter.dy - (objectPosition[1]) * _field.pixelsPerMeterVertical;

    Offset positionOffset = center +
        (Offset(xFromCenter + _field.topLeftCorner.dx,
                yFromCenter - _field.topLeftCorner.dy)) *
            scaleReduction;

    return positionOffset;
  }

  void _updateOtherObjectTopics() {
    for (NT4Topic nt4Topic in ntConnection.nt4Client.announcedTopics.values) {
      if (nt4Topic.name.contains(topic) &&
          !nt4Topic.name.contains('Robot') &&
          !nt4Topic.name.contains('.') &&
          !_otherObjectTopics.contains(nt4Topic.name)) {
        _otherObjectTopics.add(nt4Topic.name);
      }
    }
  }

  @override
  List<Object> getCurrentData() {
    List<Object> data = [];

    List<Object?> robotPositionRaw = ntConnection
            .getLastAnnouncedValue(_robotTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<double> robotPosition = robotPositionRaw.whereType<double>().toList();

    data.add(robotPosition);

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

        data.add(objectPosition);
      }
    }

    data.addAll([
      _showOtherObjects,
      _showTrajectories,
      _robotWidthMeters,
      _robotLengthMeters,
      _otherObjectTopics,
      _fieldGame,
    ]);

    return data;
  }

  @override
  Stream<Object> get multiTopicPeriodicStream async* {
    yield Object();

    List<Object> previousData = getCurrentData();

    while (true) {
      _updateOtherObjectTopics();

      List<Object> currentData = getCurrentData();

      if (!NTWidget.listEquals(previousData, currentData)) {
        yield Object();
        previousData = currentData;
      } else if (!_rendered) {
        yield Object();
      }

      await Future.delayed(Duration(
          milliseconds: ((subscription?.options.periodicRateSeconds ??
                      Settings.defaultPeriod) *
                  1000)
              .round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        if (_showOtherObjects || _showTrajectories) {
          _updateOtherObjectTopics();
        }

        List<Object?> robotPositionRaw = ntConnection
                .getLastAnnouncedValue(_robotTopicName)
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
            ? _widgetSize ?? const Size(0, 0)
            : renderBox.size;

        if (size != const Size(0, 0)) {
          _widgetSize = size;
        }

        Offset center = Offset(size.width / 2, size.height / 2);
        Offset fieldCenter = Offset((_field.fieldImageWidth?.toDouble() ?? 0.0),
                (_field.fieldImageHeight?.toDouble() ?? 0.0)) /
            2;

        double scaleReduction =
            (_getBackgroundFitWidth(size)) / (_field.fieldImageWidth ?? 1);

        if (renderBox != null &&
            _widgetSize != null &&
            size != const Size(0, 0) &&
            size.width > 100.0 &&
            scaleReduction != 0.0 &&
            robotPosition != null &&
            fieldCenter != const Offset(0.0, 0.0) &&
            _field.fieldImageLoaded) {
          _rendered = true;
        }

        Widget robot = _getTransformedFieldObject(
            robotPosition ?? [0.0, 0.0, 0.0],
            center,
            fieldCenter,
            scaleReduction,
            objectSize: Size(_robotWidthMeters, _robotLengthMeters));

        List<Widget> otherObjects = [];
        List<List<Offset>> trajectoryPoints = [];

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

            if (isTrajectory) {
              trajectoryPoints.add([]);
            }

            for (int i = 0; i < objectPosition.length - 2; i += 3) {
              if (isTrajectory) {
                trajectoryPoints.last.add(
                  _getTransformedTrajectoryPoint(
                    objectPosition.sublist(i, i + 2),
                    center,
                    fieldCenter,
                    scaleReduction,
                  ),
                );
              } else {
                otherObjects.add(
                  _getTransformedFieldObject(
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
            _field.fieldImage,
            for (List<Offset> points in trajectoryPoints)
              CustomPaint(
                painter: TrajectoryPainter(
                  points: points,
                  strokeWidth: _trajectoryPointSize *
                      _field.pixelsPerMeterHorizontal *
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
