import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MotorControllerModel extends NTWidgetModel {
  @override
  String type = MotorController.widgetType;

  String get valueTopic => '$topic/Value';

  late NT4Subscription valueSubscription;

  MotorControllerModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  MotorControllerModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void init() {
    super.init();

    valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(valueSubscription);

    valueSubscription = ntConnection.subscribe(valueTopic, super.period);

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    ntConnection.unSubscribe(valueSubscription);

    super.unSubscribe();
  }
}

class MotorController extends NTWidget {
  static const String widgetType = 'Motor Controller';

  const MotorController({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    MotorControllerModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.valueSubscription.periodicStream(yieldAll: false),
      initialData: model.ntConnection.getLastAnnouncedValue(model.valueTopic),
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
