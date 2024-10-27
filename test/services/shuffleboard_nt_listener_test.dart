import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/shuffleboard_nt_listener.dart';
import '../test_util.dart';
import '../test_util.mocks.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('Shuffleboard NT listener', () async {
    List<Function(NT4Topic topic)> topicAnnounceListeners = [];
    Map<String, dynamic> lastAnnouncedValues = {
      '/Shuffleboard/.metadata/Test-Tab/Test Number/Position': [1.0, 1.0],
      '/Shuffleboard/.metadata/Test-Tab/Test Number/Size': [2.0, 2.0],
    };

    final mockNT4Connection = MockNTConnection();
    final mockSubscription = MockNT4Subscription();

    when(mockNT4Connection.addTopicAnnounceListener(any)).thenAnswer(
        (realInvocation) =>
            topicAnnounceListeners.add(realInvocation.positionalArguments[0]));

    when(mockSubscription.periodicStream())
        .thenAnswer((_) => Stream.value(null));

    when(mockNT4Connection.isNT4Connected).thenReturn(true);
    when(mockNT4Connection.ntConnected).thenReturn(ValueNotifier(true));

    when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

    when(mockNT4Connection.getLastAnnouncedValue(any)).thenAnswer(
      (realInvocation) =>
          lastAnnouncedValues[realInvocation.positionalArguments[0]],
    );

    when(mockNT4Connection.subscribeAndRetrieveData<List<Object?>>(any))
        .thenAnswer((realInvocation) => Future.value(
            lastAnnouncedValues[realInvocation.positionalArguments[0]]));

    when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

    when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

    Map<String, dynamic> announcedWidgetData = {};

    ShuffleboardNTListener ntListener = ShuffleboardNTListener(
      ntConnection: mockNT4Connection,
      preferences: preferences,
      onWidgetAdded: (widgetData) {
        widgetData.forEach(
            (key, value) => announcedWidgetData.putIfAbsent(key, () => value));
      },
    )
      ..initializeSubscriptions()
      ..initializeListeners();

    expect(topicAnnounceListeners.isNotEmpty, true);

    for (final callback in topicAnnounceListeners) {
      callback.call(NT4Topic(
        name: '/Shuffleboard/.metadata/Test-Tab/Test Number/Position',
        type: NT4TypeStr.kFloat32Arr,
        properties: {},
      ));
      callback.call(NT4Topic(
        name: '/Shuffleboard/.metadata/Test-Tab/Test Number/Size',
        type: NT4TypeStr.kFloat32Arr,
        properties: {},
      ));
      callback.call(NT4Topic(
        name: '/Shuffleboard/Test-Tab/Test Number',
        type: NT4TypeStr.kInt,
        properties: {},
      ));
    }

    await Future(() async {});

    expect(
        ntListener.currentJsonData.containsKey('Test-Tab/Test Number'), true);

    await Future.delayed(const Duration(seconds: 3));

    expect(announcedWidgetData.containsKey('x'), true);
    expect(announcedWidgetData.containsKey('y'), true);
    expect(announcedWidgetData.containsKey('width'), true);
    expect(announcedWidgetData.containsKey('height'), true);

    expect(announcedWidgetData['x'], Defaults.gridSize.toDouble());
    expect(announcedWidgetData['y'], Defaults.gridSize.toDouble());
    expect(announcedWidgetData['width'], Defaults.gridSize.toDouble() * 2.0);
    expect(announcedWidgetData['height'], Defaults.gridSize.toDouble() * 2.0);
  });

  test('Tab selection change', () {
    final ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: '/Shuffleboard/.metadata/Selected',
          type: NT4TypeStr.kString,
          properties: {},
        ),
      ],
    );

    String? selectedTab;

    ShuffleboardNTListener(
      ntConnection: ntConnection,
      preferences: preferences,
      onTabChanged: (tab) {
        selectedTab = tab;
      },
    )
      ..initializeSubscriptions()
      ..initializeListeners();

    ntConnection.updateDataFromTopicName(
        '/Shuffleboard/.metadata/Selected', 'Test Tab Selection');

    expect(selectedTab, 'Test Tab Selection');
  });
}
