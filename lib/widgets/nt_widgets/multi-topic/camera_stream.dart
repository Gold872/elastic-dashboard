import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CameraStreamModel extends NTWidgetModel {
  @override
  String type = CameraStreamWidget.widgetType;

  String get streamsTopic => '$topic/streams';

  MemoryImage? _lastDisplayedImage;

  MjpegStreamState? mjpegStream;

  get lastDisplayedImage => _lastDisplayedImage;

  set lastDisplayedImage(value) => _lastDisplayedImage = value;

  CameraStreamModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  CameraStreamModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void resetSubscription() {
    closeClient();

    super.resetSubscription();
  }

  @override
  void disposeWidget({bool deleting = false}) {
    if (deleting) {
      _lastDisplayedImage?.evict();
      mjpegStream?.previousImage?.evict();
      mjpegStream?.dispose();
    }

    super.disposeWidget(deleting: deleting);
  }

  void closeClient() {
    _lastDisplayedImage?.evict();
    _lastDisplayedImage = mjpegStream?.previousImage;
    mjpegStream?.dispose();
    mjpegStream = null;
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawStreams =
        tryCast(ntConnection.getLastAnnouncedValue(streamsTopic)) ?? [];
    List<String> streams = rawStreams.whereType<String>().toList();

    return [
      ...streams,
      ntConnection.isNT4Connected,
    ];
  }
}

class CameraStreamWidget extends NTWidget {
  static const String widgetType = 'Camera Stream';

  const CameraStreamWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CameraStreamModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        List<Object?> rawStreams = tryCast(
                model.ntConnection.getLastAnnouncedValue(model.streamsTopic)) ??
            [];

        List<String> streams = [];
        for (Object? stream in rawStreams) {
          if (stream == null ||
              stream is! String ||
              !stream.startsWith('mjpg:')) {
            continue;
          }

          streams.add(stream.substring('mjpg:'.length));
        }

        if (streams.isEmpty || !model.ntConnection.isNT4Connected) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (model.mjpegStream != null || model.lastDisplayedImage != null)
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
                        : 'Waiting for Network Tables Connection...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        }

        bool createNewWidget = model.mjpegStream == null;

        createNewWidget =
            createNewWidget || (model.mjpegStream?.stream != streams.last);

        if (createNewWidget) {
          model.lastDisplayedImage?.evict();
          model.mjpegStream?.dispose();

          String stream = streams.last;
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
