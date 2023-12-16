import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SingleColorView extends NTWidget {
  static const String widgetType = 'Single Color View';
  @override
  String type = widgetType;

  SingleColorView({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  SingleColorView.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        String hexString = tryCast(snapshot.data) ?? '';

        hexString = hexString.toUpperCase().replaceAll('#', '');

        if (hexString.length == 6) {
          hexString = 'FF$hexString';
        }

        int hexCode = int.tryParse(hexString, radix: 16) ?? 0x00000000;

        Color color = Color(hexCode);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            color: color,
          ),
        );
      },
    );
  }
}
