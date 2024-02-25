import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class NetworkAlertsModel extends NTWidgetModel {
  @override
  String type = NetworkAlerts.widgetType;

  String get errorsTopicName => '$topic/errors';
  String get warningsTopicName => '$topic/warnings';
  String get infosTopicName => '$topic/infos';

  NetworkAlertsModel({required super.topic, super.dataType, super.period})
      : super();

  NetworkAlertsModel.fromJson({required super.jsonData}) : super.fromJson();

  @override
  List<Object> getCurrentData() {
    List<Object?> errorsRaw = ntConnection
            .getLastAnnouncedValue(errorsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<Object?> warningsRaw = ntConnection
            .getLastAnnouncedValue(warningsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<Object?> infosRaw = ntConnection
            .getLastAnnouncedValue(infosTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<String> errors = errorsRaw.whereType<String>().toList();
    List<String> warnings = warningsRaw.whereType<String>().toList();
    List<String> infos = infosRaw.whereType<String>().toList();

    return [...errors, ...warnings, ...infos];
  }
}

class NetworkAlerts extends NTWidget {
  static const String widgetType = 'Alerts';

  const NetworkAlerts({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    NetworkAlertsModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        List<Object?> errorsRaw = ntConnection
                .getLastAnnouncedValue(model.errorsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<Object?> warningsRaw = ntConnection
                .getLastAnnouncedValue(model.warningsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<Object?> infosRaw = ntConnection
                .getLastAnnouncedValue(model.infosTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<String> errors = errorsRaw.whereType<String>().toList();
        List<String> warnings = warningsRaw.whereType<String>().toList();
        List<String> infos = infosRaw.whereType<String>().toList();

        return ListView.builder(
          itemCount: errors.length + warnings.length + infos.length,
          itemBuilder: (context, index) {
            String alertType = 'error';
            String alertMessage;
            if (index >= errors.length) {
              index -= errors.length;
              alertType = 'warning';
            }
            if (index >= warnings.length && alertType == 'warning') {
              index -= warnings.length;
              alertType = 'info';
            }
            if (index >= infos.length && alertType == 'info') {
              alertType = 'none';
            }

            TextStyle? messageStyle = Theme.of(context).textTheme.bodyMedium;

            switch (alertType) {
              case 'error':
                alertMessage = errors[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  leading: const Icon(
                    Icons.cancel,
                    size: 24,
                    color: Colors.red,
                  ),
                  title: Text(alertMessage, style: messageStyle),
                );
              case 'warning':
                alertMessage = warnings[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  leading: const Icon(
                    Icons.warning,
                    size: 24,
                    color: Colors.yellow,
                  ),
                  title: Text(alertMessage, style: messageStyle),
                );
              case 'info':
                alertMessage = infos[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  leading: const Icon(
                    Icons.info,
                    size: 24,
                    color: Colors.green,
                  ),
                  title: Text(alertMessage, style: messageStyle),
                );
              default:
                return Container();
            }
          },
        );
      },
    );
  }
}
