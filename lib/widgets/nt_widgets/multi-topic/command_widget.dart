import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandModel extends MultiTopicNTWidgetModel {
  @override
  String type = CommandWidget.widgetType;

  String get runningTopicName => '$topic/running';
  String get nameTopicName => '$topic/name';

  late NT4Subscription runningSubscription;
  late NT4Subscription nameSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        runningSubscription,
        nameSubscription,
      ];

  NT4Topic? runningTopic;

  bool _showType = true;

  bool get showType => _showType;

  set showType(bool value) {
    _showType = value;
    refresh();
  }

  CommandModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showType = true,
    super.dataType,
    super.period,
  })  : _showType = showType,
        super();

  CommandModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showType = tryCast(jsonData['show_type']) ?? _showType;
  }

  @override
  void initializeSubscriptions() {
    runningSubscription =
        ntConnection.subscribe(runningTopicName, super.period);
    nameSubscription = ntConnection.subscribe(nameTopicName, super.period);
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
}

class CommandWidget extends NTWidget {
  static const String widgetType = 'Command';

  const CommandWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CommandModel model = cast(context.watch<NTWidgetModel>());

    String buttonText = model.topic.substring(model.topic.lastIndexOf('/') + 1);

    ThemeData theme = Theme.of(context);

    return Column(
      children: [
        Visibility(
          visible: model.showType,
          child: ValueListenableBuilder(
              valueListenable: model.nameSubscription,
              builder: (context, data, child) {
                String name = tryCast(data) ?? 'Unknown';

                return Text('Type: $name',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis);
              }),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTapUp: (_) {
            bool publishTopic = model.runningTopic == null;

            model.runningTopic ??=
                model.ntConnection.getTopicFromName(model.runningTopicName);

            if (model.runningTopic == null) {
              return;
            }

            if (publishTopic) {
              model.ntConnection.publishTopic(model.runningTopic!);
            }

            // Prevents widget from locking up if double pressed fast enough
            bool running =
                model.runningSubscription.value?.tryCast<bool>() ?? false;

            model.ntConnection
                .updateDataFromTopic(model.runningTopic!, !running);
          },
          child: ValueListenableBuilder(
              valueListenable: model.runningSubscription,
              builder: (context, data, child) {
                bool running = tryCast(data) ?? false;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
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
                );
              }),
        ),
      ],
    );
  }
}
