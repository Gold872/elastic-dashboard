import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RelayModel extends NTWidgetModel {
  @override
  String type = RelayWidget.widgetType;

  String get valueTopicName => '$topic/Value';

  late NT4Subscription valueSubscription;
  NT4Topic? valueTopic;

  final List<String> selectedOptions = ['Off', 'On', 'Forward', 'Reverse'];

  RelayModel({required super.topic, super.dataType, super.period}) : super();

  RelayModel.fromJson({required super.jsonData}) : super.fromJson();

  @override
  void init() {
    super.init();

    valueSubscription = ntConnection.subscribe(valueTopicName, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(valueSubscription);

    valueSubscription = ntConnection.subscribe(valueTopicName, super.period);
    valueTopic = null;

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    ntConnection.unSubscribe(valueSubscription);
    valueTopic = null;
  }
}

class RelayWidget extends NTWidget {
  static const String widgetType = 'Relay';

  const RelayWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    RelayModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.valueSubscription.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(model.valueTopicName),
      builder: (context, snapshot) {
        String selected = tryCast(snapshot.data) ?? 'Off';

        if (!model.selectedOptions.contains(selected)) {
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
                    String option = model.selectedOptions[index];

                    bool publishTopic = model.valueTopic == null;

                    model.valueTopic ??=
                        ntConnection.getTopicFromName(model.valueTopicName);

                    if (model.valueTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      ntConnection.nt4Client.publishTopic(model.valueTopic!);
                    }

                    ntConnection.updateDataFromTopic(model.valueTopic!, option);
                  },
                  isSelected:
                      model.selectedOptions.map((e) => selected == e).toList(),
                  children: model.selectedOptions.map((element) {
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
