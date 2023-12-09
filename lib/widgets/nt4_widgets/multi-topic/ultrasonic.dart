import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class Ultrasonic extends NT4Widget {
  static const String widgetType = 'Ultrasonic';
  @override
  String type = widgetType;

  late String valueTopic;
  late NT4Subscription valueSubscription;

  Ultrasonic({super.key, required super.topic, super.period}) : super();

  Ultrasonic.fromJson({super.key, required super.jsonData}) : super.fromJson();

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
            const Text('Range'),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade700,
                      width: 1.5,
                    ),
                  ),
                ),
                child: SelectableText(
                  '${value.toStringAsPrecision(5)} in',
                  maxLines: 1,
                  showCursor: true,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
