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
}
