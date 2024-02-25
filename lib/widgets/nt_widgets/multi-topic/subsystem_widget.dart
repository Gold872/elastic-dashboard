import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SubsystemModel extends NTWidgetModel {
  @override
  String type = SubsystemWidget.widgetType;

  String get defaultCommandTopic => '$topic/.default';
  String get currentCommandTopic => '$topic/.command';

  SubsystemModel({required super.topic, super.dataType, super.period})
      : super();

  SubsystemModel.fromJson({required super.jsonData}) : super.fromJson();

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
}

class SubsystemWidget extends NTWidget {
  static const String widgetType = 'Subsystem';

  const SubsystemWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    SubsystemModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        String defaultCommand = tryCast(ntConnection
                .getLastAnnouncedValue(model.defaultCommandTopic)) ??
            'none';
        String currentCommand = tryCast(ntConnection
                .getLastAnnouncedValue(model.currentCommandTopic)) ??
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
