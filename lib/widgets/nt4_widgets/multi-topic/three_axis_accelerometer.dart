import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThreeAxisAccelerometer extends NT4Widget {
  static const String widgetType = '3-Axis Accelerometer';
  @override
  String type = widgetType;

  late String xTopic;
  late String yTopic;
  late String zTopic;

  ThreeAxisAccelerometer({super.key, required super.topic, super.period});

  ThreeAxisAccelerometer.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    xTopic = '$topic/X';
    yTopic = '$topic/Y';
    zTopic = '$topic/Z';
  }

  @override
  void resetSubscription() {
    xTopic = '$topic/X';
    yTopic = '$topic/Y';
    zTopic = '$topic/Z';

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    double xAccel = tryCast(nt4Connection.getLastAnnouncedValue(xTopic)) ?? 0.0;
    double yAccel = tryCast(nt4Connection.getLastAnnouncedValue(yTopic)) ?? 0.0;
    double zAccel = tryCast(nt4Connection.getLastAnnouncedValue(zTopic)) ?? 0.0;

    return [xAccel, yAccel, zAccel];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

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
