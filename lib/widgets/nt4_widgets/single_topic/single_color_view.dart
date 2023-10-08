import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SingleColorView extends StatelessWidget with NT4Widget {
  @override
  String type = 'Single Color View';

  SingleColorView({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  SingleColorView.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        String hexString = snapshot.data as String? ?? "";

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
