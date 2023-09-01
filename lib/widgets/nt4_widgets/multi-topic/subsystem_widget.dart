import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SubsystemWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Subsystem';

  late String defaultCommandTopic;
  late String currentCommandTopic;

  SubsystemWidget({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  SubsystemWidget.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    defaultCommandTopic = '$topic/.default';
    currentCommandTopic = '$topic/.command';
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    defaultCommandTopic = '$topic/.default';
    currentCommandTopic = '$topic/.command';
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        String defaultCommand = nt4Connection
                .getLastAnnouncedValue(defaultCommandTopic) as String? ??
            'none';
        String currentCommand = nt4Connection
                .getLastAnnouncedValue(currentCommandTopic) as String? ??
            'none';

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('Default Command: $defaultCommand',
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Text('Current Command: $currentCommand',
                overflow: TextOverflow.ellipsis),
          ],
        );
      },
    );
  }
}
