import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CommandSchedulerWidget extends StatelessWidget with NT4Widget {
  @override
  String type = 'Scheduler';

  NT4Topic? cancelTopic;

  late String namesTopicName;
  late String idsTopicName;
  late String cancelTopicName;

  CommandSchedulerWidget(
      {super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  CommandSchedulerWidget.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    namesTopicName = '$topic/Names';
    idsTopicName = '$topic/Ids';
    cancelTopicName = '$topic/Cancel';
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    namesTopicName = '$topic/Names';
    idsTopicName = '$topic/Ids';
    cancelTopicName = '$topic/Cancel';

    cancelTopic = null;
  }

  void cancelCommand(int id) {
    List<Object?> currentCancellationsRaw = nt4Connection
            .getLastAnnouncedValue(cancelTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<int> currentCancellations =
        currentCancellationsRaw.whereType<int>().toList();

    currentCancellations.add(id);

    cancelTopic ??= nt4Connection.nt4Client
        .publishNewTopic(cancelTopicName, NT4TypeStr.kIntArr);

    if (cancelTopic == null) {
      return;
    }

    nt4Connection.updateDataFromTopic(cancelTopic!, currentCancellations);
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        List<Object?> rawNames = nt4Connection
                .getLastAnnouncedValue(namesTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<Object?> rawIds = nt4Connection
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
