import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:decimal/decimal.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class TextDisplayModel extends SingleTopicNTWidgetModel {
  @override
  String type = TextDisplay.widgetType;

  final TextEditingController controller = TextEditingController();

  Object? previousValue;

  bool _showSubmitButton = false;

  bool get showSubmitButton => _showSubmitButton;

  set showSubmitButton(value) {
    _showSubmitButton = value;
    refresh();
  }

  TextDisplayModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showSubmitButton = false,
    super.dataType,
    super.period,
  })  : _showSubmitButton = showSubmitButton,
        super();

  TextDisplayModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showSubmitButton =
        tryCast(jsonData['show_submit_button']) ?? _showSubmitButton;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogToggleSwitch(
        label: 'Show Submit Button',
        initialValue: _showSubmitButton,
        onToggle: (value) {
          showSubmitButton = value;
        },
      ),
    ];
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'show_submit_button': showSubmitButton,
    };
  }

  void publishData(String value) {
    bool publishTopic =
        ntTopic == null || !ntConnection.isTopicPublished(ntTopic!);

    createTopicIfNull();

    if (ntTopic == null) {
      return;
    }

    late Object? formattedData;

    String dataType = ntTopic!.type;
    switch (dataType) {
      case NT4TypeStr.kBool:
        formattedData = bool.tryParse(value);
        break;
      case NT4TypeStr.kFloat32:
      case NT4TypeStr.kFloat64:
        formattedData = double.tryParse(value);
        break;
      case NT4TypeStr.kInt:
        formattedData = int.tryParse(value);
        break;
      case NT4TypeStr.kString:
        formattedData = value;
        break;
      case NT4TypeStr.kFloat32Arr:
      case NT4TypeStr.kFloat64Arr:
        formattedData = tryCast<List<dynamic>>(jsonDecode(value))
            ?.whereType<num>()
            .toList();
        break;
      case NT4TypeStr.kIntArr:
        formattedData = tryCast<List<dynamic>>(jsonDecode(value))
            ?.whereType<num>()
            .toList();
        break;
      case NT4TypeStr.kBoolArr:
        formattedData = tryCast<List<dynamic>>(jsonDecode(value))
            ?.whereType<bool>()
            .toList();
        break;
      case NT4TypeStr.kStringArr:
        formattedData = tryCast<List<dynamic>>(jsonDecode(value))
            ?.whereType<String>()
            .toList();
        break;
      default:
        break;
    }

    if (publishTopic) {
      ntConnection.publishTopic(ntTopic!);
    }

    if (formattedData != null) {
      ntConnection.updateDataFromTopic(ntTopic!, formattedData);
    }

    previousValue = value;
  }
}

class TextDisplay extends NTWidget {
  static const String widgetType = 'Text Display';

  const TextDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    TextDisplayModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.subscription!,
        model.controller,
      ]),
      builder: (context, child) {
        Object? data = model.subscription!.value;

        if (data?.toString() != model.previousValue?.toString()) {
          // Needed to prevent errors
          Future(() async {
            String displayString = data.toString();
            if (data is double) {
              if (cast<double>(data).abs() > 1e-10) {
                displayString = Decimal.parse(data.toString()).toString();
              } else {
                data = 0.0 * cast<double>(data).sign;
                displayString = data.toString();
              }
            }
            model.controller.text = displayString;

            model.previousValue = data;
          });
        }

        return Row(
          children: [
            Flexible(
              child: TextField(
                controller: model.controller,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.bottom,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  model.publishData(value);
                },
              ),
            ),
            if (model.showSubmitButton) ...[
              const SizedBox(width: 1.5),
              Tooltip(
                message: 'Publish Data',
                waitDuration: const Duration(milliseconds: 250),
                child: Container(
                  padding: EdgeInsets.zero,
                  width: 32.0,
                  height: 32.0,
                  child: IconButton(
                    iconSize: 18.0,
                    onPressed: () {
                      model.publishData(model.controller.text);
                    },
                    icon: const Icon(Icons.exit_to_app),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
