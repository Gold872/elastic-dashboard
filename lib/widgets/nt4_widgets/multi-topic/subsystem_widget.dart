import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SubsystemWidget extends NT4Widget {
  @override
  String type = 'Subsystem';

  late String defaultCommandTopic;
  late String currentCommandTopic;

  SubsystemWidget({super.key, required super.topic, super.period}) : super();

  SubsystemWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    defaultCommandTopic = '$topic/.default';
    currentCommandTopic = '$topic/.command';
  }

  @override
  void resetSubscription() {
    defaultCommandTopic = '$topic/.default';
    currentCommandTopic = '$topic/.command';

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    String defaultCommand =
        tryCast(nt4Connection.getLastAnnouncedValue(defaultCommandTopic)) ??
            'none';
    String currentCommand =
        tryCast(nt4Connection.getLastAnnouncedValue(currentCommandTopic)) ??
            'none';

    return [defaultCommand, currentCommand];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        String defaultCommand =
            tryCast(nt4Connection.getLastAnnouncedValue(defaultCommandTopic)) ??
                'none';
        String currentCommand =
            tryCast(nt4Connection.getLastAnnouncedValue(currentCommandTopic)) ??
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
