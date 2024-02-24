import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RelayWidget extends NTWidget {
  static const String widgetType = 'Relay';
  @override
  String type = widgetType;

  late String _valueTopicName;
  late NT4Subscription _valueSubscription;
  NT4Topic? _valueTopic;

  final List<String> _selectedOptions = ['Off', 'On', 'Forward', 'Reverse'];

  RelayWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  RelayWidget.fromJson({super.key, required super.jsonData}) : super.fromJson();

  @override
  void init() {
    super.init();

    _valueTopicName = '$topic/Value';
    _valueSubscription = ntConnection.subscribe(_valueTopicName, super.period);
  }

  @override
  void resetSubscription() {
    ntConnection.unSubscribe(_valueSubscription);

    _valueTopicName = '$topic/Value';
    _valueSubscription = ntConnection.subscribe(_valueTopicName, super.period);
    _valueTopic = null;

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    ntConnection.unSubscribe(_valueSubscription);
    _valueTopic = null;
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: _valueSubscription.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(_valueTopicName),
      builder: (context, snapshot) {
        String selected = tryCast(snapshot.data) ?? 'Off';

        if (!_selectedOptions.contains(selected)) {
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
                    String option = _selectedOptions[index];

                    bool publishTopic = _valueTopic == null;

                    _valueTopic ??=
                        ntConnection.getTopicFromName(_valueTopicName);

                    if (_valueTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      ntConnection.nt4Client.publishTopic(_valueTopic!);
                    }

                    ntConnection.updateDataFromTopic(_valueTopic!, option);
                  },
                  isSelected:
                      _selectedOptions.map((e) => selected == e).toList(),
                  children: _selectedOptions.map((element) {
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
