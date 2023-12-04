import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RelayWidget extends NT4Widget {
  static const String widgetType = 'Relay';
  @override
  String type = widgetType;

  late String valueTopicName;
  late NT4Subscription valueSubscription;
  NT4Topic? valueTopic;

  final List<String> selectedOptions = ['Off', 'On', 'Forward', 'Reverse'];

  RelayWidget({super.key, required super.topic, super.period}) : super();

  RelayWidget.fromJson({super.key, required super.jsonData}) : super.fromJson();

  @override
  void init() {
    super.init();

    valueTopicName = '$topic/Value';
    valueSubscription = nt4Connection.subscribe(valueTopicName, super.period);
  }

  @override
  void resetSubscription() {
    nt4Connection.unSubscribe(valueSubscription);

    valueTopicName = '$topic/Value';
    valueSubscription = nt4Connection.subscribe(valueTopicName, super.period);
    valueTopic = null;

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    nt4Connection.unSubscribe(valueSubscription);
    valueTopic = null;
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: valueSubscription.periodicStream(yieldAll: false),
      initialData: nt4Connection.getLastAnnouncedValue(valueTopicName),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        String selected = tryCast(snapshot.data) ?? 'Off';

        if (!selectedOptions.contains(selected)) {
          selected = 'Off';
        }

        return SingleChildScrollView(
          child: Row(
            children: [
              Expanded(
                child: ToggleButtons(
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    maxWidth: double.infinity,
                    minHeight: 40,
                    maxHeight: 40,
                  ),
                  direction: Axis.vertical,
                  onPressed: (index) {
                    String option = selectedOptions[index];

                    bool publishTopic = valueTopic == null;

                    valueTopic ??=
                        nt4Connection.getTopicFromName(valueTopicName);

                    if (valueTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      nt4Connection.nt4Client.publishTopic(valueTopic!);
                    }

                    nt4Connection.updateDataFromTopic(valueTopic!, option);
                  },
                  isSelected:
                      selectedOptions.map((e) => selected == e).toList(),
                  children: selectedOptions.map((element) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 0.0),
                      child: Text(element),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
