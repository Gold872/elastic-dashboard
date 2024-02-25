import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class EncoderModel extends NTWidgetModel {
  @override
  String type = EncoderWidget.widgetType;

  String get distanceTopic => '$topic/Distance';
  String get speedTopic => '$topic/Speed';

  EncoderModel({required super.topic, super.dataType, super.period}) : super();

  EncoderModel.fromJson({required super.jsonData}) : super.fromJson();

  @override
  List<Object> getCurrentData() {
    double distance =
        tryCast(ntConnection.getLastAnnouncedValue(distanceTopic)) ?? 0.0;
    double speed =
        tryCast(ntConnection.getLastAnnouncedValue(speedTopic)) ?? 0.0;

    return [distance, speed];
  }
}

class EncoderWidget extends NTWidget {
  static const String widgetType = 'Encoder';

  const EncoderWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    EncoderModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        double distance =
            tryCast(ntConnection.getLastAnnouncedValue(model.distanceTopic)) ??
                0.0;
        double speed =
            tryCast(ntConnection.getLastAnnouncedValue(model.speedTopic)) ??
                0.0;

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
