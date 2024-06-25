import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';

class RobotNotificationsListener {
  bool _alertFirstRun = true;
  final NTConnection ntConnection;
  final Function(String title, String description, Icon icon) onNotification;

  RobotNotificationsListener({
    required this.ntConnection,
    required this.onNotification,
  });

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

  void _onAlert(Object alertData, int timestamp) {
    // prevent showing a notification when we connect to NT
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

    if (!data.containsKey('level')) {}

    Icon icon;

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
    String? title = tryCast(data['title']);
    String? description = tryCast(data['description']);

    if (title == null || description == null) {
      return;
    }

    onNotification(title, description, icon);
  }
}
