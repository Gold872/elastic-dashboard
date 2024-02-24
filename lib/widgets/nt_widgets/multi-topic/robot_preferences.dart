import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RobotPreferences extends NTWidget {
  static const String widgetType = 'RobotPreferences';
  @override
  String type = widgetType;

  final TextEditingController _searchTextController = TextEditingController();

  final List<String> _preferenceTopicNames = [];
  final Map<String, NT4Topic> _preferenceTopics = {};
  final Map<String, TextEditingController> _preferenceTextControllers = {};
  final Map<String, Object?> _previousValues = {};

  _PreferenceSearch? _searchWidget;

  RobotPreferences({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  RobotPreferences.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        bool rebuildWidget = _searchWidget == null;

        for (NT4Topic nt4Topic
            in ntConnection.nt4Client.announcedTopics.values) {
          if (!nt4Topic.name.contains(topic) ||
              _preferenceTopicNames.contains(nt4Topic.name) ||
              nt4Topic.name.contains('.type')) {
            continue;
          }

          Object? previousValue =
              ntConnection.getLastAnnouncedValue(nt4Topic.name);

          _preferenceTopicNames.add(nt4Topic.name);
          _preferenceTopics.addAll({nt4Topic.name: nt4Topic});
          _preferenceTextControllers.addAll({
            nt4Topic.name: TextEditingController()
              ..text = previousValue?.toString() ?? ''
          });
          _previousValues.addAll({nt4Topic.name: previousValue});

          rebuildWidget = true;
        }

        Iterable<String> announcedTopics =
            ntConnection.nt4Client.announcedTopics.values.map(
          (e) => e.name,
        );

        for (String topic in _preferenceTopicNames) {
          if (!announcedTopics.contains(topic)) {
            _preferenceTopics.remove(topic);

            _preferenceTextControllers.remove(topic);

            _previousValues.remove(topic);

            rebuildWidget = true;

            continue;
          }

          if (ntConnection.getLastAnnouncedValue(topic).toString() !=
              _previousValues[topic].toString()) {
            _preferenceTextControllers[topic]?.text =
                ntConnection.getLastAnnouncedValue(topic).toString();

            _previousValues[topic] = ntConnection.getLastAnnouncedValue(topic);
          }
        }

        _preferenceTopicNames
            .removeWhere((element) => !announcedTopics.contains(element));

        if (rebuildWidget) {
          _searchWidget = _PreferenceSearch(
            onSubmit: (String topic, String? data) {
              if (data == null) {
                return;
              }

              NT4Topic? nt4Topic = _preferenceTopics[topic];

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
                _preferenceTextControllers[topic]?.text =
                    _previousValues[topic].toString();
                return;
              }

              ntConnection.nt4Client.publishTopic(nt4Topic);
              ntConnection.updateDataFromTopic(nt4Topic, formattedData);
              ntConnection.nt4Client.unpublishTopic(nt4Topic);

              _preferenceTextControllers[topic]?.text =
                  formattedData.toString();
            },
            searchTextController: _searchTextController,
            preferenceTopicNames: _preferenceTopicNames,
            preferenceTextControllers: _preferenceTextControllers,
            preferenceTopics: _preferenceTopics,
          );
        }

        return _searchWidget!;
      },
    );
  }
}

class _PreferenceSearch extends StatelessWidget {
  const _PreferenceSearch({
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
