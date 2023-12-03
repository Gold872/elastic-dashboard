import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CommandWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Command';

  NT4Topic? runningTopic;

  late String runningTopicName;
  late String nameTopicName;

  CommandWidget({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  CommandWidget.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

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
    bool running = nt4Connection
            .getLastAnnouncedValue(runningTopicName)
            ?.tryCast<bool>() ??
        false;
    String name =
        nt4Connection.getLastAnnouncedValue(nameTopicName)?.tryCast<String>() ??
            'Unknown';

    return [running, name];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        bool running = nt4Connection
                .getLastAnnouncedValue(runningTopicName)
                ?.tryCast<bool>() ??
            false;
        String name = nt4Connection
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

                runningTopic = nt4Connection.getTopicFromName(runningTopicName);

                if (runningTopic == null) {
                  return;
                }

                if (publishTopic) {
                  nt4Connection.nt4Client.publishTopic(runningTopic!);
                }

                nt4Connection.updateDataFromTopic(runningTopic!, !running);
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
