import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ToggleSwitch extends NTWidget {
  static const String widgetType = 'Toggle Switch';
  @override
  String type = widgetType;

  ToggleSwitch({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ToggleSwitch.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        bool value = tryCast(snapshot.data) ?? false;

        return Switch(
          value: value,
          onChanged: (bool value) {
            bool publishTopic =
                ntTopic == null || !ntConnection.isTopicPublished(ntTopic);

            createTopicIfNull();

            if (ntTopic == null) {
              return;
            }

            if (publishTopic) {
              ntConnection.nt4Client.publishTopic(ntTopic!);
            }

            ntConnection.updateDataFromTopic(ntTopic!, value);
          },
        );
      },
    );
  }
}
