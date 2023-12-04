import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ToggleButton extends NT4Widget {
  @override
  String type = 'Toggle Button';

  ToggleButton({super.key, required super.topic, super.period}) : super();

  ToggleButton.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
        stream: subscription?.periodicStream(yieldAll: false),
        initialData: nt4Connection.getLastAnnouncedValue(topic),
        builder: (context, snapshot) {
          notifier = context.watch<NT4WidgetNotifier?>();

          bool value = tryCast(snapshot.data) ?? false;

          String buttonText = topic.substring(topic.lastIndexOf('/') + 1);

          Size buttonSize = MediaQuery.of(context).size;

          ThemeData theme = Theme.of(context);

          return GestureDetector(
            onTapUp: (_) {
              bool publishTopic = nt4Topic == null;

              createTopicIfNull();

              if (nt4Topic == null) {
                return;
              }

              if (publishTopic) {
                nt4Connection.nt4Client.publishTopic(nt4Topic!);
              }

              nt4Connection.updateDataFromTopic(nt4Topic!, !value);
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
                    child:
                        Text(buttonText, style: theme.textTheme.titleMedium)),
              ),
            ),
          );
        });
  }
}
