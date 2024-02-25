import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SingleColorView extends NTWidget {
  static const String widgetType = 'Single Color View';

  const SingleColorView({super.key});

  @override
  Widget build(BuildContext context) {
    NTWidgetModel model = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: model.subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(model.topic),
      builder: (context, snapshot) {
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
