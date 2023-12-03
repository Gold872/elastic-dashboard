import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

class CameraStreamWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Camera Stream';

  late String streamsTopic;

  Mjpeg? streamWidget;
  MemoryImage? lastDisplayedImage;

  late Client httpClient;
  bool clientOpen = false;

  CameraStreamWidget(
      {super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  CameraStreamWidget.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    streamsTopic = '$topic/streams';

    httpClient = Client();
    clientOpen = true;
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    closeClient();

    streamsTopic = '$topic/streams';
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
        tryCast(nt4Connection.getLastAnnouncedValue(streamsTopic)) ?? [];
    List<String> streams = rawStreams.whereType<String>().toList();

    return [
      ...streams,
      clientOpen,
      nt4Connection.isNT4Connected,
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        if (!nt4Connection.isNT4Connected && clientOpen) {
          closeClient();
        }

        bool createNewWidget = streamWidget == null ||
            (!clientOpen && nt4Connection.isNT4Connected);

        List<Object?> rawStreams =
            tryCast(nt4Connection.getLastAnnouncedValue(streamsTopic)) ?? [];

        List<String> streams = [];
        for (Object? stream in rawStreams) {
          if (stream == null || stream is! String) {
            continue;
          }

          streams.add(stream.substring(5));
        }

        if (streams.isEmpty || !nt4Connection.isNT4Connected) {
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
                  Text((nt4Connection.isNT4Connected)
                      ? 'Waiting for Camera Stream connection...'
                      : 'Waiting for Network Tables Connection...'),
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
