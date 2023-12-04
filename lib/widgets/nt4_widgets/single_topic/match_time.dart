import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MatchTimeWidget extends NT4Widget {
  @override
  String type = 'Match Time';

  MatchTimeWidget({super.key, required super.topic, super.period}) : super();

  MatchTimeWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  Color _getTimeColor(num time) {
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
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        double time = tryCast(snapshot.data) ?? -1.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.contain,
              child: Text(
                '${time.floor()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _getTimeColor(time.floor()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
