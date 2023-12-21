import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandWidget extends NTWidget {
  static const String widgetType = 'Command';
  @override
  String type = widgetType;

  NT4Topic? runningTopic;

  late String runningTopicName;
  late String nameTopicName;

  CommandWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  CommandWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    runningTopicName = '$topic/running';
    nameTopicName = '$topic/.name';
  }

  @override
  void resetSubscription() {
    runningTopicName = '$topic/running';
    nameTopicName = '$topic/.name';

    runningTopic = null;

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    bool running =
        ntConnection.getLastAnnouncedValue(runningTopicName)?.tryCast<bool>() ??
            false;
    String name =
        ntConnection.getLastAnnouncedValue(nameTopicName)?.tryCast<String>() ??
            'Unknown';

    return [running, name];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        bool running = ntConnection
                .getLastAnnouncedValue(runningTopicName)
                ?.tryCast<bool>() ??
            false;
        String name = ntConnection
                .getLastAnnouncedValue(nameTopicName)
                ?.tryCast<String>() ??
            'Unknown';

        String buttonText = topic.substring(topic.lastIndexOf('/') + 1);

        ThemeData theme = Theme.of(context);

        return Column(
          children: [
            Text('Type: $name',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            GestureDetector(
              onTapUp: (_) {
                bool publishTopic = runningTopic == null;

                runningTopic = ntConnection.getTopicFromName(runningTopicName);

                if (runningTopic == null) {
                  return;
                }

                if (publishTopic) {
                  ntConnection.nt4Client.publishTopic(runningTopic!);
                }

                ntConnection.updateDataFromTopic(runningTopic!, !running);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: const [
                    BoxShadow(
                      offset: Offset(2, 2),
                      blurRadius: 10.0,
                      spreadRadius: -5,
                      color: Colors.black,
                    ),
                  ],
                  color: (running)
                      ? theme.colorScheme.primaryContainer
                      : const Color.fromARGB(255, 50, 50, 50),
                ),
                child: Text(buttonText,
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        );
      },
    );
  }
}
