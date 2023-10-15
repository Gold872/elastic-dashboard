import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';

class MatchTimeWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Match Time';

  MatchTimeWidget({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  MatchTimeWidget.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

  Color _getTimeColor(double time) {
    if (time <= 15.0) {
      return Colors.red;
    } else if (time <= 30.0) {
      return Colors.yellow;
    } else if (time <= 60.0) {
      return Colors.green;
    }

    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        double time = tryCast(snapshot.data) ?? -1.0;

        return Text('${time.ceil()}',
            style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  color: _getTimeColor(time.ceil().toDouble()),
                ));
      },
    );
  }
}
