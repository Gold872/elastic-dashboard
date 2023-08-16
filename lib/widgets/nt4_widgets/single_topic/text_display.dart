import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TextDisplay extends StatelessWidget with NT4Widget {
  @override
  String type = 'Text Display';

  final TextEditingController _controller = TextEditingController();

  Object? _previousValue;

  TextDisplay({super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  TextDisplay.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    topic = jsonData['topic'] ?? '';
    period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        Object data = snapshot.data ?? '';

        if (data.toString() != _previousValue.toString()) {
          // Needed to prevent errors
          Future(() async {
            _controller.text = data.toString();

            _previousValue = data;
          });
        }

        return TextField(
          controller: _controller,
          textAlign: TextAlign.left,
          onSubmitted: (value) {
            bool publishTopic = nt4Topic == null;

            createTopicIfNull();

            if (nt4Topic == null) {
              return;
            }

            late Object? formattedData;

            String dataType = nt4Topic!.type;
            switch (dataType) {
              case NT4TypeStr.kBool:
                formattedData = bool.tryParse(value);
                break;
              case NT4TypeStr.kFloat32:
              case NT4TypeStr.kFloat64:
                formattedData = double.tryParse(value);
                break;
              case NT4TypeStr.kInt:
                formattedData = int.tryParse(value);
                break;
              case NT4TypeStr.kString:
                formattedData = value;
                break;
              default:
                break;
            }

            if (publishTopic) {
              nt4Connection.nt4Client.publishTopic(nt4Topic!);
            }

            if (formattedData != null) {
              nt4Connection.updateDataFromTopic(nt4Topic!, formattedData);
            }

            _previousValue = value;
          },
        );
      },
    );
  }
}
