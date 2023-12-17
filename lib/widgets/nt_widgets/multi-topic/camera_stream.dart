import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CameraStreamWidget extends NTWidget {
  static const String widgetType = 'Camera Stream';
  @override
  String type = widgetType;

  late String streamsTopic;

  Mjpeg? streamWidget;
  MemoryImage? lastDisplayedImage;

  late Client httpClient;
  bool clientOpen = false;

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

    streamsTopic = '$topic/streams';

    httpClient = Client();
    clientOpen = true;
  }

  @override
  void resetSubscription() {
    closeClient();

    streamsTopic = '$topic/streams';

    super.resetSubscription();
  }

  @override
  void dispose({bool deleting = false}) {
    Future(() async {
      await streamWidget?.cancelSubscription();

      httpClient.close();
      clientOpen = false;

      if (deleting) {
        lastDisplayedImage?.evict();
        streamWidget?.previousImage?.evict();
      }
    });

    super.dispose(deleting: deleting);
  }

  void closeClient() {
    lastDisplayedImage?.evict();
    lastDisplayedImage = streamWidget?.previousImage;
    streamWidget = null;
    httpClient.close();
    clientOpen = false;
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawStreams =
        tryCast(ntConnection.getLastAnnouncedValue(streamsTopic)) ?? [];
    List<String> streams = rawStreams.whereType<String>().toList();

    return [
      ...streams,
      clientOpen,
      ntConnection.isNT4Connected,
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        if (!ntConnection.isNT4Connected && clientOpen) {
          closeClient();
        }

        bool createNewWidget = streamWidget == null ||
            (!clientOpen && ntConnection.isNT4Connected);

        List<Object?> rawStreams =
            tryCast(ntConnection.getLastAnnouncedValue(streamsTopic)) ?? [];

        List<String> streams = [];
        for (Object? stream in rawStreams) {
          if (stream == null || stream is! String) {
            continue;
          }

          streams.add(stream.substring(5));
        }

        if (streams.isEmpty || !ntConnection.isNT4Connected) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (lastDisplayedImage != null)
                Opacity(
                  opacity: 0.35,
                  child: Image(
                    image: lastDisplayedImage!,
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
          if (!clientOpen) {
            httpClient = Client();
            clientOpen = true;
          }
          lastDisplayedImage?.evict();

          String stream = streams.last;

          streamWidget = Mjpeg(
            fit: BoxFit.contain,
            httpClient: httpClient,
            isLive: true,
            stream: stream,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            streamWidget!,
          ],
        );
      },
    );
  }
}
