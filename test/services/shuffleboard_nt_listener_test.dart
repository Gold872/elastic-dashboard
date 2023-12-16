import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/shuffleboard_nt_listener.dart';
import '../test_util.mocks.dart';

void main() {
  test('Shuffleboard NT listener', () async {
    List<Function(NT4Topic topic)> topicAnnounceListeners = [];
    Map<String, dynamic> lastAnnouncedValues = {
      '/Shuffleboard/.metadata/Test-Tab/Test Number/Position': [1.0, 1.0],
      '/Shuffleboard/.metadata/Test-Tab/Test Number/Size': [2.0, 2.0],
    };

    final mockNT4Connection = MockNTConnection();
    final mockNT4Client = MockNT4Client();
    final mockSubscription = MockNT4Subscription();

    when(mockNT4Client.lastAnnouncedValues).thenReturn(lastAnnouncedValues);
    when(mockNT4Client.topicAnnounceListeners)
        .thenReturn(topicAnnounceListeners);
    when(mockNT4Client.addTopicAnnounceListener(any)).thenAnswer(
        (realInvocation) =>
            topicAnnounceListeners.add(realInvocation.positionalArguments[0]));

    when(mockSubscription.periodicStream())
        .thenAnswer((_) => Stream.value(null));

    when(mockNT4Connection.nt4Client).thenReturn(mockNT4Client);

    when(mockNT4Connection.isNT4Connected).thenReturn(true);

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

    NTConnection.instance = mockNT4Connection;

    Map<String, dynamic> announcedWidgetData = {};

    ShuffleboardNTListener ntListener = ShuffleboardNTListener(
      onWidgetAdded: (widgetData) {
        widgetData.forEach(
            (key, value) => announcedWidgetData.putIfAbsent(key, () => value));
      },
    )
      ..initializeSubscriptions()
      ..initializeListeners();

    expect(ntConnection.nt4Client.topicAnnounceListeners.isNotEmpty, true);

    for (final callback in ntConnection.nt4Client.topicAnnounceListeners) {
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

    expect(announcedWidgetData['x'], Settings.gridSize.toDouble());
    expect(announcedWidgetData['y'], Settings.gridSize.toDouble());
    expect(announcedWidgetData['width'], Settings.gridSize.toDouble() * 2.0);
    expect(announcedWidgetData['height'], Settings.gridSize.toDouble() * 2.0);
  });
}
