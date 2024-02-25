import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ComboBoxChooserModel extends NTWidgetModel {
  @override
  String type = ComboBoxChooser.widgetType;

  String get optionsTopicName => '$topic/options';
  String get selectedTopicName => '$topic/selected';
  String get activeTopicName => '$topic/active';
  String get defaultTopicName => '$topic/default';

  final TextEditingController _searchController = TextEditingController();

  String? selectedChoice;

  StringChooserData? previousData;

  NT4Topic? _selectedTopic;
  NT4Topic? _activeTopic;

  bool _sortOptions = false;

  get sortOptions => _sortOptions;

  set sortOptions(value) {
    _sortOptions = value;
    refresh();
  }

  ComboBoxChooserModel({
    required super.topic,
    bool sortOptions = false,
    super.dataType,
    super.period,
  })  : _sortOptions = sortOptions,
        super();

  ComboBoxChooserModel.fromJson({required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _sortOptions = tryCast(jsonData['sort_options']) ?? _sortOptions;
  }

  @override
  void resetSubscription() {
    _selectedTopic = null;

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'sort_options': _sortOptions,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogToggleSwitch(
        label: 'Sort Options Alphabetically',
        initialValue: _sortOptions,
        onToggle: (value) {
          sortOptions = value;
        },
      ),
    ];
  }

  void publishSelectedValue(String? selected) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    _selectedTopic ??= ntConnection.nt4Client
        .publishNewTopic(selectedTopicName, NT4TypeStr.kString);

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
      ntConnection.nt4Client.publishTopic(_activeTopic!);
    }

    ntConnection.updateDataFromTopic(_activeTopic!, active);
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

    return [
      ...options,
      active,
      selected,
      defaultOption,
    ];
  }
}

class ComboBoxChooser extends NTWidget {
  static const String widgetType = 'ComboBox Chooser';

  const ComboBoxChooser({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    ComboBoxChooserModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        List<Object?> rawOptions = ntConnection
                .getLastAnnouncedValue(model.optionsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<String> options = rawOptions.whereType<String>().toList();

        if (model.sortOptions) {
          options.sort();
        }

        String? active =
            tryCast(ntConnection.getLastAnnouncedValue(model.activeTopicName));
        if (active != null && active == '') {
          active = null;
        }

        String? selected = tryCast(
            ntConnection.getLastAnnouncedValue(model.selectedTopicName));
        if (selected != null && selected == '') {
          selected = null;
        }

        String? defaultOption =
            tryCast(ntConnection.getLastAnnouncedValue(model.defaultTopicName));
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
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 36.0,
                ),
                child: _StringChooserDropdown(
                  selected: model.selectedChoice,
                  options: options,
                  textController: model._searchController,
                  onValueChanged: (String? value) {
                    model.publishSelectedValue(value);

                    model.selectedChoice = value;
                  },
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
