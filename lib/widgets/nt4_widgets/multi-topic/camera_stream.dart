import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
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

  Object? rawStreams;
  Mjpeg? streamWidget;
  MemoryImage? lastDisplayedImage;

  late NT4Subscription streamsSubscription;
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
    streamsSubscription = nt4Connection.subscribe(streamsTopic, super.period);

    httpClient = Client();
    clientOpen = true;
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    closeClient();

    nt4Connection.unSubscribe(streamsSubscription);

    streamsTopic = '$topic/streams';
    streamsSubscription = nt4Connection.subscribe(streamsTopic, super.period);
  }

  @override
  void dispose() {
    Future(() async {
      await streamWidget?.cancelSubscription();

      httpClient.close();
      clientOpen = false;

      lastDisplayedImage?.evict();
      streamWidget?.previousImage?.evict();
    });

    super.dispose();
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    nt4Connection.unSubscribe(streamsSubscription);
  }

  void closeClient() {
    lastDisplayedImage?.evict();
    lastDisplayedImage = streamWidget?.previousImage;
    streamWidget = null;
    httpClient.close();
    clientOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: streamsSubscription.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(streamsTopic),
      builder: (context, snapshot) {
        if (!nt4Connection.isNT4Connected && clientOpen) {
          closeClient();
        }
        Object? value = snapshot.data;

        bool createNewWidget = streamWidget == null ||
            rawStreams != value ||
            (!clientOpen && nt4Connection.isNT4Connected);

        rawStreams = value;

        List<Object?> rawStreamsList =
            rawStreams?.tryCast<List<Object?>>() ?? [];

        List<String> streams = [];
        for (Object? stream in rawStreamsList) {
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

          String stream = (streams.length > 1) ? streams[1] : streams[0];

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
