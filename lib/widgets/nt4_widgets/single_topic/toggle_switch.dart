import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ToggleSwitch extends StatelessWidget with NT4Widget {
  @override
  String type = 'Toggle Switch';

  ToggleSwitch({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  ToggleSwitch.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    topic = jsonData['topic'] ?? '';
    period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        Object data = snapshot.data ?? false;

        bool value = (data is bool) ? data : false;

        return Switch(
          value: value,
          onChanged: (bool value) {
            bool publishTopic = nt4Topic == null;

            createTopicIfNull();

            if (nt4Topic == null) {
              return;
            }

            if (publishTopic) {
              nt4Connection.nt4Client.publishTopic(nt4Topic!);
            }

            nt4Connection.updateDataFromTopic(nt4Topic!, value);
          },
        );
      },
    );
  }
}
