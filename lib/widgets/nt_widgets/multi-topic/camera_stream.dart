import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CameraStreamWidget extends NTWidget {
  static const String widgetType = 'Camera Stream';
  @override
  String type = widgetType;

  late String _streamsTopic;

  Mjpeg? _streamWidget;
  MemoryImage? _lastDisplayedImage;

  bool _clientOpen = false;

  CameraStreamWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  CameraStreamWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    _streamsTopic = '$topic/streams';

    _clientOpen = true;
  }

  @override
  void resetSubscription() {
    _closeClient();

    _streamsTopic = '$topic/streams';

    super.resetSubscription();
  }

  @override
  void dispose({bool deleting = false}) {
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

    super.dispose(deleting: deleting);
  }

  void _closeClient() {
    _lastDisplayedImage?.evict();
    _lastDisplayedImage = _streamWidget?.previousImage;
    _streamWidget?.dispose();
    _streamWidget = null;
    _clientOpen = false;
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawStreams =
        tryCast(ntConnection.getLastAnnouncedValue(_streamsTopic)) ?? [];
    List<String> streams = rawStreams.whereType<String>().toList();

    return [
      ...streams,
      _clientOpen,
      ntConnection.isNT4Connected,
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        if (!ntConnection.isNT4Connected && _clientOpen) {
          _closeClient();
        }

        bool createNewWidget = _streamWidget == null ||
            (!_clientOpen && ntConnection.isNT4Connected);

        List<Object?> rawStreams =
            tryCast(ntConnection.getLastAnnouncedValue(_streamsTopic)) ?? [];

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
              if (_lastDisplayedImage != null)
                Opacity(
                  opacity: 0.35,
                  child: Image(
                    image: _lastDisplayedImage!,
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
          _clientOpen = true;
          _lastDisplayedImage?.evict();

          String stream = streams.last;

          _streamWidget = Mjpeg(
            fit: BoxFit.contain,
            isLive: true,
            stream: stream,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            _streamWidget!,
          ],
        );
      },
    );
  }
}
