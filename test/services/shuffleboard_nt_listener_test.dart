import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/services/shuffleboard_nt_listener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shuffleboard NT listener', () async {
    nt4Connection.nt4Connect('0.0.0.0');

    Map<String, dynamic> announcedWidgetData = {};

    ShuffleboardNTListener ntListener = ShuffleboardNTListener(
      onWidgetAdded: (widgetData) {
        widgetData.forEach(
            (key, value) => announcedWidgetData.putIfAbsent(key, () => value));
      },
    )
      ..initializeSubscriptions()
      ..initializeListeners();

    expect(nt4Connection.nt4Client.topicAnnounceListeners.isNotEmpty, true);

    nt4Connection.nt4Client.lastAnnouncedValues.addAll({
      '/Shuffleboard/.metadata/Test-Tab/Test Number/Position': [1.0, 1.0],
      '/Shuffleboard/.metadata/Test-Tab/Test Number/Size': [2.0, 2.0],
    });

    for (final callback in nt4Connection.nt4Client.topicAnnounceListeners) {
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
