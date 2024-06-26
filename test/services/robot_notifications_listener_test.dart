import 'dart:convert';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/robot_notifications_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_util.dart';
import '../test_util.mocks.dart';

// Create a mock class for the onNotification callback
class MockNotificationCallback extends Mock {
  void call(String? title, String? description, Icon? icon);
}

void main() {
  test("Robot Notifications (No Connection) ", () {
    MockNTConnection mockConnection = createMockOfflineNT4();
    MockNT4Subscription mockSub = MockNT4Subscription();

    when(mockConnection.subscribeAll(any, any)).thenReturn(mockSub);

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
  test(
    "Robot Notifications (Initial Connection | No Notifications)",
    () {
      MockNTConnection mockConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
              name: '/Elastic/robotnotifications',
              type: NT4TypeStr.kString,
              properties: {})
        ],
      );
      MockNT4Subscription mockSub = MockNT4Subscription();

      when(mockConnection.subscribeAll(any, any)).thenReturn(mockSub);

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
    },
  );

  test(
    "Robot Notifications (Initial Connection | No Notifications)",
    () {
      MockNTConnection mockConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
              name: '/Elastic/robotnotifications',
              type: NT4TypeStr.kString,
              properties: {})
        ],
      );
      MockNT4Subscription mockSub = MockNT4Subscription();

      when(mockConnection.subscribeAll(any, any)).thenReturn(mockSub);

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
    },
  );
  test(
    "Robot Notifications (Initial Connection | Existing Notifications)",
    () {
      Map<String, dynamic> initData = {
        'title': 'Title1',
        'description': 'Description1',
        'level': 'INFO'
      };
      print('${jsonEncode(initData)}');
      MockNTConnection mockConnection = createMockOnlineNT4(virtualTopics: [
        NT4Topic(
            name: '/Elastic/robotnotifications',
            type: NT4TypeStr.kString,
            properties: {})
      ]);

      MockNT4Subscription mockSub = MockNT4Subscription();

      when(mockConnection.subscribeAll(any, any)).thenReturn(mockSub);

      // Create a mock for the onNotification callback
      MockNotificationCallback mockOnNotification = MockNotificationCallback();

      RobotNotificationsListener notifications = RobotNotificationsListener(
        ntConnection: mockConnection,
        onNotification: mockOnNotification.call,
      );

      notifications.listen();
      //TODO add stuff

      // Verify that subscribeAll was called with the specific parameters
      verify(mockConnection.subscribeAll('/Elastic/robotnotifications', 0.2))
          .called(1);
      verify(mockConnection.addDisconnectedListener(any)).called(1);

      // Verify that no other interactions have been made with the mockConnection
      verifyNoMoreInteractions(mockConnection);

      // Verify that the onNotification callback was never called
      verifyNever(mockOnNotification.call(any, any, any));
    },
  );
}
