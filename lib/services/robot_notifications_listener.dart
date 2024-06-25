import 'dart:convert';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:flutter/material.dart';

class RobotNotificationsListener {
  bool _alertFirstRun = true;
  final NTConnection connection;
  final Function(String title, String description, Icon icon) onNotification;

  RobotNotificationsListener(
      {required this.connection, required this.onNotification});

  void listen() {
    var notifications =
        ntConnection.subscribeAll("elastic/robotnotifications", 0.2);
    notifications.listen((alertData, alertTimestamp) {
      _onAlert(alertData!, alertTimestamp);
    });
  }

  void _onAlert(Object alertData, int timestamp) {
    //prevent showing a notification when we connect to NT
    if (_alertFirstRun) {
      _alertFirstRun = false;
      return;
    }

    Map<String, dynamic> data = jsonDecode(alertData.toString());
    Icon icon;

    if (data["level"] == "INFO") {
      icon = const Icon(Icons.info);
    } else if (data["level"] == "WARNING") {
      icon = const Icon(
        Icons.warning_amber,
        color: Colors.orange,
      );
    } else if (data["level"] == "ERROR") {
      icon = const Icon(
        Icons.error,
        color: Colors.red,
      );
    } else {
      icon = const Icon(Icons.question_mark);
    }
    onNotification(data["title"], data["description"], icon);
  }
}
