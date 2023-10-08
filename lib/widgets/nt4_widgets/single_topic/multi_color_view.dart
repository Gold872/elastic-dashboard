import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';

class MultiColorView extends StatelessWidget with NT4Widget {
  @override
  String type = 'Multi Color View';

  MultiColorView({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  MultiColorView.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        List<String?> hexStrings =
            (snapshot.data as List<Object?>?)?.whereType<String?>().toList() ??
                [];

        List<Color> colors = [];

        for (String? hexString in hexStrings) {
          if (hexString == null) {
            continue;
          }

          hexString = hexString.toUpperCase().replaceAll('#', '');

          if (hexString.length == 6) {
            hexString = 'FF$hexString';
          }

          int? hexCode = int.tryParse(hexString, radix: 16);

          if (hexCode != null) {
            colors.add(Color(hexCode));
          }
        }

        if (colors.length < 2) {
          if (colors.length == 1) {
            colors.add(colors[0]);
          } else {
            colors.add(Colors.transparent);
            colors.add(Colors.transparent);
          }
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            gradient: LinearGradient(
              colors: colors,
            ),
          ),
        );
      },
    );
  }
}
