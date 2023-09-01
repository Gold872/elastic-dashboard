import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
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
    topic = jsonData['topic'] ?? '';
    period = jsonData['period'] ?? Globals.defaultPeriod;

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

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: streamsSubscription.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(streamsTopic),
      builder: (context, snapshot) {
        if (!nt4Connection.isNT4Connected && clientOpen) {
          lastDisplayedImage = streamWidget?.previousImage;
          streamWidget = null;
          httpClient.close();
          clientOpen = false;
        }
        Object? value = snapshot.data;

        bool createNewWidget = streamWidget == null ||
            rawStreams != value ||
            (!clientOpen && nt4Connection.isNT4Connected);

        rawStreams = value;

        List<Object?> rawStreamsList = rawStreams as List<Object?>? ?? [];

        List<String> streams = [];
        for (Object? stream in rawStreamsList) {
          if (stream == null || stream is! String) {
            continue;
          }

          streams.add(stream.substring(5));
        }

        if (streams.isEmpty) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (lastDisplayedImage != null)
                Opacity(
                  opacity: 0.50,
                  child: Image(
                    image: lastDisplayedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
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
          streamWidget = Mjpeg(
            fit: BoxFit.contain,
            httpClient: httpClient,
            isLive: true,
            stream: streams[0],
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
