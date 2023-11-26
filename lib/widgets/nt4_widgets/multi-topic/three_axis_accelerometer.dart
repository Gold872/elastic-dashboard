import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThreeAxisAccelerometer extends StatelessWidget with NT4Widget {
  @override
  String type = '3-Axis Accelerometer';

  late String xTopic;
  late String yTopic;
  late String zTopic;

  ThreeAxisAccelerometer(
      {super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  ThreeAxisAccelerometer.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    xTopic = '$topic/X';
    yTopic = '$topic/Y';
    zTopic = '$topic/Z';
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    xTopic = '$topic/X';
    yTopic = '$topic/Y';
    zTopic = '$topic/Z';
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        double xAccel =
            tryCast(nt4Connection.getLastAnnouncedValue(xTopic)) ?? 0.0;
        double yAccel =
            tryCast(nt4Connection.getLastAnnouncedValue(yTopic)) ?? 0.0;
        double zAccel =
            tryCast(nt4Connection.getLastAnnouncedValue(zTopic)) ?? 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: [
            // X Acceleration
            Flexible(
              flex: 16,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('X'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '${xAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Flexible(
              child: SizedBox(height: 4.0),
            ),
            // Y Acceleration
            Flexible(
              flex: 16,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Y'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '${yAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Flexible(
              child: SizedBox(height: 4.0),
            ),
            // Z Acceleration
            Flexible(
              flex: 16,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Z'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '${zAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
