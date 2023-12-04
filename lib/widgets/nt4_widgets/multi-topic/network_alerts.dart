import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NetworkAlerts extends NT4Widget {
  static const String widgetType = 'Alerts';
  @override
  String type = widgetType;

  late String errorsTopicName;
  late String warningsTopicName;
  late String infosTopicName;

  NetworkAlerts({super.key, required super.topic, super.period}) : super();

  NetworkAlerts.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    errorsTopicName = '$topic/errors';
    warningsTopicName = '$topic/warnings';
    infosTopicName = '$topic/infos';
  }

  @override
  void resetSubscription() {
    errorsTopicName = '$topic/errors';
    warningsTopicName = '$topic/warnings';
    infosTopicName = '$topic/infos';

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> errorsRaw = nt4Connection
            .getLastAnnouncedValue(errorsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<Object?> warningsRaw = nt4Connection
            .getLastAnnouncedValue(warningsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<Object?> infosRaw = nt4Connection
            .getLastAnnouncedValue(infosTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<String> errors = errorsRaw.whereType<String>().toList();
    List<String> warnings = warningsRaw.whereType<String>().toList();
    List<String> infos = infosRaw.whereType<String>().toList();

    return [errors, warnings, infos];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        List<Object?> errorsRaw = nt4Connection
                .getLastAnnouncedValue(errorsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<Object?> warningsRaw = nt4Connection
                .getLastAnnouncedValue(warningsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<Object?> infosRaw = nt4Connection
                .getLastAnnouncedValue(infosTopicName)
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
