import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RobotPreferencesModel extends MultiTopicNTWidgetModel {
  @override
  String type = RobotPreferences.widgetType;

  final TextEditingController searchTextController = TextEditingController();

  final List<String> preferenceTopicNames = [];
  final Map<String, NT4Subscription> preferenceSubscriptions = {};
  final Map<String, NT4Topic> preferenceTopics = {};
  final Map<String, TextEditingController> preferenceTextControllers = {};
  final Map<String, Object?> previousValues = {};

  @override
  List<NT4Subscription> get subscriptions =>
      preferenceSubscriptions.values.toList();

  late Function(NT4Topic topic) topicAnnounceListener;

  late Function(NT4Topic topic) topicUnannounceListener;

  PreferenceSearch? searchWidget;

  RobotPreferencesModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  RobotPreferencesModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void init() {
    topicAnnounceListener = (topic) {
      if (!topic.name.contains(this.topic) ||
          preferenceTopicNames.contains(topic.name) ||
          topic.name.contains('.type')) {
        return;
      }

      Object? previousValue = ntConnection.getLastAnnouncedValue(topic.name);

      preferenceTopicNames.add(topic.name);
      preferenceTopics.addAll({topic.name: topic});
      preferenceSubscriptions.addAll({
        topic.name: ntConnection.subscribe(topic.name, super.period),
      });
      preferenceTextControllers.addAll({
        topic.name: TextEditingController()
          ..text = previousValue?.toString() ?? ''
      });
      previousValues.addAll({topic.name: previousValue});

      notifyListeners();
    };

    topicUnannounceListener = (topic) {
      if (!preferenceTopicNames.contains(topic.name)) {
        return;
      }

      preferenceTopicNames.remove(topic.name);

      preferenceTopics.remove(topic.name);

      if (preferenceSubscriptions.containsKey(topic.name)) {
        ntConnection.unSubscribe(preferenceSubscriptions[topic.name]!);
      }
      preferenceSubscriptions.remove(topic.name);

      preferenceTextControllers.remove(topic.name);

      previousValues.remove(topic.name);

      notifyListeners();
    };

    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
    ntConnection.addTopicUnannounceListener(topicUnannounceListener);

    super.init();
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in preferenceSubscriptions.values) {
      ntConnection.unSubscribe(subscription);
    }
    preferenceSubscriptions.clear();

    // Trigger the topics to get recalled to the listener and added to the preferences list
    ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }
}

class RobotPreferences extends NTWidget {
  static const String widgetType = 'RobotPreferences';

  const RobotPreferences({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    RobotPreferencesModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
        listenable: Listenable.merge(model.subscriptions),
        builder: (context, child) {
          for (String topic in model.preferenceTopicNames) {
            if (model.preferenceSubscriptions[topic]?.value.toString() !=
                model.previousValues[topic].toString()) {
              model.preferenceTextControllers[topic]?.text =
                  model.preferenceSubscriptions[topic]?.value?.toString() ?? '';

              model.previousValues[topic] =
                  model.preferenceSubscriptions[topic]?.value;
            }
          }

          return PreferenceSearch(
            onSubmit: (String topic, String? data) {
              NT4Topic? nt4Topic = model.preferenceTopics[topic];

              if (nt4Topic == null ||
                  !model.ntConnection.isTopicPublished(nt4Topic)) {
                return;
              }

              if (data == null) {
                model.ntConnection.unpublishTopic(nt4Topic);
                return;
              }

              Object? formattedData;

              String dataType = nt4Topic.type;
              switch (dataType) {
                case NT4TypeStr.kBool:
                  formattedData = bool.tryParse(data);
                  break;
                case NT4TypeStr.kFloat32:
                case NT4TypeStr.kFloat64:
                  formattedData = double.tryParse(data);
                  break;
                case NT4TypeStr.kInt:
                  formattedData = int.tryParse(data);
                  break;
                case NT4TypeStr.kString:
                  formattedData = data;
                  break;
                default:
                  break;
              }

              if (formattedData == null) {
                model.preferenceTextControllers[topic]?.text =
                    model.previousValues[topic].toString();
                model.ntConnection.unpublishTopic(nt4Topic);
                return;
              }

              model.ntConnection.updateDataFromTopic(nt4Topic, formattedData);
              model.ntConnection.unpublishTopic(nt4Topic);

              model.preferenceTextControllers[topic]?.text =
                  formattedData.toString();
            },
            model: model,
          );
        });
  }
}

class PreferenceSearch extends StatelessWidget {
  const PreferenceSearch({
    super.key,
    required this.model,
    required this.onSubmit,
  });

  final RobotPreferencesModel model;
  final Function(String topic, String? data) onSubmit;

  @override
  Widget build(BuildContext context) {
    return SearchableList<String>(
      inputDecoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        label: const Text('Search'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      searchTextController: model.searchTextController,
      seperatorBuilder: (context, _) => const Divider(height: 4.0),
      spaceBetweenSearchAndList: 15,
      filter: (query) {
        return model.preferenceTopicNames
            .where((element) => element
                .split('/')
                .last
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      },
      initialList: model.preferenceTopicNames,
      itemBuilder: (item) {
        TextEditingController? textController =
            model.preferenceTextControllers[item];

        return _RobotPreference(
          label: item.split('/').last,
          textController: textController ?? TextEditingController(),
          onFocusGained: () {
            NT4Topic? nt4Topic = model.preferenceTopics[item];

            if (nt4Topic == null) {
              return;
            }

            model.ntConnection.publishTopic(nt4Topic);
          },
          onSubmit: (data) {
            onSubmit.call(item, data);
          },
        );
      },
    );
  }
}

class _RobotPreference extends StatelessWidget {
  final TextEditingController textController;
  final Function() onFocusGained;
  final Function(String? data) onSubmit;
  final String label;

  const _RobotPreference({
    required this.textController,
    required this.onFocusGained,
    required this.onSubmit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Focus(
        onFocusChange: (value) {
          // Don't consider the text submitted when focus is gained
          if (value) {
            onFocusGained.call();
            return;
          }
          String textValue = textController.text;
          if (textValue.isNotEmpty) {
            onSubmit.call(textValue);
          }
        },
        child: TextField(
          onSubmitted: (value) {
            onSubmit.call(value);
          },
          controller: textController,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
