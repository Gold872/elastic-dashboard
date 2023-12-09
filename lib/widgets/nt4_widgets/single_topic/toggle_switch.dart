import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class ToggleSwitch extends NT4Widget {
  static const String widgetType = 'Toggle Switch';
  @override
  String type = widgetType;

  ToggleSwitch({super.key, required super.topic, super.period}) : super();

  ToggleSwitch.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        bool value = tryCast(snapshot.data) ?? false;

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
