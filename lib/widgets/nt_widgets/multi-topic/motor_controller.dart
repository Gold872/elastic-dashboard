import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MotorController extends NTWidget {
  static const String widgetType = 'Motor Controller';
  @override
  String type = widgetType;

  late String _valueTopic;
  late NT4Subscription _valueSubscription;

  MotorController({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  MotorController.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    _valueTopic = '$topic/Value';
    _valueSubscription = ntConnection.subscribe(_valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(_valueSubscription);

    _valueTopic = '$topic/Value';
    _valueSubscription = ntConnection.subscribe(_valueTopic, super.period);

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    ntConnection.unSubscribe(_valueSubscription);

    super.unSubscribe();
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: _valueSubscription.periodicStream(yieldAll: false),
      builder: (context, snapshot) {
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
