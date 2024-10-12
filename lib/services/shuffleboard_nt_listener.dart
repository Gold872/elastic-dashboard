import 'package:dot_cast/dot_cast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree_row.dart';

class ShuffleboardNTListener {
  static const String shuffleboardTableRoot = '/Shuffleboard';
  static const String metadataTable = '$shuffleboardTableRoot/.metadata';
  static const String tabsEntry = '$metadataTable/Tabs';
  static const String selectedEntry = '$metadataTable/Selected';

  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final Function(Map<String, dynamic> widgetData)? onWidgetAdded;
  final Function(String tab)? onTabChanged;
  final Function(String tab)? onTabCreated;

  late NT4Subscription selectedSubscription;

  String? previousSelection;

  Map<String, Map<String, dynamic>> currentJsonData = {};

  late final NetworkTableTreeRow shuffleboardTreeRoot = NetworkTableTreeRow(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: '/',
      rowName: '');

  ShuffleboardNTListener({
    required this.ntConnection,
    required this.preferences,
    this.onTabChanged,
    this.onTabCreated,
    this.onWidgetAdded,
  });

  void initializeSubscriptions() {
    selectedSubscription = ntConnection.subscribe(selectedEntry);
  }

  void initializeListeners() {
    selectedSubscription.addListener(() {
      if (selectedSubscription.value is! String?) {
        return;
      }

      if (selectedSubscription.value != null) {
        _handleTabChange(selectedSubscription.value! as String);
      }

      previousSelection = selectedSubscription.value! as String;
    });

    // Also clear data when connected in case if threads auto populate json after disconnection
    // Chances are low since the timing has to be just right but you never know
    ntConnection.addConnectedListener(() {
      currentJsonData.clear();
      shuffleboardTreeRoot.clearRows();
      previousSelection = null;
    });

    ntConnection.addDisconnectedListener(() {
      currentJsonData.clear();
      shuffleboardTreeRoot.clearRows();
      previousSelection = null;
    });

    ntConnection.addTopicAnnounceListener((topic) async {
      if (!topic.name.contains(shuffleboardTableRoot)) {
        return;
      }

      String name = topic.name;

      createRows(topic);

      if (topic.name.contains(metadataTable)) {
        Future(() async => _metadataChanged(topic));
      }

      if (!name.contains(metadataTable) &&
          !name.contains('$shuffleboardTableRoot/.recording') &&
          !name.contains(RegExp(
              '${r'\'}$shuffleboardTableRoot${r'\/([^\/]+\/){1}\.type'}'))) {
        Future(() async => _topicAnnounced(topic));
      }

      if (!name.contains(metadataTable) &&
          !name.contains('$shuffleboardTableRoot/.recording') &&
          name.endsWith('/.type') &&
          name.substring(1).split('/').length == 3) {
        String tabName = name.substring(1).split('/')[1];
        onTabCreated?.call(tabName);
      }
    });
  }

