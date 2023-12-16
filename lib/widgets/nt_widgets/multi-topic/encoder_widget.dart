import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class EncoderWidget extends NTWidget {
  static const String widgetType = 'Encoder';
  @override
  String type = widgetType;

  late String distanceTopic;
  late String speedTopic;

  EncoderWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  EncoderWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    distanceTopic = '$topic/Distance';
    speedTopic = '$topic/Speed';
  }

  @override
  void resetSubscription() {
    distanceTopic = '$topic/Distance';
    speedTopic = '$topic/Speed';

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    double distance =
        tryCast(ntConnection.getLastAnnouncedValue(distanceTopic)) ?? 0.0;
    double speed =
        tryCast(ntConnection.getLastAnnouncedValue(speedTopic)) ?? 0.0;

    return [distance, speed];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        double distance =
            tryCast(ntConnection.getLastAnnouncedValue(distanceTopic)) ?? 0.0;
        double speed =
            tryCast(ntConnection.getLastAnnouncedValue(speedTopic)) ?? 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                const Text('Distance'),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade700,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: SelectableText(
                      distance.toStringAsPrecision(10),
                      maxLines: 1,
                      showCursor: true,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Speed'),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade700,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: SelectableText(
                      speed.toStringAsPrecision(10),
                      maxLines: 1,
                      showCursor: true,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
