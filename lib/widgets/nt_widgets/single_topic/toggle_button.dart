import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ToggleButton extends NTWidget {
  static const String widgetType = 'Toggle Button';
  @override
  String type = widgetType;

  ToggleButton({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ToggleButton.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
        stream: subscription?.periodicStream(yieldAll: false),
        initialData: ntConnection.getLastAnnouncedValue(topic),
        builder: (context, snapshot) {
          bool value = tryCast(snapshot.data) ?? false;

          String buttonText = topic.substring(topic.lastIndexOf('/') + 1);

          Size buttonSize = MediaQuery.of(context).size;

          ThemeData theme = Theme.of(context);

          return GestureDetector(
            onTapUp: (_) {
              bool publishTopic =
                  ntTopic == null || !ntConnection.isTopicPublished(ntTopic);

              createTopicIfNull();

              if (ntTopic == null) {
                return;
              }

              if (publishTopic) {
                ntConnection.nt4Client.publishTopic(ntTopic!);
              }

              ntConnection.updateDataFromTopic(ntTopic!, !value);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: buttonSize.width * 0.01,
                  vertical: buttonSize.height * 0.01),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 10),
                width: buttonSize.width,
                height: buttonSize.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: const [
                    BoxShadow(
                      offset: Offset(2, 2),
                      blurRadius: 10.0,
                      spreadRadius: -5,
                      color: Colors.black,
                    ),
                  ],
                  color: (value)
                      ? theme.colorScheme.primaryContainer
                      : const Color.fromARGB(255, 50, 50, 50),
                ),
                child: Center(
                    child: Text(
                  buttonText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                )),
              ),
            ),
          );
        });
  }
}
