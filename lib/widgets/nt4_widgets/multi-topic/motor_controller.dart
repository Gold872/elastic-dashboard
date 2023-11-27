import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class MotorController extends StatelessWidget with NT4Widget {
  @override
  String type = 'Motor Controller';

  late String valueTopic;
  late NT4Subscription valueSubscription;

  MotorController({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  MotorController.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    valueTopic = '$topic/Value';
    valueSubscription = nt4Connection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    nt4Connection.unSubscribe(valueSubscription);

    valueTopic = '$topic/Value';
    valueSubscription = nt4Connection.subscribe(valueTopic, super.period);
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    nt4Connection.unSubscribe(valueSubscription);
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: valueSubscription.periodicStream(yieldAll: false),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        double value = tryCast(snapshot.data) ?? 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Flexible(
              child: SizedBox(height: 5),
            ),
            SfLinearGauge(
              maximum: 1.0,
              minimum: -1.0,
              markerPointers: [
                LinearShapePointer(
                  value: value.clamp(-1.0, 1.0),
                  color: Theme.of(context).colorScheme.primary,
                  width: 10.0,
                  height: 14.0,
                  enableAnimation: false,
                  shapeType: LinearShapePointerType.diamond,
                  position: LinearElementPosition.cross,
                ),
              ],
              interval: 0.5,
            ),
          ],
        );
      },
    );
  }
}
