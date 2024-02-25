import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class AccelerometerModel extends NTWidgetModel {
  @override
  String type = AccelerometerWidget.widgetType;

  late NT4Subscription _valueSubscription;

  String get valueTopic => '$topic/Value';

  AccelerometerModel({required super.topic, super.dataType, super.period})
      : super();

  AccelerometerModel.fromJson({required super.jsonData}) : super.fromJson();

  @override
  void init() {
    super.init();

    _valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(_valueSubscription);

    _valueSubscription = ntConnection.subscribe(valueTopic, super.period);

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    ntConnection.unSubscribe(_valueSubscription);

    super.unSubscribe();
  }

  NT4Subscription get valueSubscription => _valueSubscription;
}

class AccelerometerWidget extends NTWidget {
  static const String widgetType = 'Accelerometer';

  const AccelerometerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    AccelerometerModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
        stream: model.valueSubscription.periodicStream(yieldAll: false),
        initialData: ntConnection.getLastAnnouncedValue(model.valueTopic),
        builder: (context, snapshot) {
          double value = tryCast(snapshot.data) ?? 0.0;

          return Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '${value.toStringAsFixed(2)} g',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        });
  }
}
