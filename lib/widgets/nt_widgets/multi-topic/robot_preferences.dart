import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RobotPreferencesModel extends NTWidgetModel {
  @override
  String type = RobotPreferences.widgetType;

  final TextEditingController searchTextController = TextEditingController();

  final List<String> preferenceTopicNames = [];
  final Map<String, NT4Topic> preferenceTopics = {};
  final Map<String, TextEditingController> preferenceTextControllers = {};
  final Map<String, Object?> previousValues = {};

  PreferenceSearch? searchWidget;

  RobotPreferencesModel({required super.topic, super.dataType, super.period})
      : super();

  RobotPreferencesModel.fromJson({required super.jsonData}) : super.fromJson();
}

class RobotPreferences extends NTWidget {
  static const String widgetType = 'RobotPreferences';

  const RobotPreferences({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    RobotPreferencesModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.subscription?.periodicStream(),
      builder: (context, snapshot) {
        bool rebuildWidget = model.searchWidget == null;

        for (NT4Topic nt4Topic
            in ntConnection.nt4Client.announcedTopics.values) {
          if (!nt4Topic.name.contains(model.topic) ||
              model.preferenceTopicNames.contains(nt4Topic.name) ||
              nt4Topic.name.contains('.type')) {
            continue;
          }

          Object? previousValue =
              ntConnection.getLastAnnouncedValue(nt4Topic.name);

          model.preferenceTopicNames.add(nt4Topic.name);
          model.preferenceTopics.addAll({nt4Topic.name: nt4Topic});
          model.preferenceTextControllers.addAll({
            nt4Topic.name: TextEditingController()
              ..text = previousValue?.toString() ?? ''
          });
          model.previousValues.addAll({nt4Topic.name: previousValue});

          rebuildWidget = true;
        }

        Iterable<String> announcedTopics =
            ntConnection.nt4Client.announcedTopics.values.map(
          (e) => e.name,
        );

        for (String topic in model.preferenceTopicNames) {
          if (!announcedTopics.contains(topic)) {
            model.preferenceTopics.remove(topic);

            model.preferenceTextControllers.remove(topic);

            model.previousValues.remove(topic);

            rebuildWidget = true;

            continue;
          }

          if (ntConnection.getLastAnnouncedValue(topic).toString() !=
              model.previousValues[topic].toString()) {
            model.preferenceTextControllers[topic]?.text =
                ntConnection.getLastAnnouncedValue(topic).toString();

            model.previousValues[topic] =
                ntConnection.getLastAnnouncedValue(topic);
          }
        }

        model.preferenceTopicNames
            .removeWhere((element) => !announcedTopics.contains(element));

        if (rebuildWidget) {
          model.searchWidget = PreferenceSearch(
            onSubmit: (String topic, String? data) {
              if (data == null) {
                return;
              }

              NT4Topic? nt4Topic = model.preferenceTopics[topic];

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
                model.preferenceTextControllers[topic]?.text =
                    model.previousValues[topic].toString();
                return;
              }

              ntConnection.nt4Client.publishTopic(nt4Topic);
              ntConnection.updateDataFromTopic(nt4Topic, formattedData);
              ntConnection.nt4Client.unpublishTopic(nt4Topic);

              model.preferenceTextControllers[topic]?.text =
                  formattedData.toString();
            },
            searchTextController: model.searchTextController,
            preferenceTopicNames: model.preferenceTopicNames,
            preferenceTextControllers: model.preferenceTextControllers,
            preferenceTopics: model.preferenceTopics,
          );
        }

        return model.searchWidget!;
      },
    );
  }
}

class PreferenceSearch extends StatelessWidget {
  const PreferenceSearch({
    super.key,
    required this.onSubmit,
    required this.searchTextController,
    required this.preferenceTopicNames,
    required this.preferenceTextControllers,
    required this.preferenceTopics,
  });

  final Function(String topic, String? data) onSubmit;
  final TextEditingController searchTextController;
  final List<String> preferenceTopicNames;
  final Map<String, TextEditingController> preferenceTextControllers;
  final Map<String, NT4Topic> preferenceTopics;

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
