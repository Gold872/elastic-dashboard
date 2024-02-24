import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class BooleanBox extends NTWidget {
  static const String widgetType = 'Boolean Box';
  @override
  String type = widgetType;

  late Color _trueColor;
  late Color _falseColor;

  BooleanBox({
    super.key,
    required super.topic,
    Color trueColor = Colors.green,
    Color falseColor = Colors.red,
    super.dataType,
    super.period,
  })  : _falseColor = falseColor,
        _trueColor = trueColor,
        super();

  BooleanBox.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    int? trueColorValue =
        tryCast(jsonData['true_color']) ?? tryCast(jsonData['colorWhenTrue']);
    int? falseColorValue =
        tryCast(jsonData['false_color']) ?? tryCast(jsonData['colorWhenFalse']);

    if (trueColorValue == null) {
      String? hexString = tryCast(jsonData['colorWhenTrue']);

      if (hexString != null) {
        hexString = hexString.toUpperCase().replaceAll('#', '');

        if (hexString.length == 6) {
          hexString = 'FF$hexString';
        }

        trueColorValue = int.tryParse(hexString, radix: 16);
      }
    }

    if (falseColorValue == null) {
      String? hexString = tryCast(jsonData['colorWhenFalse']);

      if (hexString != null) {
        hexString = hexString.toUpperCase().replaceAll('#', '');

        if (hexString.length == 6) {
          hexString = 'FF$hexString';
        }

        falseColorValue = int.tryParse(hexString, radix: 16);
      }
    }

    _trueColor = Color(trueColorValue ?? Colors.green.value);
    _falseColor = Color(falseColorValue ?? Colors.red.value);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'true_color': _trueColor.value,
      'false_color': _falseColor.value,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          DialogColorPicker(
            onColorPicked: (Color color) {
              _trueColor = color;
              refresh();
            },
            label: 'True Color',
            initialColor: _trueColor,
          ),
          const SizedBox(width: 10),
          DialogColorPicker(
            onColorPicked: (Color color) {
              _falseColor = color;
              refresh();
            },
            label: 'False Color',
            initialColor: _falseColor,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        bool value = tryCast(snapshot.data) ?? false;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: (value) ? _trueColor : _falseColor,
          ),
        );
      },
    );
  }
}
