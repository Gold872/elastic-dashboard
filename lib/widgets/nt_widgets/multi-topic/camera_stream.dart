import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CameraStreamModel extends MultiTopicNTWidgetModel {
  @override
  String type = CameraStreamWidget.widgetType;

  String get streamsTopic => '$topic/streams';

  late NT4Subscription streamsSubscription;

  @override
  List<NT4Subscription> get subscriptions => [streamsSubscription];

  int? _quality;
  int? _fps;
  Size? _resolution;

  MemoryImage? _lastDisplayedImage;

  MjpegStreamState? mjpegStream;

  MemoryImage? get lastDisplayedImage => _lastDisplayedImage;

  set lastDisplayedImage(value) => _lastDisplayedImage = value;

  int? get quality => _quality;

  set quality(value) => _quality = value;

  int? get fps => _fps;

  set fps(value) => _fps = value;

  Size? get resolution => _resolution;

  set resolution(value) => _resolution = value;

  String getUrlWithParameters(String urlString) {
    Uri url = Uri.parse(urlString);

    Map<String, String> parameters =
        Map<String, String>.from(url.queryParameters);

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
    int? fps,
    Size? resolution,
    super.dataType,
    super.period,
  })  : _quality = compression,
        _fps = fps,
        _resolution = resolution,
        super();

  CameraStreamModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _quality = tryCast(jsonData['compression']);
    _fps = tryCast(jsonData['fps']);

    List<num>? resolution = tryCast<List<Object?>>(jsonData['resolution'])
        ?.whereType<num>()
        .toList();

    if (resolution != null && resolution.length > 1) {
      _resolution = Size(resolution[0].toDouble(), resolution[1].toDouble());
    }
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
  List<Widget> getEditProperties(BuildContext context) {
    return [
      StatefulBuilder(builder: (context, setState) {
        return Row(
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

                    resolution = Size(newWidth.toDouble(),
                        resolution?.height.toDouble() ?? 0);
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

                    resolution = Size(resolution?.width.toDouble() ?? 0,
                        newHeight.toDouble());
                  });
                },
              ),
            ),
          ],
        );
      }),
      StatefulBuilder(
        builder: (context, setState) {
          return Row(
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
          );
        },
      ),
      TextButton(
        onPressed: () => refresh(),
        child: const Text('Apply Quality Settings'),
      ),
    ];
  }

  @override
  void disposeWidget({bool deleting = false}) {
    if (deleting) {
      _lastDisplayedImage?.evict();
      mjpegStream?.previousImage?.evict();
      mjpegStream?.dispose(deleting: deleting);
    }

    super.disposeWidget(deleting: deleting);
  }

  void closeClient() {
    _lastDisplayedImage?.evict();
    _lastDisplayedImage = mjpegStream?.previousImage;
    mjpegStream?.dispose();
    mjpegStream = null;
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
              if (model.mjpegStream?.previousImage != null ||
                  model.lastDisplayedImage != null)
                Opacity(
                  opacity: 0.35,
                  child: Image(
                    image: model.mjpegStream?.previousImage ??
                        model.lastDisplayedImage!,
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

        bool createNewWidget = model.mjpegStream == null;

        String stream = model.getUrlWithParameters(streams.last);

        createNewWidget =
            createNewWidget || (model.mjpegStream?.stream != stream);

        if (createNewWidget) {
          model.lastDisplayedImage?.evict();
          model.mjpegStream?.dispose(deleting: true);

          model.mjpegStream = MjpegStreamState(stream: stream);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Mjpeg(
              mjpegStream: model.mjpegStream!,
              fit: BoxFit.contain,
            ),
          ],
        );
      },
    );
  }
}
