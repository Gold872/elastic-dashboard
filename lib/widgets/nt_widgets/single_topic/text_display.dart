import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class TextDisplay extends NTWidget {
  static const String widgetType = 'Text Display';
  @override
  String type = widgetType;

  final TextEditingController _controller = TextEditingController();

  Object? _previousValue;

  TextDisplay({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  TextDisplay.fromJson({super.key, required super.jsonData}) : super.fromJson();

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

        return TextField(
          controller: _controller,
          textAlign: TextAlign.left,
          textAlignVertical: TextAlignVertical.bottom,
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 0.0, vertical: 10.0),
            isDense: true,
          ),
          onSubmitted: (value) {
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
          },
        );
      },
    );
  }
}
