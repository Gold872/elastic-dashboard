import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SplitButtonChooserModel extends MultiTopicNTWidgetModel {
  @override
  String type = SplitButtonChooser.widgetType;

  String get optionsTopicName => '$topic/options';
  String get selectedTopicName => '$topic/selected';
  String get activeTopicName => '$topic/active';
  String get defaultTopicName => '$topic/default';

  late NT4Subscription optionsSubscription;
  late NT4Subscription selectedSubscription;
  late NT4Subscription activeSubscription;
  late NT4Subscription defaultSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        optionsSubscription,
        selectedSubscription,
        activeSubscription,
        defaultSubscription,
      ];

  String? selectedChoice;

  StringChooserData? previousData;

  NT4Topic? _selectedTopic;
  NT4Topic? _activeTopic;

  SplitButtonChooserModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  SplitButtonChooserModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    optionsSubscription =
        ntConnection.subscribe(optionsTopicName, super.period);
    selectedSubscription =
        ntConnection.subscribe(selectedTopicName, super.period);
    activeSubscription = ntConnection.subscribe(activeTopicName, super.period);
    defaultSubscription =
        ntConnection.subscribe(defaultTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _selectedTopic = null;

    super.resetSubscription();
  }

  void publishSelectedValue(String? selected) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    _selectedTopic ??=
        ntConnection.publishNewTopic(selectedTopicName, NT4TypeStr.kString);

    ntConnection.updateDataFromTopic(_selectedTopic!, selected);
  }

  void _publishActiveValue(String? active) {
    if (active == null || !ntConnection.isNT4Connected) {
      return;
    }

    bool publishTopic = _activeTopic == null;

    _activeTopic ??= ntConnection.getTopicFromName(activeTopicName);

    if (_activeTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_activeTopic!);
    }

    ntConnection.updateDataFromTopic(_activeTopic!, active);
  }
}

class SplitButtonChooser extends NTWidget {
  static const String widgetType = 'Split Button Chooser';

  const SplitButtonChooser({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    SplitButtonChooserModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        List<Object?> rawOptions =
            model.optionsSubscription.value?.tryCast<List<Object?>>() ?? [];

        List<String> options = rawOptions.whereType<String>().toList();

        String? active = tryCast(model.activeSubscription.value);
        if (active != null && active == '') {
          active = null;
        }

        String? selected = tryCast(model.selectedSubscription.value);
        if (selected != null && selected == '') {
          selected = null;
        }

        String? defaultOption = tryCast(model.defaultSubscription.value);
        if (defaultOption != null && defaultOption == '') {
          defaultOption = null;
        }

        if (!model.ntConnection.isNT4Connected) {
          active = null;
          selected = null;
          defaultOption = null;
        }

        StringChooserData currentData = StringChooserData(
            options: options,
            active: active,
            defaultOption: defaultOption,
            selected: selected);

        // If a choice has been selected previously but the topic on NT has no value, publish it
        // This can happen if NT happens to restart
        if (currentData.selectedChanged(model.previousData)) {
          if (selected != null && model.selectedChoice != selected) {
            model.selectedChoice = selected;
          }
        } else if (currentData.activeChanged(model.previousData) ||
            active == null) {
          if (selected == null && model.selectedChoice != null) {
            if (options.contains(model.selectedChoice!)) {
              model.publishSelectedValue(model.selectedChoice!);
            } else if (options.isNotEmpty) {
              model.selectedChoice = active;
            }
          }
        }

        // If nothing is selected but NT has an active value, set the selected to the NT value
        // This happens on program startup
        if (active != null && model.selectedChoice == null) {
          model.selectedChoice = active;
        }

        model.previousData = currentData;

        bool showWarning = active != model.selectedChoice;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ToggleButtons(
                  onPressed: (index) {
                    model.selectedChoice = options[index];

                    model.publishSelectedValue(model.selectedChoice!);
                  },
                  isSelected: options.map((String option) {
                    if (option == model.selectedChoice) {
                      return true;
                    }
                    return false;
                  }).toList(),
                  children: options.map((String option) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(option),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 5),
            (showWarning)
                ? const Tooltip(
                    message:
                        'Selected value has not been published to Network Tables.\nRobot code will not be receiving the correct value.',
                    child: Icon(Icons.priority_high, color: Colors.red),
                  )
                : const Icon(Icons.check, color: Colors.green),
          ],
        );
      },
    );
  }
}
