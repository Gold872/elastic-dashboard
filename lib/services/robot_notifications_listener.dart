import 'dart:convert';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:flutter/material.dart';

class RobotNotificationsListener {
  bool _alertFirstRun = true;

  void listen(NTConnection nt, BuildContext context) {
    var notifications = ntConnection.subscribe("elastic/robotnotifications");
    notifications.listen((alertData, alertTimestamp) {
      _onAlert(alertData!, alertTimestamp, context);
    });
  }

  void _onAlert(Object alertData, int timestamp, BuildContext context) {
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

    _buildNotification(data["title"], data["description"], icon, context)
        .show(context);
  }

  ElegantNotification _buildNotification(
      String title, String description, Icon icon, BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    return ElegantNotification(
      autoDismiss: true,
      showProgressIndicator: true,
      background: colorScheme.surface,
      width: 350,
      position: Alignment.bottomRight,
      title: Text(
        title,
        style: textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      icon: icon,
      description: Text(description),
      stackedOptions: StackedOptions(
        key: 'robotnotification',
        type: StackedType.above,
        itemOffset: const Offset(0, 5),
      ),
    );
  }
}
