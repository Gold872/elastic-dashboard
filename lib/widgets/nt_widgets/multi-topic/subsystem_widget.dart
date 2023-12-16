import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SubsystemWidget extends NTWidget {
  static const String widgetType = 'Subsystem';
  @override
  String type = widgetType;

  late String defaultCommandTopic;
  late String currentCommandTopic;

  SubsystemWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

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
        tryCast(ntConnection.getLastAnnouncedValue(defaultCommandTopic)) ??
            'none';
    String currentCommand =
        tryCast(ntConnection.getLastAnnouncedValue(currentCommandTopic)) ??
            'none';

    return [defaultCommand, currentCommand];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        String defaultCommand =
            tryCast(ntConnection.getLastAnnouncedValue(defaultCommandTopic)) ??
                'none';
        String currentCommand =
            tryCast(ntConnection.getLastAnnouncedValue(currentCommandTopic)) ??
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
