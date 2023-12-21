import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandSchedulerWidget extends NTWidget {
  static const String widgetType = 'Scheduler';
  @override
  String type = widgetType;

  NT4Topic? cancelTopic;

  late String namesTopicName;
  late String idsTopicName;
  late String cancelTopicName;

  CommandSchedulerWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  CommandSchedulerWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    namesTopicName = '$topic/Names';
    idsTopicName = '$topic/Ids';
    cancelTopicName = '$topic/Cancel';
  }

  @override
  void resetSubscription() {
    namesTopicName = '$topic/Names';
    idsTopicName = '$topic/Ids';
    cancelTopicName = '$topic/Cancel';

    cancelTopic = null;

    super.resetSubscription();
  }

  void cancelCommand(int id) {
    List<Object?> currentCancellationsRaw = ntConnection
            .getLastAnnouncedValue(cancelTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<int> currentCancellations =
        currentCancellationsRaw.whereType<int>().toList();

    currentCancellations.add(id);

    cancelTopic ??= ntConnection.nt4Client
        .publishNewTopic(cancelTopicName, NT4TypeStr.kIntArr);

    if (cancelTopic == null) {
      return;
    }

    ntConnection.updateDataFromTopic(cancelTopic!, currentCancellations);
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawNames = ntConnection
            .getLastAnnouncedValue(namesTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<Object?> rawIds = ntConnection
            .getLastAnnouncedValue(idsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<String> names = rawNames.whereType<String>().toList();
    List<int> ids = rawIds.whereType<int>().toList();

    return [names, ids];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        List<Object?> rawNames = ntConnection
                .getLastAnnouncedValue(namesTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<Object?> rawIds = ntConnection
                .getLastAnnouncedValue(idsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<String> names = rawNames.whereType<String>().toList();
        List<int> ids = rawIds.whereType<int>().toList();

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4.0, top: 4.0, right: 4.0),
              child:
                  Text('Scheduled Commands:', overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                itemCount: names.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.only(left: 16.0, right: 8.0),
                    visualDensity: const VisualDensity(
                        vertical: VisualDensity.minimumDensity),
                    title: Text(names[index], overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Cancel Command',
                      onPressed: () {
                        cancelCommand(ids[index]);
                      },
                      color: Colors.red,
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                    subtitle: Text(
                      'ID: ${ids[index].toString()}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
