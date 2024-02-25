import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class UltrasonicModel extends NTWidgetModel {
  @override
  String type = Ultrasonic.widgetType;

  String get valueTopic => '$topic/Value';

  late NT4Subscription valueSubscription;

  UltrasonicModel({required super.topic, super.dataType, super.period})
      : super();

  UltrasonicModel.fromJson({required super.jsonData}) : super.fromJson();

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

class Ultrasonic extends NTWidget {
  static const String widgetType = 'Ultrasonic';

  const Ultrasonic({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    UltrasonicModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.valueSubscription.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(model.valueTopic),
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
