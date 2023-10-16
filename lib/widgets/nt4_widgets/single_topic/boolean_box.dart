import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BooleanBox extends StatelessWidget with NT4Widget {
  @override
  String type = 'Boolean Box';

  Color trueColor;
  Color falseColor;

  BooleanBox({
    super.key,
    required topic,
    this.trueColor = Colors.green,
    this.falseColor = Colors.red,
    period = Globals.defaultPeriod,
  }) {
    super.topic = topic;
    super.period = period;

    init();
  }

  BooleanBox.fromJson({super.key, required Map<String, dynamic> jsonData})
      : trueColor =
            Color(tryCast(jsonData['true_color']) ?? Colors.green.value),
        falseColor =
            Color(tryCast(jsonData['false_color']) ?? Colors.red.value) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
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
      stream: subscription?.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
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
