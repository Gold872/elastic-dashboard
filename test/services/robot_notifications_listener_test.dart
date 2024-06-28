import 'dart:convert';

import 'package:elastic_dashboard/services/robot_notifications_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_util.dart';
import '../test_util.mocks.dart';

class MockNotificationCallback extends Mock {
  void call(String? title, String? description, Icon? icon);
}

void main() {
  test("Robot Notifications (Initial Connection | No Existing Data) ", () {
    MockNTConnection mockConnection = createMockOnlineNT4();
    MockNT4Subscription mockSub = MockNT4Subscription();

    List<Function(Object?, int)> listeners = [];
    when(mockSub.listen(any)).thenAnswer(
      (realInvocation) {
        listeners.add(realInvocation.positionalArguments[0]);
      },
    );

    when(mockSub.updateValue(any, any)).thenAnswer(
      (invoc) {
        for (var value in listeners) {
          value.call(
              invoc.positionalArguments[0], invoc.positionalArguments[1]);
        }
      },
    );

    when(mockConnection.subscribeAll(any, any)).thenAnswer(
      (realInvocation) {
        return mockSub;
      },
    );

    // Create a mock for the onNotification callback
    MockNotificationCallback mockOnNotification = MockNotificationCallback();

    RobotNotificationsListener notifications = RobotNotificationsListener(
      ntConnection: mockConnection,
      onNotification: mockOnNotification.call,
    );

    notifications.listen();

    // Verify that subscribeAll was called with the specific parameters
    verify(mockConnection.subscribeAll('/Elastic/robotnotifications', 0.2))
        .called(1);
    verify(mockConnection.addDisconnectedListener(any)).called(1);

    // Verify that no other interactions have been made with the mockConnection
    verifyNoMoreInteractions(mockConnection);

    // Verify that the onNotification callback was never called
    verifyNever(mockOnNotification.call(any, any, any));
  });

  test("Robot Notifications (Initial Connection | Existing Data) ", () {
    MockNTConnection mockConnection = createMockOnlineNT4();
    MockNT4Subscription mockSub = MockNT4Subscription();

    Map<String, dynamic> data = {
      'title': 'Title1',
      'description': 'Description1',
      'level': 'Info'
    };

    List<Function(Object?, int)> listeners = [];
    when(mockSub.listen(any)).thenAnswer(
      (realInvocation) {
        listeners.add(realInvocation.positionalArguments[0]);
        mockSub.updateValue(jsonEncode(data), 0);
      },
    );

    when(mockSub.updateValue(any, any)).thenAnswer(
      (invoc) {
        for (var value in listeners) {
          value.call(
              invoc.positionalArguments[0], invoc.positionalArguments[1]);
        }
      },
    );

    when(mockConnection.subscribeAll(any, any)).thenAnswer(
      (realInvocation) {
        mockSub.updateValue(jsonEncode(data), 0);
        return mockSub;
      },
    );

    // Create a mock for the onNotification callback
    MockNotificationCallback mockOnNotification = MockNotificationCallback();

    RobotNotificationsListener notifications = RobotNotificationsListener(
      ntConnection: mockConnection,
      onNotification: mockOnNotification.call,
    );

    notifications.listen();

    // Verify that subscribeAll was called with the specific parameters
    verify(mockConnection.subscribeAll('/Elastic/robotnotifications', 0.2))
        .called(1);
    verify(mockConnection.addDisconnectedListener(any)).called(1);

    // Verify that no other interactions have been made with the mockConnection
    verifyNoMoreInteractions(mockConnection);

    // Verify that the onNotification callback was never called
    verifyNever(mockOnNotification(any, any, any));

    //publish some data and expect an update
    data['title'] = 'Title2';
    data['description'] = 'Description2';
    data['level'] = 'INFO';
    mockSub.updateValue(jsonEncode(data), 2);

    verify(mockOnNotification(data['title'], data['description'], any));

    //try malformed data
    data['title'] = null;
    data['description'] = null;
    data['level'] = 'malformedlevel';

    mockSub.updateValue(jsonEncode(data), 3);
    reset(mockOnNotification);
    verifyNever(mockOnNotification(any, any, any));
  });


}