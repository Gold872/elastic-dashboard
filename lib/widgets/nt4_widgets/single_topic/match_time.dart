import 'package:elastic_dashboard/services/globals.dart';
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
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    subscription?.yieldAll = false;
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
      builder: (context, snapshot) {
        double time = snapshot.data as double? ?? -1.0;

        return Text('${time.ceil()}',
            style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  color: _getTimeColor(time.ceil().toDouble()),
                ));
      },
    );
  }
}
