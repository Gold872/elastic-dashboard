import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SubsystemWidget extends NTWidget {
  static const String widgetType = 'Subsystem';
  @override
  String type = widgetType;

  late String _defaultCommandTopic;
  late String _currentCommandTopic;

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

    _defaultCommandTopic = '$topic/.default';
    _currentCommandTopic = '$topic/.command';
  }

  @override
  void resetSubscription() {
    _defaultCommandTopic = '$topic/.default';
    _currentCommandTopic = '$topic/.command';

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    String defaultCommand =
        tryCast(ntConnection.getLastAnnouncedValue(_defaultCommandTopic)) ??
            'none';
    String currentCommand =
        tryCast(ntConnection.getLastAnnouncedValue(_currentCommandTopic)) ??
            'none';

    return [defaultCommand, currentCommand];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        String defaultCommand =
            tryCast(ntConnection.getLastAnnouncedValue(_defaultCommandTopic)) ??
                'none';
        String currentCommand =
            tryCast(ntConnection.getLastAnnouncedValue(_currentCommandTopic)) ??
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
