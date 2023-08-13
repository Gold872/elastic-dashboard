import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplitButtonChooser extends StatelessWidget with NT4Widget {
  @override
  String type = 'Split Button Chooser';

  late String optionsTopicName;
  late String selectedTopicName;
  late String activeTopicName;
  late String defaultTopicName;

  String? selectedChoice;

  StringChooserData? _previousData;

  NT4Topic? selectedTopic;

  SplitButtonChooser({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  SplitButtonChooser.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    optionsTopicName = '$topic/options';
    selectedTopicName = '$topic/selected';
    activeTopicName = '$topic/active';
    defaultTopicName = '$topic/default';
  }

  void publishSelectedValue(String? selected) {
    if (selected == null || !NT4Connection.connected) {
      return;
    }

    selectedTopic ??= NT4Connection.nt4Client
        .publishNewTopic(selectedTopicName, NT4TypeStr.kString);

    NT4Connection.updateDataFromTopic(selectedTopic!, selected);
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();
    
    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        List<Object?> rawOptions =
            NT4Connection.getLastAnnouncedValue(optionsTopicName)
                    as List<Object?>? ??
                [];

        List<String> options = [];

        for (Object? option in rawOptions) {
          if (option == null || option is! String) {
            continue;
          }

          options.add(option);
        }

        String? active =
            NT4Connection.getLastAnnouncedValue(activeTopicName) as String?;
        if (active != null && active == '') {
          active = null;
        }

        String? selected =
            NT4Connection.getLastAnnouncedValue(selectedTopicName) as String?;
        if (selected != null && selected == '') {
          selected = null;
        }

        String? defaultOption =
            NT4Connection.getLastAnnouncedValue(defaultTopicName) as String?;

        if (defaultOption != null && defaultOption == '') {
          defaultOption = null;
        }

        if (!NT4Connection.connected) {
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
        if (currentData.selectedChanged(_previousData)) {
          if (selected != null && selectedChoice != selected) {
            selectedChoice = selected;
          }
        } else if (currentData.activeChanged(_previousData) || active == null) {
          if (selected == null && selectedChoice != null) {
            if (options.contains(selectedChoice!)) {
              publishSelectedValue(selectedChoice!);
            } else if (options.isNotEmpty) {
              selectedChoice = active;
            }
          }
        }

        // If nothing is selected but NT has an active value, set the selected to the NT value
        // This happens on program startup
        if (active != null && selectedChoice == null) {
          selectedChoice = active;
        }

        _previousData = currentData;

        bool showWarning = active != selectedChoice;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToggleButtons(
              onPressed: (index) {
                selectedChoice = options[index];

                publishSelectedValue(selectedChoice!);
              },
              isSelected: options.map((String option) {
                if (option == selectedChoice) {
                  return true;
                }
                return false;
              }).toList(),
              children: options.map((String option) {
                return Text(option);
              }).toList(),
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
