import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CameraStreamModel extends NTWidgetModel {
  @override
  String type = CameraStreamWidget.widgetType;

  String get streamsTopic => '$topic/streams';

  Mjpeg? _streamWidget;
  MemoryImage? _lastDisplayedImage;

  get streamWidget => _streamWidget;

  set streamWidget(value) => _streamWidget = value;

  get lastDisplayedImage => _lastDisplayedImage;

  set lastDisplayedImage(value) => _lastDisplayedImage = value;

  bool _clientOpen = false;

  get clientOpen => _clientOpen;

  set clientOpen(value) => _clientOpen = value;

  CameraStreamModel({required super.topic, super.dataType, super.period})
      : super();

  CameraStreamModel.fromJson({required super.jsonData}) : super.fromJson();

  @override
  void init() {
    super.init();

    _clientOpen = true;
  }

  @override
  void resetSubscription() {
    closeClient();

    super.resetSubscription();
  }

  @override
  void disposeWidget({bool deleting = false}) {
    Future(() async {
      if (deleting) {
        await _streamWidget?.dispose();
      }
      _clientOpen = false;

      if (deleting) {
        _lastDisplayedImage?.evict();
        _streamWidget?.previousImage?.evict();
      }
    });

    super.disposeWidget(deleting: deleting);
  }

  void closeClient() {
    _lastDisplayedImage?.evict();
    _lastDisplayedImage = _streamWidget?.previousImage;
    _streamWidget?.dispose();
    _streamWidget = null;
    _clientOpen = false;
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawStreams =
        tryCast(ntConnection.getLastAnnouncedValue(streamsTopic)) ?? [];
    List<String> streams = rawStreams.whereType<String>().toList();

    return [
      ...streams,
      _clientOpen,
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
        if (!ntConnection.isNT4Connected && model._clientOpen) {
          model.closeClient();
        }

        bool createNewWidget = model._streamWidget == null ||
            (!model.clientOpen && ntConnection.isNT4Connected);

        List<Object?> rawStreams =
            tryCast(ntConnection.getLastAnnouncedValue(model.streamsTopic)) ??
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

        if (streams.isEmpty || !ntConnection.isNT4Connected) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (model.lastDisplayedImage != null)
                Opacity(
                  opacity: 0.35,
                  child: Image(
                    image: model.lastDisplayedImage!,
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
                    (ntConnection.isNT4Connected)
                        ? 'Waiting for Camera Stream connection...'
                        : 'Waiting for Network Tables Connection...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        }

        if (createNewWidget) {
          model.clientOpen = true;
          model.lastDisplayedImage?.evict();

          String stream = streams.last;

          model.streamWidget = Mjpeg(
            fit: BoxFit.contain,
            isLive: true,
            stream: stream,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            model.streamWidget!,
          ],
        );
      },
    );
  }
}
