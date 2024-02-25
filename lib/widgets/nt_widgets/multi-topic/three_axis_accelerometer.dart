import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ThreeAxisAccelerometerModel extends NTWidgetModel {
  @override
  String type = ThreeAxisAccelerometer.widgetType;

  String get xTopic => '$topic/X';
  String get yTopic => '$topic/Y';
  String get zTopic => '$topic/Z';

  ThreeAxisAccelerometerModel(
      {required super.topic, super.dataType, super.period})
      : super();

  ThreeAxisAccelerometerModel.fromJson({required super.jsonData})
      : super.fromJson();

  @override
  List<Object> getCurrentData() {
    double xAccel = tryCast(ntConnection.getLastAnnouncedValue(xTopic)) ?? 0.0;
    double yAccel = tryCast(ntConnection.getLastAnnouncedValue(yTopic)) ?? 0.0;
    double zAccel = tryCast(ntConnection.getLastAnnouncedValue(zTopic)) ?? 0.0;

    return [xAccel, yAccel, zAccel];
  }
}

class ThreeAxisAccelerometer extends NTWidget {
  static const String widgetType = '3-Axis Accelerometer';

  const ThreeAxisAccelerometer({super.key});

  @override
  Widget build(BuildContext context) {
    ThreeAxisAccelerometerModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        double xAccel =
            tryCast(ntConnection.getLastAnnouncedValue(model.xTopic)) ?? 0.0;
        double yAccel =
            tryCast(ntConnection.getLastAnnouncedValue(model.yTopic)) ?? 0.0;
        double zAccel =
            tryCast(ntConnection.getLastAnnouncedValue(model.zTopic)) ?? 0.0;

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
