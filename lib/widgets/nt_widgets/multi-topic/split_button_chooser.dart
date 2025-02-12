import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';

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

  bool _buttonDirectionHorizontal = true;
  bool get buttonDirectionHorizontal => _buttonDirectionHorizontal;
  set buttonDirectionHorizontal(bool value) {
    _buttonDirectionHorizontal = value;
    refresh();
  }
  
  double _buttonFontSize = 20.0;
  double get buttonFontSize => _buttonFontSize;
  set buttonFontSize(double value) {
    _buttonFontSize = value;
    refresh();
  }
  
  double _buttonBorderSize = 2.0;
  double get buttonBorderSize => _buttonBorderSize;
  set buttonBorderSize(double value) {
    _buttonBorderSize = value;
    refresh();
  }

  SplitButtonChooserModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool? buttonDirectionHorizontal,
    double? buttonFontSize,
    double? buttonBorderSize,
    super.dataType,
    super.period,
  }) : super() {
    if (preferences.getBool(PrefKeys.buttonDirectionHorizontal) ?? false) {
      buttonDirectionHorizontal ??= true;
    } else {
      buttonDirectionHorizontal ??= false;
    }
    _buttonDirectionHorizontal = buttonDirectionHorizontal;

    if (preferences.getDouble(PrefKeys.buttonFontSize) != null) {
      buttonFontSize ??= preferences.getDouble(PrefKeys.buttonFontSize);
    } else {
      buttonFontSize ??= _buttonFontSize;
    }
    _buttonFontSize = tryCast(buttonFontSize) ?? 20.0;

    if (preferences.getDouble(PrefKeys.buttonBorderSize) != null) {
      buttonBorderSize ??= preferences.getDouble(PrefKeys.buttonBorderSize);
    } else {
      buttonBorderSize ??= _buttonBorderSize;
    }
    _buttonBorderSize = tryCast(buttonBorderSize) ?? 2.0;
  }

  SplitButtonChooserModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _buttonDirectionHorizontal =
        tryCast(jsonData['button_direction_horizontal']) ?? true;
    _buttonFontSize = tryCast(jsonData['button_text_size']) ?? 20.0;
    _buttonBorderSize = tryCast(jsonData['button_border_size']) ?? 2.0;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogToggleSwitch(
        label: 'Button Direction Horizontal',
        initialValue: _buttonDirectionHorizontal,
        onToggle: (value) {
          buttonDirectionHorizontal = value;
        },
      ),
      DialogTextInput(
        label: 'Font Size (0 for auto, 20 is default)',
        initialText: _buttonFontSize.toString(),
        onSubmit: (value) {
          buttonFontSize = double.tryParse(value) ?? 20.0;
        },
      ),
      DialogTextInput(
        label: 'Button border size (2 is default)',
        initialText: _buttonBorderSize.toString(),
        onSubmit: (value) {
          buttonBorderSize= double.tryParse(value) ?? 2.0;
        },
      ),
    ];
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'button_direction_horizontal': buttonDirectionHorizontal,
      'button_text_size': buttonFontSize,
      'button_padding': buttonBorderSize,
    };
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

  void publishSelectedValue(String? selected) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    _selectedTopic ??=
        ntConnection.publishNewTopic(selectedTopicName, NT4TypeStr.kString);

    Future(() => ntConnection.updateDataFromTopic(_selectedTopic!, selected));
  }
}

class SplitButtonChooser extends NTWidget {
  static const String widgetType = 'Split Button Chooser';

  const SplitButtonChooser({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    SplitButtonChooserModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) {
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

            double fontSize = model.buttonFontSize == 0.0
                ? model.buttonDirectionHorizontal
                    ? (constraints.maxHeight / 2.0)
                    : (constraints.maxWidth / 3.5)
                : model.buttonFontSize;
            fontSize = max(min(fontSize, 250.0), 10.0);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: model.buttonDirectionHorizontal ? Axis.horizontal : Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ToggleButtons(
                      direction: model._buttonDirectionHorizontal ? Axis.horizontal : Axis.vertical,
                      borderWidth: model._buttonBorderSize,
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
                          child: Text(
                            option,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: fontSize,
                            ),
                          ),
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
    );
  }
}
