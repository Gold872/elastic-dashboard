import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandModel extends NTWidgetModel {
  @override
  String type = CommandWidget.widgetType;

  NT4Topic? runningTopic;

  String get runningTopicName => '$topic/running';
  String get nameTopicName => '$topic/name';

  bool _showType = true;

  bool get showType => _showType;

  set showType(bool value) {
    _showType = value;
    refresh();
  }

  CommandModel({
    required super.topic,
    bool showType = true,
    super.dataType,
    super.period,
  })  : _showType = showType,
        super();

  CommandModel.fromJson({required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _showType = tryCast(jsonData['show_type']) ?? _showType;
  }

  @override
  void resetSubscription() {
    runningTopic = null;

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'show_type': _showType,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogToggleSwitch(
        label: 'Show Command Type',
        initialValue: _showType,
        onToggle: (value) {
          showType = value;
        },
      ),
    ];
  }

  @override
  List<Object> getCurrentData() {
    bool running =
        ntConnection.getLastAnnouncedValue(runningTopicName)?.tryCast<bool>() ??
            false;
    String name =
        ntConnection.getLastAnnouncedValue(nameTopicName)?.tryCast<String>() ??
            'Unknown';

    return [running, name];
  }
}

class CommandWidget extends NTWidget {
  static const String widgetType = 'Command';

  const CommandWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CommandModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        bool running = ntConnection
                .getLastAnnouncedValue(model.runningTopicName)
                ?.tryCast<bool>() ??
            false;
        String name = ntConnection
                .getLastAnnouncedValue(model.nameTopicName)
                ?.tryCast<String>() ??
            'Unknown';

        String buttonText =
            model.topic.substring(model.topic.lastIndexOf('/') + 1);

        ThemeData theme = Theme.of(context);

        return Column(
          children: [
            Visibility(
              visible: model.showType,
              child: Text('Type: $name',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTapUp: (_) {
                bool publishTopic = model.runningTopic == null;

                model.runningTopic =
                    ntConnection.getTopicFromName(model.runningTopicName);

                if (model.runningTopic == null) {
                  return;
                }

                if (publishTopic) {
                  ntConnection.nt4Client.publishTopic(model.runningTopic!);
                }

                ntConnection.updateDataFromTopic(model.runningTopic!, !running);
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
