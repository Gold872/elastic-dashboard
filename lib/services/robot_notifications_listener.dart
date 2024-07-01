import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';

/// Listens to robot notifications from NetworkTables (NT) and triggers notifications
/// through the provided [onNotification] callback.
class RobotNotificationsListener {
  bool _alertFirstRun = true;
  final NTConnection connection;
  final Function(String title, String description, Icon icon) onNotification;

  /// Constructs a [RobotNotificationsListener] instance.
  ///
  /// Requires an [NTConnection] instance for subscribing to notifications
  /// and a callback [onNotification] to handle received notifications.
  RobotNotificationsListener({
    required this.connection,
    required this.onNotification,
  });

  /// Starts listening to robot notifications.
  void listen() {
    var notifications =
        ntConnection.subscribeAll('/Elastic/robotnotifications', 0.2);
    notifications.listen((alertData, alertTimestamp) {
      if (alertData == null) {
        return;
      }
      _onAlert(alertData, alertTimestamp);
    });

    ntConnection.addDisconnectedListener(() => _alertFirstRun = true);
  }

  /// Handles incoming robot notification data.
  void _onAlert(Object alertData, int timestamp) {
    // Prevent showing a notification when we connect to NT for the first time
    if (_alertFirstRun) {
      _alertFirstRun = false;
      return;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(alertData.toString());
    } catch (e) {
      return;
    }

    if (!data.containsKey('level')) {
      // Invalid data format, do nothing
      return;
    }

    Icon icon;

    // Determine the icon based on the alert level
    if (data['level'] == 'INFO') {
      icon = const Icon(Icons.info);
    } else if (data['level'] == 'WARNING') {
      icon = const Icon(
        Icons.warning_amber,
        color: Colors.orange,
      );
    } else if (data['level'] == 'ERROR') {
      icon = const Icon(
        Icons.error,
        color: Colors.red,
      );
    } else {
      icon = const Icon(Icons.question_mark);
    }

    // Extract title and description from data
    String? title = tryCast(data['title']);
    String? description = tryCast(data['description']);

    if (title == null || description == null) {
      // If title or description is missing, do not process further
      return;
    }

    // Trigger the notification callback with the parsed data
    onNotification(title, description, icon);
  }
}
