import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccelerometerWidget extends NT4Widget {
  @override
  String type = 'Accelerometer';

  late String valueTopic;
  late NT4Subscription valueSubscription;

  AccelerometerWidget({super.key, required super.topic, super.period})
      : super() {
    init();
  }

  AccelerometerWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson() {
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
    nt4Connection.unSubscribe(valueSubscription);

    valueTopic = '$topic/Value';
    valueSubscription = nt4Connection.subscribe(valueTopic, super.period);

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    nt4Connection.unSubscribe(valueSubscription);

    super.unSubscribe();
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
        stream: valueSubscription.periodicStream(yieldAll: false),
        initialData: nt4Connection.getLastAnnouncedValue(valueTopic),
        builder: (context, snapshot) {
          notifier = context.watch<NT4WidgetNotifier?>();

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
