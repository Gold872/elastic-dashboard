import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ComboBoxChooserModel extends MultiTopicNTWidgetModel {
  @override
  String type = ComboBoxChooser.widgetType;

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

  final TextEditingController _searchController = TextEditingController();

  String? _selectedChoice;

  String? get selectedChoice => _selectedChoice;

  set selectedChoice(value) {
    _selectedChoice = value;
    refresh();
  }

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
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool sortOptions = false,
    super.dataType,
    super.period,
  })  : _sortOptions = sortOptions,
        super();

  ComboBoxChooserModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _sortOptions = tryCast(jsonData['sort_options']) ?? _sortOptions;
  }

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

class ComboBoxChooser extends NTWidget {
  static const String widgetType = 'ComboBox Chooser';

  const ComboBoxChooser({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    ComboBoxChooserModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        List<Object?> rawOptions =
            model.optionsSubscription.value?.tryCast<List<Object?>>() ?? [];

        List<String> options = rawOptions.whereType<String>().toList();

        if (model.sortOptions) {
          options.sort();
        }

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return DropdownButton2<String>(
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
                width: max(constraints.maxWidth, 250),
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
                  child: Text(option,
                      style: Theme.of(context).textTheme.bodyMedium),
                );
              }).toList(),
              onMenuStateChange: (isOpen) {
                if (!isOpen) {
                  textController.clear();
                }
              },
              onChanged: onValueChanged,
            );
          },
        ),
      ),
    );
  }
}
