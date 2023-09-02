import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/network_tree/tree_row.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class ShuffleboardNTListener {
  static const String shuffleboardTableRoot = '/Shuffleboard';
  static const String metadataTable = '$shuffleboardTableRoot/.metadata';
  static const String tabsEntry = '$metadataTable/Tabs';
  static const String selectedEntry = '$metadataTable/Selected';

  final Function(Map<String, dynamic> widgetData)? onWidgetAdded;
  final Function(String tab)? onTabChanged;

  late NT4Subscription selectedSubscription;

  String? previousSelection;

  Map<String, Map<String, dynamic>> currentJsonData = {};

  final TreeRow shuffleboardTreeRoot = TreeRow(topic: '/', rowName: '');

  ShuffleboardNTListener({this.onTabChanged, this.onWidgetAdded});

  void initializeSubscriptions() {
    selectedSubscription = nt4Connection.subscribe(selectedEntry);
  }

  void initializeListeners() {
    selectedSubscription.periodicStream().listen((data) {
      if (data is! String?) {
        return;
      }

      if (data != previousSelection && data != null) {
        _handleTabChange(data);
      }

      previousSelection = data;
    });

    nt4Connection.nt4Client.addTopicAnnounceListener((topic) async {
      if (!topic.name.contains(shuffleboardTableRoot)) {
        return;
      }

      createRows(topic);

      if (topic.name.contains(metadataTable)) {
        Future(() async => _handleMetadata(topic));
      }

      if (!topic.name.contains(metadataTable) &&
          !topic.name.contains('$shuffleboardTableRoot/.recording') &&
          !topic.name.contains(RegExp(
              '${r'\'}$shuffleboardTableRoot${r'\/([^\/]+\/){1}\.type'}'))) {
        Future(() async => _handleWidgetTopicAnnounced(topic));
      }
    });
  }

  Future<void> _handleMetadata(NT4Topic topic) async {
    List<String> tables = topic.name.substring(1).split('/');

    if (tables.length < 5) {
      return;
    }

    String tabName = tables[2];
    String widgetName = tables[3];
    String property = tables[4];

    String jsonTopic = '$tabName/$widgetName';

    currentJsonData.putIfAbsent(jsonTopic, () => {});

    switch (property) {
      case 'Size':
        List<Object?> rawSize =
            await nt4Connection.subscribeAndRetrieveData(topic.name) ?? [];

        List<double> size = rawSize.whereType<double>().toList();

        if (size.length != 2) {
          break;
        }

        currentJsonData[jsonTopic]!['width'] =
            size[0] * Globals.gridSize.toDouble();
        currentJsonData[jsonTopic]!['height'] =
            size[1] * Globals.gridSize.toDouble();
        break;
      case 'Position':
        List<Object?> rawPosition =
            await nt4Connection.subscribeAndRetrieveData(topic.name) ?? [];

        List<double> position = rawPosition.whereType<double>().toList();

        if (position.length != 2) {
          break;
        }

        currentJsonData[jsonTopic]!['x'] = position[0] * Globals.gridSize;
        currentJsonData[jsonTopic]!['y'] = position[1] * Globals.gridSize;
        break;
      case 'PreferredComponent':
        String? component =
            await nt4Connection.subscribeAndRetrieveData(topic.name);

        if (component == null) {
          break;
        }

        currentJsonData[jsonTopic]!['type'] = component;
        break;
    }
  }

  void _handleWidgetTopicAnnounced(NT4Topic topic) async {
    List<String> tables = topic.name.substring(1).split('/');

    if (tables.length < 3) {
      return;
    }

    String tabName = tables[1];
    String widgetName = tables[2];

    if (!shuffleboardTreeRoot.hasRow(shuffleboardTableRoot.substring(1))) {
      return;
    }
    TreeRow shuffleboardRootRow =
        shuffleboardTreeRoot.getRow(shuffleboardTableRoot.substring(1));

    if (!shuffleboardRootRow.hasRow(tabName)) {
      return;
    }
    TreeRow tabRow = shuffleboardRootRow.getRow(tabName);

    if (!tabRow.hasRow(widgetName)) {
      return;
    }
    TreeRow widgetRow = tabRow.getRow(widgetName);

    bool isCameraStream = topic.name.endsWith('/.ShuffleboardURI');

    // If there's a topic like .controllable that gets published before the
    // type topic, don't delay everything else from being processed
    if (widgetRow.children.isNotEmpty &&
        !topic.name.endsWith('/.type') &&
        !isCameraStream) {
      return;
    }

    NT4Widget? widget;

    if (!isCameraStream) {
      widget = await widgetRow.getPrimaryWidget();

      if (widget == null) {
        return;
      }
    }

    String jsonTopic = '$tabName/$widgetName';

    if (isCameraStream) {
      String? cameraStream =
          await nt4Connection.subscribeAndRetrieveData(topic.name);

      if (cameraStream == null) {
        return;
      }

      String cameraName = cameraStream.substring(16);

      currentJsonData.putIfAbsent(jsonTopic, () => {});
      currentJsonData[jsonTopic]!
          .putIfAbsent('properties', () => <String, dynamic>{});
      currentJsonData[jsonTopic]!['properties']['topic'] =
          '/CameraPublisher/$cameraName';
    }

    await Future.delayed(const Duration(seconds: 2, milliseconds: 750), () {
      currentJsonData.putIfAbsent(jsonTopic, () => {});

      currentJsonData[jsonTopic]!.putIfAbsent('title', () => widgetName);
      currentJsonData[jsonTopic]!.putIfAbsent('x', () => 0.0);
      currentJsonData[jsonTopic]!.putIfAbsent('y', () => 0.0);
      currentJsonData[jsonTopic]!
          .putIfAbsent('width', () => Globals.gridSize.toDouble());
      currentJsonData[jsonTopic]!
          .putIfAbsent('height', () => Globals.gridSize.toDouble());
      currentJsonData[jsonTopic]!.putIfAbsent('tab', () => tabName);
      currentJsonData[jsonTopic]!.putIfAbsent(
          'type', () => (!isCameraStream) ? widget!.type : 'Camera Stream');
      currentJsonData[jsonTopic]!
          .putIfAbsent('properties', () => <String, dynamic>{});
      currentJsonData[jsonTopic]!['properties'].putIfAbsent(
          'topic', () => '$shuffleboardTableRoot/$tabName/$widgetName');
      currentJsonData[jsonTopic]!['properties']
          .putIfAbsent('period', () => Globals.defaultPeriod);

      onWidgetAdded?.call(currentJsonData[jsonTopic]!);

      widget?.unSubscribe();
      widget?.dispose();

      // currentJsonData[jsonTopic]!.clear();
    });
  }

  void _handleTabChange(String newTab) {
    onTabChanged?.call(newTab);
  }

  void createRows(NT4Topic nt4Topic) {
    String topic = nt4Topic.name;

    List<String> rows = topic.substring(1).split('/');
    TreeRow? current;
    String currentTopic = '';

    for (String row in rows) {
      currentTopic += '/$row';

      bool lastElement = currentTopic == topic;

      if (current != null) {
        if (current.hasRow(row)) {
          current = current.getRow(row);
        } else {
          current = current.createNewRow(
              topic: currentTopic,
              name: row,
              nt4Topic: (lastElement) ? nt4Topic : null);
        }
      } else {
        if (shuffleboardTreeRoot.hasRow(row)) {
          current = shuffleboardTreeRoot.getRow(row);
        } else {
          current = shuffleboardTreeRoot.createNewRow(
              topic: currentTopic,
              name: row,
              nt4Topic: (lastElement) ? nt4Topic : null);
        }
      }
    }
  }
}
