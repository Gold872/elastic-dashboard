import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ComboBoxChooser extends NTWidget {
  static const String widgetType = 'ComboBox Chooser';
  @override
  String type = widgetType;

  late String optionsTopicName;
  late String selectedTopicName;
  late String activeTopicName;
  late String defaultTopicName;

  TextEditingController searchController = TextEditingController();

  String? selectedChoice;

  StringChooserData? _previousData;

  NT4Topic? selectedTopic;
  NT4Topic? activeTopic;

  ComboBoxChooser({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ComboBoxChooser.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    optionsTopicName = '$topic/options';
    selectedTopicName = '$topic/selected';
    activeTopicName = '$topic/active';
    defaultTopicName = '$topic/default';
  }

  @override
  void resetSubscription() {
    optionsTopicName = '$topic/options';
    selectedTopicName = '$topic/selected';
    activeTopicName = '$topic/active';
    defaultTopicName = '$topic/default';

    selectedTopic = null;

    super.resetSubscription();
  }

  void publishSelectedValue(String? selected) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    selectedTopic ??= ntConnection.nt4Client
        .publishNewTopic(selectedTopicName, NT4TypeStr.kString);

    ntConnection.updateDataFromTopic(selectedTopic!, selected);
  }

  void publishActiveValue(String? active) {
    if (active == null || !ntConnection.isNT4Connected) {
      return;
    }

    bool publishTopic = activeTopic == null;

    activeTopic ??= ntConnection.getTopicFromName(activeTopicName);

    if (activeTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(activeTopic!);
    }

    ntConnection.updateDataFromTopic(activeTopic!, active);
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawOptions = ntConnection
            .getLastAnnouncedValue(optionsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<String> options = rawOptions.whereType<String>().toList();

    String active =
        tryCast(ntConnection.getLastAnnouncedValue(activeTopicName)) ?? '';

    String selected =
        tryCast(ntConnection.getLastAnnouncedValue(selectedTopicName)) ?? '';

    String defaultOption =
        tryCast(ntConnection.getLastAnnouncedValue(defaultTopicName)) ?? '';

    return [options, active, selected, defaultOption];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        List<Object?> rawOptions = ntConnection
                .getLastAnnouncedValue(optionsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<String> options = rawOptions.whereType<String>().toList();

        String? active =
            tryCast(ntConnection.getLastAnnouncedValue(activeTopicName));
        if (active != null && active == '') {
          active = null;
        }

        String? selected =
            tryCast(ntConnection.getLastAnnouncedValue(selectedTopicName));
        if (selected != null && selected == '') {
          selected = null;
        }

        String? defaultOption =
            tryCast(ntConnection.getLastAnnouncedValue(defaultTopicName));
        if (defaultOption != null && defaultOption == '') {
          defaultOption = null;
        }

        if (!ntConnection.isNT4Connected) {
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
            Flexible(
              child: _StringChooserDropdown(
                selected: selectedChoice,
                options: options,
                textController: searchController,
                onValueChanged: (String? value) {
                  publishSelectedValue(value);

                  selectedChoice = value;
                },
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

class StringChooserData {
  final List<String> options;
  final String? active;
  final String? defaultOption;
  final String? selected;

  const StringChooserData(
      {required this.options,
      required this.active,
      required this.defaultOption,
      required this.selected});

  bool optionsChanged(StringChooserData? other) {
    return options != other?.options;
  }

  bool activeChanged(StringChooserData? other) {
    return active != other?.active;
  }

  bool defaultOptionChanged(StringChooserData? other) {
    return defaultOption != other?.defaultOption;
  }

  bool selectedChanged(StringChooserData? other) {
    return selected != other?.selected;
  }
}

class _StringChooserDropdown extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(String? value) onValueChanged;
  final TextEditingController textController;

  const _StringChooserDropdown({
    required this.options,
    required this.onValueChanged,
    required this.textController,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Tooltip(
        message: selected ?? '',
        waitDuration: const Duration(milliseconds: 250),
        child: DropdownButton2<String>(
          isExpanded: true,
          value: selected,
          selectedItemBuilder: (context) => [
            ...options.map((String option) {
              return Container(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.0),
            ),
            maxHeight: 250,
            width: 250,
          ),
          dropdownSearchData: DropdownSearchData(
            searchController: textController,
            searchMatchFn: (item, searchValue) {
              return item.value
                  .toString()
                  .toLowerCase()
                  .contains(searchValue.toLowerCase());
            },
            searchInnerWidgetHeight: 50,
            searchInnerWidget: Container(
              color: Theme.of(context).colorScheme.surface,
              height: 50,
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 4,
                right: 8,
                left: 8,
              ),
              child: TextFormField(
                expands: true,
                maxLines: null,
                controller: textController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  label: const Text('Search'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          items: options.map((String option) {
            return DropdownMenuItem(
              value: option,
              child:
                  Text(option, style: Theme.of(context).textTheme.bodyMedium),
            );
          }).toList(),
          onMenuStateChange: (isOpen) {
            if (!isOpen) {
              textController.clear();
            }
          },
          onChanged: onValueChanged,
        ),
      ),
    );
  }
}
