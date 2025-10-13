import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../dialog_widgets/dialog_color_picker.dart';

class CameraStreamModel extends MultiTopicNTWidgetModel {
  @override
  String type = CameraStreamWidget.widgetType;

  String get streamsTopic => '$topic/streams';

  late NT4Subscription streamsSubscription;

  @override
  List<NT4Subscription> get subscriptions => [streamsSubscription];

  int? quality;
  int? fps;
  Size? resolution;
  int _rotationTurns = 0;
  bool _crosshairEnabled = false;
  int _crosshairX = 0;
  int _crosshairY = 0;
  int _crosshairWidth = 25;
  int _crosshairHeight = 25;
  int _crosshairThickness = 2;
  Color _crosshairColor = Colors.red;
  bool _crosshairCentered = false;

  bool get crosshairCentered => _crosshairCentered;

  set crosshairCentered(bool value) => _crosshairCentered = value;

  Color get crosshairColor => _crosshairColor;

  set crosshairColor(Color value) => _crosshairColor = value;

  bool get crosshairEnabled => _crosshairEnabled;

  set crosshairEnabled(bool value) => _crosshairEnabled = value;

  int get crosshairX => _crosshairX;

  set crosshairX(int value) => _crosshairX = value;

  int get crosshairY => _crosshairY;

  set crosshairY(int value) => _crosshairY = value;

  int get crosshairWidth => _crosshairWidth;

  set crosshairWidth(int value) => _crosshairWidth = value;

  int get crosshairHeight => _crosshairHeight;

  set crosshairHeight(int value) => _crosshairHeight = value;

  int get crosshairThickness => _crosshairThickness;

  set crosshairThickness(int value) => _crosshairThickness = value;

  int get rotationTurns => _rotationTurns;

  set rotationTurns(int value) {
    _rotationTurns = value;
    notifyListeners();
  }

  String getUrlWithParameters(String urlString) {
    Uri url = Uri.parse(urlString);

    Map<String, String> parameters = Map<String, String>.from(
      url.queryParameters,
    );

    parameters.addAll({
      if (resolution != null &&
          resolution!.width != 0.0 &&
          resolution!.height != 0.0)
        'resolution':
            '${resolution!.width.floor()}x${resolution!.height.floor()}',
      if (fps != null) 'fps': '$fps',
      if (quality != null) 'compression': '$quality',
    });

    return url.replace(queryParameters: parameters).toString();
  }

  CameraStreamModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    int? compression,
    this.fps,
    this.resolution,
    int rotation = 0,
    bool crosshairEnabled = false,
    int crosshairWidth = 50,
    int crosshairHeight = 50,
    int crosshairThickness = 2,
    int crosshairX = 0,
    int crosshairY = 0,
    Color crosshairColor = Colors.red,
    super.dataType,
    super.period,
  })  : quality = compression,
        _fps = fps,
        _resolution = resolution,
        _rotationTurns = rotation,
        _crosshairEnabled = crosshairEnabled,
        _crosshairWidth = crosshairWidth,
        _crosshairHeight = crosshairHeight,
        _crosshairThickness = crosshairThickness,
        _crosshairX = crosshairX,
        _crosshairY = crosshairY,
        _crosshairColor = crosshairColor,
        super();

  CameraStreamModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    quality = tryCast(jsonData['compression']);
    fps = tryCast(jsonData['fps']);
    _crosshairEnabled = tryCast(jsonData['crosshair_enabled']) ?? false;
    _rotationTurns = tryCast(jsonData['rotation_turns']) ?? 0;
    _crosshairWidth = tryCast(jsonData['crosshair_width']) ?? 25;
    _crosshairHeight = tryCast(jsonData['crosshair_height']) ?? 25;
    _crosshairThickness = tryCast(jsonData['crosshair_thickness']) ?? 2;
    _crosshairX = tryCast(jsonData['crosshair_x']) ?? 0;
    _crosshairY = tryCast(jsonData['crosshair_y']) ?? 0;
    _crosshairColor = Color(
        tryCast<int>(jsonData['crosshair_color']) ?? Colors.red.toARGB32());
    _crosshairCentered = tryCast(jsonData['crosshair_centered']) ?? false;

    List<num>? resolution = tryCast<List<Object?>>(
      jsonData['resolution'],
    )?.whereType<num>().toList();

    if (resolution != null && resolution.length > 1) {
      if (resolution[0] % 2 != 0) {
        resolution[0] += 1;
      }
      if (resolution[0] > 0 && resolution[1] > 0) {
        this.resolution = Size(
          resolution[0].toDouble(),
          resolution[1].toDouble(),
        );
      }
    }
  }

  @override
  void init() {
    ntConnection.ntConnected.addListener(onNTConnected);
    super.init();
  }

  @override
  void initializeSubscriptions() {
    streamsSubscription = ntConnection.subscribe(streamsTopic, super.period);
  }

  @override
  void resetSubscription() {
    closeClient();

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'rotation_turns': _rotationTurns,
      'crosshair_enabled': crosshairEnabled,
      'crosshair_width': crosshairWidth,
      'crosshair_height': crosshairHeight,
      'crosshair_thickness': crosshairThickness,
      'crosshair_x': crosshairX,
      'crosshair_y': crosshairY,
      'crosshair_color': _crosshairColor.toARGB32(),
      'crosshair_centered': _crosshairCentered,
      if (quality != null) 'compression': quality,
      if (fps != null) 'fps': fps,
      if (resolution != null)
        'resolution': [
          resolution!.width,
          resolution!.height,
        ],
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: fps?.toString() ?? '-1',
              label: 'FPS',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newFPS = int.tryParse(value);

                setState(() {
                  if (newFPS == -1 || newFPS == 0) {
                    fps = null;
                    return;
                  }

                  fps = newFPS;
                });
              },
            ),
          ),
          const SizedBox(width: 10.0),
          const Text('Resolution'),
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: resolution?.width.floor().toString() ?? '-1',
              label: 'Width',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newWidth = int.tryParse(value);

                setState(() {
                  if (newWidth == null || newWidth == 0) {
                    resolution = null;
                    return;
                  }

                  if (newWidth! % 2 != 0) {
                    // Won't allow += for some reason
                    newWidth = newWidth! + 1;
                  }

                  resolution = Size(
                    newWidth!.toDouble(),
                    resolution?.height.toDouble() ?? 0,
                  );
                });
              },
            ),
          ),
          const Text('x'),
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: resolution?.height.floor().toString() ?? '-1',
              label: 'Height',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newHeight = int.tryParse(value);

                setState(() {
                  if (newHeight == null || newHeight == 0) {
                    resolution = null;
                    return;
                  }

                  resolution = Size(
                    resolution?.width.toDouble() ?? 0,
                    newHeight.toDouble(),
                  );
                });
              },
            ),
          ),
        ],
      ),
    ),
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          const Text('Quality:'),
          Expanded(
            child: Slider(
              value: quality?.toDouble() ?? -5.0,
              min: -5.0,
              max: 100.0,
              divisions: 104,
              label: '${quality ?? -1}',
              onChanged: (value) {
                setState(() {
                  if (value < 0) {
                    quality = null;
                  } else {
                    quality = value.floor();
                  }
                });
              },
            ),
          ),
        ],
      ),
    ),
    TextButton(
      onPressed: () => refresh(),
      child: const Text('Apply Quality Settings'),
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
                int newRotation = rotationTurns - 1;
                if (newRotation < 0) {
                  newRotation += 4;
                }
                rotationTurns = newRotation;
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
                int newRotation = rotationTurns + 1;
                if (newRotation >= 4) {
                  newRotation -= 4;
                }
                rotationTurns = newRotation;
              },
            ),
          ),
        ],
      ),
      //Camera Crosshair
      StatefulBuilder(
        builder: (context, setState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Divider(
                height: 10,
              ),
              Text("Crosshair Settings"),
              const SizedBox(height: 10),
              DialogToggleSwitch(
                  onToggle: (value) => setState(
                        () => _crosshairEnabled = value,
                      ),
                  initialValue: _crosshairEnabled,
                  label: "Enabled"),
              const SizedBox(height: 10),
              //Height, Width, Thickness
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: DialogTextInput(
                      allowEmptySubmission: true,
                      initialText: "$_crosshairWidth",
                      label: 'Width',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                      onSubmit: (value) {
                        int? newWidth = int.tryParse(value) ?? 0;
                        setState(() {
                          if (newWidth >= 0) {
                            _crosshairWidth = newWidth;
                            return;
                          }
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: DialogTextInput(
                      allowEmptySubmission: true,
                      initialText: "$_crosshairHeight",
                      label: 'Height',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                      onSubmit: (value) {
                        int? newHeight = int.tryParse(value) ?? 0;
                        setState(() {
                          if (newHeight >= 0) {
                            _crosshairHeight = newHeight;
                            return;
                          }
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: DialogTextInput(
                      allowEmptySubmission: true,
                      initialText: "$_crosshairThickness",
                      label: 'Thickness',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                      onSubmit: (value) {
                        int? newThickness = int.tryParse(value) ?? 0;
                        setState(() {
                          if (newThickness >= 0) {
                            _crosshairThickness = newThickness;
                            return;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),
              //Centered, X and Y POS
              DialogToggleSwitch(
                  onToggle: (value) => setState(
                        () => _crosshairCentered = value,
                      ),
                  initialValue: _crosshairCentered,
                  label: "Centered"),
              SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: DialogTextInput(
                      enabled: !_crosshairCentered,
                      allowEmptySubmission: true,
                      initialText: "$_crosshairX",
                      label: 'X Position',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                      onSubmit: (value) {
                        int? newX = int.tryParse(value) ?? 0;
                        setState(() {
                          if (newX >= 0) {
                            _crosshairX = newX;
                            return;
                          }
                        });
                      },
                    ),
                  ),
                  Flexible(
                    child: DialogTextInput(
                      enabled: !_crosshairCentered,
                      allowEmptySubmission: true,
                      initialText: "$_crosshairY",
                      label: 'Y Position',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                      onSubmit: (value) {
                        int? newY = int.tryParse(value) ?? 0;
                        setState(() {
                          if (newY >= 0) {
                            _crosshairY = newY;
                            return;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),

              DialogColorPicker(
                onColorPicked: (color) => setState(
                  () => setState(
                    () => _crosshairColor = color,
                  ),
                ),
                label: 'Crosshair Color',
                initialColor: _crosshairColor,
                defaultColor: Colors.red,
                rowSize: MainAxisSize.max,
              ),
            ],
          );
        },
      )
    ];
  }
        ),
      ],
    ),
  ];

  @override
  void softDispose({bool deleting = false}) {
    if (deleting) {
      controller?.dispose();
      ntConnection.ntConnected.removeListener(onNTConnected);
    }

    super.softDispose(deleting: deleting);
  }

  void onNTConnected() {
    if (ntConnection.ntConnected.value) {
      closeClient();
    } else {
      controller?.changeCycleState(StreamCycleState.idle);
    }
  }

  void closeClient() {
    controller?.dispose();
    controller = null;
  }
}

class CameraStreamWidget extends NTWidget {
  static const String widgetType = 'Camera Stream';

  const CameraStreamWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CameraStreamModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.streamsSubscription,
        model.ntConnection.ntConnected,
      ]),
      builder: (context, child) {
        List<Object?> rawStreams =
            tryCast(model.streamsSubscription.value) ?? [];

        List<String> streams = [];
        for (Object? stream in rawStreams) {
          if (stream == null ||
              stream is! String ||
              !stream.startsWith('mjpg:')) {
            continue;
          }

          streams.add(stream.substring('mjpg:'.length));
        }

        if (streams.isEmpty || !model.ntConnection.ntConnected.value) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (model.controller?.previousImage != null)
                Opacity(
                  opacity: 0.35,
                  child: Image.memory(
                    Uint8List.fromList(model.controller!.previousImage!),
                    fit: BoxFit.contain,
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomLoadingIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    (model.ntConnection.isNT4Connected)
                        ? 'Waiting for Camera Stream connection...'
                        : 'Waiting for Network Tables connection...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        }

        bool createNewWidget = model.controller == null;

        List<String> streamUrls = streams
            .map((stream) => model.getUrlWithParameters(stream))
            .toList();

        createNewWidget =
            createNewWidget ||
            !(model.controller?.streams.equals(streamUrls) ?? false);

        if (createNewWidget) {
          model.controller?.dispose();

          model.controller = MjpegController(
            streams: streamUrls,
            timeout: const Duration(milliseconds: 500),
          );
        }

        return IntrinsicWidth(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: model.controller!.framesPerSecond,
                    builder: (context, value, child) => Text('FPS: $value'),
                  ),
                  const Spacer(),
                  ValueListenableBuilder(
                    valueListenable: model.controller!.bandwidth,
                    builder: (context, value, child) =>
                        Text('Bandwidth: ${value.toStringAsFixed(2)} Mbps'),
                  ),
                ],
              ),
              Flexible(
                child: Stack(children: [
                  CustomPaint(
                      foregroundPainter: CrosshairPainter(
                          model._crosshairWidth,
                          model._crosshairHeight,
                          model._crosshairThickness,
                          model._crosshairX,
                          model._crosshairY,
                          model._crosshairEnabled,
                          model._crosshairColor,
                          model._crosshairCentered),
                      child: Mjpeg(
                        controller: model.controller!,
                        fit: BoxFit.contain,
                        expandToFit: true,
                        quarterTurns: model.rotationTurns,
                      ))
                ]),
              ),
              const Text(''),
            ],
          ),
        );
      },
    );
  }
}

