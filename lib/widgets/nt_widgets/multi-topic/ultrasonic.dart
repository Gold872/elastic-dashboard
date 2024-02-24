import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class Ultrasonic extends NTWidget {
  static const String widgetType = 'Ultrasonic';
  @override
  String type = widgetType;

  late String _valueTopic;
  late NT4Subscription _valueSubscription;

  Ultrasonic({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  Ultrasonic.fromJson({super.key, required super.jsonData}) : super.fromJson();

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
      initialData: ntConnection.getLastAnnouncedValue(_valueTopic),
      builder: (context, snapshot) {
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
