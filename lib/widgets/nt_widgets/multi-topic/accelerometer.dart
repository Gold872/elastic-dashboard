import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class AccelerometerWidget extends NTWidget {
  static const String widgetType = 'Accelerometer';
  @override
  String type = widgetType;

  late String valueTopic;
  late NT4Subscription valueSubscription;

  AccelerometerWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  AccelerometerWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    valueTopic = '$topic/Value';
    valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(valueSubscription);

    valueTopic = '$topic/Value';
    valueSubscription = ntConnection.subscribe(valueTopic, super.period);

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    ntConnection.unSubscribe(valueSubscription);

    super.unSubscribe();
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
        stream: valueSubscription.periodicStream(yieldAll: false),
        initialData: ntConnection.getLastAnnouncedValue(valueTopic),
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
