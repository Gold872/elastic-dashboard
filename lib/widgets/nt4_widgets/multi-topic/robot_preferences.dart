import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:searchable_listview/searchable_listview.dart';

import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class RobotPreferences extends NT4Widget {
  static const String widgetType = 'RobotPreferences';
  @override
  String type = widgetType;

  TextEditingController searchTextController = TextEditingController();

  List<String> preferenceTopicNames = [];
  Map<String, NT4Topic> preferenceTopics = {};
  Map<String, TextEditingController> preferenceTextControllers = {};
  Map<String, Object?> previousValues = {};

  PreferenceSearch? searchWidget;

  RobotPreferences({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  RobotPreferences.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    if (topic == '') {
      topic = tryCast(jsonData['topic']) ?? '/Preferences';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        bool rebuildWidget = searchWidget == null;

        for (NT4Topic nt4Topic
            in nt4Connection.nt4Client.announcedTopics.values) {
          if (!nt4Topic.name.contains(topic) ||
              preferenceTopicNames.contains(nt4Topic.name) ||
              nt4Topic.name.contains('.type')) {
            continue;
          }

          Object? previousValue =
              nt4Connection.getLastAnnouncedValue(nt4Topic.name);

          preferenceTopicNames.add(nt4Topic.name);
          preferenceTopics.addAll({nt4Topic.name: nt4Topic});
          preferenceTextControllers.addAll({
            nt4Topic.name: TextEditingController()
              ..text = previousValue?.toString() ?? ''
          });
          previousValues.addAll({nt4Topic.name: previousValue});

          rebuildWidget = true;
        }

        Iterable<String> announcedTopics =
            nt4Connection.nt4Client.announcedTopics.values.map(
          (e) => e.name,
        );

        for (String topic in preferenceTopicNames) {
          if (!announcedTopics.contains(topic)) {
            preferenceTopics.remove(topic);

            preferenceTextControllers.remove(topic);

            previousValues.remove(topic);

            rebuildWidget = true;

            continue;
          }

          if (nt4Connection.getLastAnnouncedValue(topic).toString() !=
              previousValues[topic].toString()) {
            preferenceTextControllers[topic]?.text =
                nt4Connection.getLastAnnouncedValue(topic).toString();

            previousValues[topic] = nt4Connection.getLastAnnouncedValue(topic);
          }
        }

        preferenceTopicNames
            .removeWhere((element) => !announcedTopics.contains(element));

        if (rebuildWidget) {
          searchWidget = PreferenceSearch(
            onSubmit: (String topic, String? data) {
              if (data == null) {
                return;
              }

              NT4Topic? nt4Topic = preferenceTopics[topic];

              if (nt4Topic == null) {
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
                preferenceTextControllers[topic]?.text =
                    previousValues[topic].toString();
                return;
              }

              nt4Connection.nt4Client.publishTopic(nt4Topic);
              nt4Connection.updateDataFromTopic(nt4Topic, formattedData);
              nt4Connection.nt4Client.unpublishTopic(nt4Topic);

              preferenceTextControllers[topic]?.text = formattedData.toString();
            },
            searchTextController: searchTextController,
            preferenceTopicNames: preferenceTopicNames,
            preferenceTextControllers: preferenceTextControllers,
            preferenceTopics: preferenceTopics,
          );
        }

        return searchWidget!;
      },
    );
  }
}

class PreferenceSearch extends StatelessWidget {
  PreferenceSearch({
    super.key,
    required this.onSubmit,
    required this.searchTextController,
    required this.preferenceTopicNames,
    required this.preferenceTextControllers,
    required this.preferenceTopics,
  });

  final Function(String topic, String? data) onSubmit;
  final TextEditingController searchTextController;
  List<String> preferenceTopicNames;
  Map<String, TextEditingController> preferenceTextControllers;
  Map<String, NT4Topic> preferenceTopics;

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
      searchTextController: searchTextController,
      seperatorBuilder: (context, _) => const Divider(height: 4.0),
      spaceBetweenSearchAndList: 15,
      filter: (query) {
        return preferenceTopicNames
            .where((element) =>
                element.toLowerCase().contains(query.toLowerCase()))
            .toList();
      },
      initialList: preferenceTopicNames,
      builder: (displayedList, itemIndex, item) {
        TextEditingController? textController = preferenceTextControllers[item];

        return _RobotPreference(
          label: item.split('/').last,
          textController: textController ?? TextEditingController(),
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
  final Function(String? data) onSubmit;
  final String label;

  const _RobotPreference({
    required this.textController,
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
