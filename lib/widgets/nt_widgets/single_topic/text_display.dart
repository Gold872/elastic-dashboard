import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class TextDisplay extends NTWidget {
  static const String widgetType = 'Text Display';
  @override
  String type = widgetType;

  final TextEditingController _controller = TextEditingController();

  Object? _previousValue;

  bool showSubmitButton = false;

  TextDisplay({
    super.key,
    required super.topic,
    this.showSubmitButton = false,
    super.dataType,
    super.period,
  }) : super();

  TextDisplay.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    showSubmitButton =
        tryCast(jsonData['show_submit_button']) ?? showSubmitButton;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogToggleSwitch(
        label: 'Show Submit Button',
        initialValue: showSubmitButton,
        onToggle: (value) {
          showSubmitButton = value;
          refresh();
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

  void _publishData(String value) {
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
      ntConnection.nt4Client.publishTopic(ntTopic!);
    }

    if (formattedData != null) {
      ntConnection.updateDataFromTopic(ntTopic!, formattedData);
    }

    _previousValue = value;
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        Object data = snapshot.data ?? Object();

        if (data.toString() != _previousValue.toString() &&
            !data.isExactType<Object>()) {
          // Needed to prevent errors
          Future(() async {
            _controller.text = data.toString();

            _previousValue = data;
          });
        }

        return Row(
          children: [
            Flexible(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.bottom,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  _publishData(value);
                },
              ),
            ),
            if (showSubmitButton) ...[
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
                      _publishData(_controller.text);
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
