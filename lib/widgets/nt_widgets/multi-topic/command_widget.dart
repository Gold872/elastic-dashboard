import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandWidget extends NTWidget {
  static const String widgetType = 'Command';
  @override
  String type = widgetType;

  NT4Topic? _runningTopic;

  late String _runningTopicName;
  late String _nameTopicName;

  bool _showType = true;

  CommandWidget({
    super.key,
    required super.topic,
    bool showType = true,
    super.dataType,
    super.period,
  })  : _showType = showType,
        super();

  CommandWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _showType = tryCast(jsonData['show_type']) ?? _showType;
  }

  @override
  void init() {
    super.init();

    _runningTopicName = '$topic/running';
    _nameTopicName = '$topic/.name';
  }

  @override
  void resetSubscription() {
    _runningTopicName = '$topic/running';
    _nameTopicName = '$topic/.name';

    _runningTopic = null;

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
          _showType = value;
          refresh();
        },
      ),
    ];
  }

  @override
  List<Object> getCurrentData() {
    bool running = ntConnection
            .getLastAnnouncedValue(_runningTopicName)
            ?.tryCast<bool>() ??
        false;
    String name =
        ntConnection.getLastAnnouncedValue(_nameTopicName)?.tryCast<String>() ??
            'Unknown';

    return [running, name];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        bool running = ntConnection
                .getLastAnnouncedValue(_runningTopicName)
                ?.tryCast<bool>() ??
            false;
        String name = ntConnection
                .getLastAnnouncedValue(_nameTopicName)
                ?.tryCast<String>() ??
            'Unknown';

        String buttonText = topic.substring(topic.lastIndexOf('/') + 1);

        ThemeData theme = Theme.of(context);

        return Column(
          children: [
            Visibility(
              visible: _showType,
              child: Text('Type: $name',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTapUp: (_) {
                bool publishTopic = _runningTopic == null;

                _runningTopic =
                    ntConnection.getTopicFromName(_runningTopicName);

                if (_runningTopic == null) {
                  return;
                }

                if (publishTopic) {
                  ntConnection.nt4Client.publishTopic(_runningTopic!);
                }

                ntConnection.updateDataFromTopic(_runningTopic!, !running);
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
