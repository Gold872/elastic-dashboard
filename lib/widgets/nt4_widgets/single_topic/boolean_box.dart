import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BooleanBox extends NT4Widget {
  static const String widgetType = 'Boolean Box';
  @override
  String type = widgetType;

  late Color trueColor;
  late Color falseColor;

  BooleanBox({
    super.key,
    required super.topic,
    this.trueColor = Colors.green,
    this.falseColor = Colors.red,
    super.period,
  }) : super();

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

    trueColor = Color(trueColorValue ?? Colors.green.value);
    falseColor = Color(falseColorValue ?? Colors.red.value);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'true_color': trueColor.value,
      'false_color': falseColor.value,
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
              trueColor = color;
              refresh();
            },
            label: 'True Color',
            initialColor: trueColor,
          ),
          const SizedBox(width: 10),
          DialogColorPicker(
            onColorPicked: (Color color) {
              falseColor = color;
              refresh();
            },
            label: 'False Color',
            initialColor: falseColor,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        bool value = tryCast(snapshot.data) ?? false;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: (value) ? trueColor : falseColor,
          ),
        );
      },
    );
  }
}
