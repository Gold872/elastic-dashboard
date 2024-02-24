import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ThreeAxisAccelerometer extends NTWidget {
  static const String widgetType = '3-Axis Accelerometer';
  @override
  String type = widgetType;

  late String _xTopic;
  late String _yTopic;
  late String _zTopic;

  ThreeAxisAccelerometer({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  });

  ThreeAxisAccelerometer.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    _xTopic = '$topic/X';
    _yTopic = '$topic/Y';
    _zTopic = '$topic/Z';
  }

  @override
  void resetSubscription() {
    _xTopic = '$topic/X';
    _yTopic = '$topic/Y';
    _zTopic = '$topic/Z';

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    double xAccel = tryCast(ntConnection.getLastAnnouncedValue(_xTopic)) ?? 0.0;
    double yAccel = tryCast(ntConnection.getLastAnnouncedValue(_yTopic)) ?? 0.0;
    double zAccel = tryCast(ntConnection.getLastAnnouncedValue(_zTopic)) ?? 0.0;

    return [xAccel, yAccel, zAccel];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        double xAccel =
            tryCast(ntConnection.getLastAnnouncedValue(_xTopic)) ?? 0.0;
        double yAccel =
            tryCast(ntConnection.getLastAnnouncedValue(_yTopic)) ?? 0.0;
        double zAccel =
            tryCast(ntConnection.getLastAnnouncedValue(_zTopic)) ?? 0.0;

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