class CrosshairPainter extends CustomPainter {
  final bool? enabled;
  final int? crosshairWidth;
  final int? crosshairHeight;
  final int? crosshairThickness;
  final int? crosshairY;
  final int? crosshairX;
  final Color? crosshairColor;
  final bool? centered;

  CrosshairPainter(
      this.crosshairWidth,
      this.crosshairHeight,
      this.crosshairThickness,
      this.crosshairX,
      this.crosshairY,
      this.enabled,
      this.crosshairColor,
      this.centered);

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled!) return;
    var widthModifier = size.width / 250;
    var heightModifier = size.height / 250;
    var maxWidth = size.width - (crosshairWidth! / 2 * widthModifier);
    var maxHeight = size.height - (crosshairHeight! / 2 * widthModifier);
    double x;
    double y;
    if (centered!) {
      x = (size.width / 2);
      y = (size.height / 2);
    } else {
      x = clampDouble(
          (crosshairX! + crosshairWidth! / 2) * widthModifier, 0, maxWidth);
      y = clampDouble(
          (crosshairY! + crosshairHeight! / 2) * widthModifier, 0, maxHeight);
    }

    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(x, y),
            width: crosshairWidth! * widthModifier,
            height: crosshairThickness! * heightModifier),
        Paint()..color = crosshairColor!);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(x, y),
            width: crosshairThickness! * heightModifier,
            height: crosshairHeight! * widthModifier),
        Paint()..color = crosshairColor!);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return enabled!;
  }
}
