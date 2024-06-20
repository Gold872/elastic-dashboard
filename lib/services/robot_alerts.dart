import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RobotAlerts {
  bool _alertFirstRun = true;

  void listen(NTConnection nt, BuildContext context) {
    var notifications = ntConnection.subscribe("elastic/robotalerts");
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
    List<String> data =
        alertData.toString().replaceAll("[", "").replaceAll("]", "").split(",");
    Icon icon;
    if (data[0] == "INFO") {
      icon = const Icon(Icons.info);
    } else if (data[0] == "WARNING") {
      icon = const Icon(
        Icons.warning_amber,
        color: Colors.orange,
      );
    } else if (data[0] == "ERROR") {
      icon = const Icon(
        Icons.error,
        color: Colors.red,
      );
    } else {
      icon = const Icon(Icons.question_mark);
    }

    String title = data[1];
    String description = data[2];
    _buildNotification(title, description, icon, context).show(context);
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
        key: 'robotalert',
        type: StackedType.above,
        itemOffset: const Offset(0, 5),
      ),
    );
  }
}