  Future<void> _metadataChanged(NT4Topic topic) async {
    String name = topic.name;

    List<String> metaHierarchy = _getHierarchy(name);

    if (metaHierarchy.length < 5) {
      return;
    }

    List<String> realHierarchy = _getHierarchy(_realPath(name));

    // Properties
    if (name.contains('/Properties')) {
      String propertyTopic = metaHierarchy[metaHierarchy.length - 1];

      Object? subProperty =
          await ntConnection.subscribeAndRetrieveData(propertyTopic);

      String real = realHierarchy[realHierarchy.length - 1];
      List<String> realTopics = real.split('/');
      bool inLayout = real.split('/').length > 6;

      String tabName = (inLayout)
          ? realTopics[realTopics.length - 5]
          : realTopics[realTopics.length - 4];
      String componentName = (inLayout)
          ? realTopics[realTopics.length - 4]
          : realTopics[realTopics.length - 3];
      String widgetName =
          (inLayout) ? realTopics[realTopics.length - 3] : componentName;
      String propertyName = realTopics[realTopics.length - 1];
      String jsonKey = '$tabName/$componentName';

      if (inLayout) {
        currentJsonData[jsonKey]!['layout'] = true;

        currentJsonData[jsonKey]!
            .putIfAbsent('children', () => <Map<String, dynamic>>[]);

        Map<String, dynamic> child = _createOrGetChild(jsonKey, widgetName);

        child.putIfAbsent('properties', () => <String, dynamic>{});
        child['properties']!.putIfAbsent(propertyName, () => subProperty);
      } else {
        currentJsonData[jsonKey]!.putIfAbsent('layout', () => false);

        currentJsonData[jsonKey]!.putIfAbsent('title', () => widgetName);

        currentJsonData[jsonKey]!
            .putIfAbsent('properties', () => <String, dynamic>{});
        currentJsonData[jsonKey]!['properties']
            .putIfAbsent(propertyName, () => subProperty);
      }

      return;
    }

    String real = realHierarchy[realHierarchy.length - 2];
    List<String> realTopics = real.split('/');
    bool inLayout = real.split('/').length > 4;

    String tabName = (inLayout)
        ? realTopics[realTopics.length - 3]
        : realTopics[realTopics.length - 2];
    String componentName = (inLayout)
        ? realTopics[realTopics.length - 2]
        : realTopics[realTopics.length - 1];
    String widgetName =
        (inLayout) ? realTopics[realTopics.length - 1] : componentName;
    String jsonKey = '$tabName/$componentName';

    currentJsonData.putIfAbsent(jsonKey, () => <String, dynamic>{});

    if (inLayout) {
      currentJsonData[jsonKey]!['layout'] = true;

      currentJsonData[jsonKey]!
          .putIfAbsent('children', () => <Map<String, dynamic>>[]);

      _createOrGetChild(jsonKey, widgetName);
    } else {
      currentJsonData[jsonKey]!.putIfAbsent('layout', () => false);

      currentJsonData[jsonKey]!.putIfAbsent('title', () => widgetName);
    }

    // Type
    if (name.endsWith('/PreferredComponent')) {
      String componentTopic = metaHierarchy[metaHierarchy.length - 1];

      String? type =
          await ntConnection.subscribeAndRetrieveData(componentTopic);

      if (inLayout) {
        Map<String, dynamic> child = _createOrGetChild(jsonKey, widgetName);

        child.putIfAbsent('type', () => type);
      } else {
        currentJsonData[jsonKey]!.putIfAbsent('type', () => type);
      }
    }

    // Size
    if (name.endsWith('/Size')) {
      String sizeTopic = metaHierarchy[metaHierarchy.length - 1];

      List<Object?> sizeRaw =
          await ntConnection.subscribeAndRetrieveData(sizeTopic) ?? [];
      List<double> size = sizeRaw.whereType<double>().toList();

      if (size.length < 2) {
        return;
      }

      if (inLayout) {
        Map<String, dynamic> child = _createOrGetChild(jsonKey, widgetName);

        child.putIfAbsent(
            'width',
            () =>
                size[0] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
        child.putIfAbsent(
            'height',
            () =>
                size[1] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
      } else {
        currentJsonData[jsonKey]!.putIfAbsent(
            'width',
            () =>
                size[0] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
        currentJsonData[jsonKey]!.putIfAbsent(
            'height',
            () =>
                size[1] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
      }
    }

    // Position
    if (name.endsWith('/Position')) {
      String positionTopic = metaHierarchy[metaHierarchy.length - 1];

      List<Object?> positionRaw =
          await ntConnection.subscribeAndRetrieveData(positionTopic) ?? [];
      List<double> position = positionRaw.whereType<double>().toList();

      if (position.length < 2) {
        return;
      }

      if (inLayout) {
        Map<String, dynamic> child = _createOrGetChild(jsonKey, widgetName);

        child.putIfAbsent(
            'x',
            () =>
                position[0] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
        child.putIfAbsent(
            'y',
            () =>
                position[1] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
      } else {
        currentJsonData[jsonKey]!.putIfAbsent(
            'x',
            () =>
                position[0] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
        currentJsonData[jsonKey]!.putIfAbsent(
            'y',
            () =>
                position[1] *
                (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize));
      }
    }
  }

  Map<String, dynamic> _createOrGetChild(String jsonKey, String title) {
    List<Map<String, dynamic>> children = currentJsonData[jsonKey]!['children'];

    return children.firstWhere(
      (element) => element.containsKey('title') && element['title'] == title,
      orElse: () {
        final newMap = <String, dynamic>{'title': title};
        children.add(newMap);

        return newMap;
      },
    );
  }

  Future<void> _topicAnnounced(NT4Topic topic) async {
    String name = topic.name;

    List<String> hierarchy = _getHierarchy(name);
    List<String> tables = name.substring(1).split('/');

    if (hierarchy.length < 3) {
      return;
    }

    String tabName = tables[1];
    String componentName = tables[2];

    String jsonKey = '$tabName/$componentName';
    currentJsonData.putIfAbsent(jsonKey, () => {});

    if (!shuffleboardTreeRoot.hasRow(shuffleboardTableRoot.substring(1))) {
      return;
    }
    NetworkTableTreeRow shuffleboardRootRow =
        shuffleboardTreeRoot.getRow(shuffleboardTableRoot.substring(1));

    if (!shuffleboardRootRow.hasRow(tabName)) {
      return;
    }
    NetworkTableTreeRow tabRow = shuffleboardRootRow.getRow(tabName);

    if (!tabRow.hasRow(componentName)) {
      return;
    }
    NetworkTableTreeRow widgetRow = tabRow.getRow(componentName);

    bool isCameraStream = topic.name.endsWith('/.ShuffleboardURI');

    if (widgetRow.hasRow('.type')) {
      String typeTopic = widgetRow.getRow('.type').topic;

      String? type = await ntConnection.subscribeAndRetrieveData(typeTopic,
          timeout: const Duration(seconds: 3));

      if (type == 'ShuffleboardLayout') {
        currentJsonData[jsonKey]!['layout'] = true;
      }
    }

    // Prevents multi-topic widgets from being published twice
    // If there's a topic like .controllable that gets published before the
    // type topic, don't delay everything else from being processed
    if (widgetRow.children.isNotEmpty &&
        !name.endsWith('/.type') &&
        !isCameraStream) {
      return;
    }

    bool isLayout = tryCast(currentJsonData[jsonKey]!['layout']) ?? false;

    if (isLayout) {
      handleLayoutTopicAnnounce(topic, widgetRow);
      return;
    }

    WidgetContainerModel? widget;
    NTWidgetContainerModel? ntWidget;

    if (!isCameraStream) {
      widget =
          await widgetRow.toWidgetContainerModel(resortToListLayout: false);
      ntWidget = tryCast(widget);

      if (widget == null || ntWidget == null) {
        widget?.unSubscribe();
        widget?.disposeModel(deleting: true);
        widget?.forceDispose();
        return;
      }
    }

    if (isCameraStream) {
      String? cameraStream =
          await ntConnection.subscribeAndRetrieveData(topic.name);

      if (cameraStream == null) {
        return;
      }

      String cameraName = cameraStream.substring(16);

      currentJsonData[jsonKey]!
          .putIfAbsent('properties', () => <String, dynamic>{});
      currentJsonData[jsonKey]!['properties']['topic'] =
          '/CameraPublisher/$cameraName';
    }

    await Future.delayed(const Duration(seconds: 2, milliseconds: 750), () {
      currentJsonData.putIfAbsent(jsonKey, () => {});

      String type =
          (!isCameraStream) ? ntWidget!.childModel.type : 'Camera Stream';

      currentJsonData[jsonKey]!.putIfAbsent('title', () => componentName);
      currentJsonData[jsonKey]!.putIfAbsent('x', () => 0.0);
      currentJsonData[jsonKey]!.putIfAbsent('y', () => 0.0);
      currentJsonData[jsonKey]!.putIfAbsent(
          'width',
          () => (!isCameraStream)
              ? widget!.displayRect.width
              : (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) *
                  2);
      currentJsonData[jsonKey]!.putIfAbsent(
          'height',
          () => (!isCameraStream)
              ? widget!.displayRect.height
              : (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) *
                  2);
      currentJsonData[jsonKey]!.putIfAbsent('tab', () => tabName);
      currentJsonData[jsonKey]!.putIfAbsent('type', () => type);
      currentJsonData[jsonKey]!
          .putIfAbsent('properties', () => <String, dynamic>{});
      currentJsonData[jsonKey]!['properties']
          .putIfAbsent('topic', () => widgetRow.topic);
      currentJsonData[jsonKey]!['properties'].putIfAbsent(
          'period',
          () => (type != 'Graph')
              ? preferences.getDouble(PrefKeys.defaultPeriod) ??
                  Defaults.defaultPeriod
              : preferences.getDouble(PrefKeys.defaultGraphPeriod) ??
                  Defaults.defaultGraphPeriod);

      if (ntConnection.isNT4Connected) {
        onWidgetAdded?.call(currentJsonData[jsonKey]!);
      }

      ntWidget?.unSubscribe();
      ntWidget?.disposeModel(deleting: true);
      ntWidget?.forceDispose();
    });
  }

  Future<void> handleLayoutTopicAnnounce(
      NT4Topic topic, NetworkTableTreeRow widgetRow) async {
    String name = topic.name;

    List<String> tables = name.substring(1).split('/');

    String tabName = tables[1];
    String componentName = tables[2];

    String jsonKey = '$tabName/$componentName';

    await Future.delayed(const Duration(seconds: 2, milliseconds: 750),
        () async {
      currentJsonData.putIfAbsent(jsonKey, () => {});

      currentJsonData[jsonKey]!.putIfAbsent('title', () => componentName);
      currentJsonData[jsonKey]!.putIfAbsent('x', () => 0.0);
      currentJsonData[jsonKey]!.putIfAbsent('y', () => 0.0);
      currentJsonData[jsonKey]!.putIfAbsent(
          'width',
          () => (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize)
              .toDouble());
      currentJsonData[jsonKey]!.putIfAbsent(
          'height',
          () => (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize)
              .toDouble());
      currentJsonData[jsonKey]!.putIfAbsent('type', () => 'List Layout');
      currentJsonData[jsonKey]!.putIfAbsent('tab', () => tabName);
      currentJsonData[jsonKey]!
          .putIfAbsent('children', () => <Map<String, dynamic>>[]);

      Iterable<String> childrenNames = widgetRow.children
          .where((element) => !element.rowName.startsWith('.'))
          .map((e) => e.rowName);

      for (String childName in childrenNames) {
        _createOrGetChild(jsonKey, childName);
      }

      for (Map<String, dynamic> child
          in currentJsonData[jsonKey]!['children']) {
        child.putIfAbsent('properties', () => <String, dynamic>{});

        if (!widgetRow.hasRow(child['title'])) {
          continue;
        }
        NetworkTableTreeRow childRow = widgetRow.getRow(child['title']);

        WidgetContainerModel? widget =
            await childRow.toWidgetContainerModel(resortToListLayout: false);
        NTWidgetContainerModel? ntWidget = tryCast(widget);

        bool isCameraStream = childRow.hasRow('.ShuffleboardURI');

        if (!isCameraStream && (ntWidget == null || widget == null)) {
          widget?.unSubscribe();
          widget?.disposeModel(deleting: true);
          widget?.forceDispose();
          continue;
        }

        if (isCameraStream) {
          String? cameraStream = await ntConnection.subscribeAndRetrieveData(
              childRow.getRow('.ShuffleboardURI').topic);

          if (cameraStream == null) {
            continue;
          }

          String cameraName = cameraStream.substring(16);

          child['properties']['topic'] = '/CameraPublisher/$cameraName';
        }

        String type =
            (!isCameraStream) ? ntWidget!.childModel.type : 'Camera Stream';

        child.putIfAbsent('type', () => type);
        child.putIfAbsent('x', () => 0.0);
        child.putIfAbsent('y', () => 0.0);
        child.putIfAbsent(
            'width',
            () => (!isCameraStream)
                ? widget!.displayRect.width
                : (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) *
                    2);
        child.putIfAbsent(
            'height',
            () => (!isCameraStream)
                ? widget!.displayRect.height
                : (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize) *
                    2);

        child['properties']!.putIfAbsent('topic', () => childRow.topic);
        child['properties']!.putIfAbsent(
            'period',
            () => (type != 'Graph')
                ? preferences.getDouble(PrefKeys.defaultPeriod) ??
                    Defaults.defaultPeriod
                : preferences.getDouble(PrefKeys.defaultGraphPeriod) ??
                    Defaults.defaultGraphPeriod);

        widget?.unSubscribe();
        widget?.disposeModel(deleting: true);
        widget?.forceDispose();
      }
      if (ntConnection.isNT4Connected) {
        onWidgetAdded?.call(currentJsonData[jsonKey]!);
      }
    });
  }

  void _handleTabChange(String newTab) {
    onTabChanged?.call(newTab);
  }

  String _realPath(String path) {
    return path.replaceFirst('/Shuffleboard/.metadata/', '/Shuffleboard/');
  }

  List<String> _getHierarchy(String path) {
    final String normal = path;
    List<String> hierarchy = [];
    if (normal.length == 1) {
      hierarchy.add(normal);
      return hierarchy;
    }

    for (int i = 1;; i = normal.indexOf('/', i + 1)) {
      if (i == -1) {
        hierarchy.add(normal);
        break;
      } else {
        hierarchy.add(normal.substring(0, i));
      }
    }
    return hierarchy;
  }

  void createRows(NT4Topic nt4Topic) {
    String topic = nt4Topic.name;

    List<String> rows = topic.substring(1).split('/');
    NetworkTableTreeRow? current;
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
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      } else {
        if (shuffleboardTreeRoot.hasRow(row)) {
          current = shuffleboardTreeRoot.getRow(row);
        } else {
          current = shuffleboardTreeRoot.createNewRow(
              topic: currentTopic,
              name: row,
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      }
    }
  }
}
