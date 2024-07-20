import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ToggleSwitch extends NTWidget {
  static const String widgetType = 'Toggle Switch';

  const ToggleSwitch({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    NTWidgetModel model = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: model.subscription?.periodicStream(yieldAll: false),
      initialData: model.ntConnection.getLastAnnouncedValue(model.topic),
      builder: (context, snapshot) {
        bool value = tryCast(snapshot.data) ?? false;

        return Switch(
          value: value,
          onChanged: (bool value) {
            bool publishTopic = model.ntTopic == null ||
                !model.ntConnection.isTopicPublished(model.ntTopic);

            model.createTopicIfNull();

            if (model.ntTopic == null) {
              return;
            }

            if (publishTopic) {
              model.ntConnection.publishTopic(model.ntTopic!);
            }

            model.ntConnection.updateDataFromTopic(model.ntTopic!, value);
          },
        );
      },
    );
  }
}
