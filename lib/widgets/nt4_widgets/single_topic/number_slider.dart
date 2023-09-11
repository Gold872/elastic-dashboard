import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class NumberSlider extends StatelessWidget with NT4Widget {
  @override
  final String type = 'Number Slider';

  double minValue;
  double maxValue;
  int divisions;

  double _currentValue = 0.0;
  double _previousValue = 0.0;

  NumberSlider({
    super.key,
    required topic,
    this.minValue = -1.0,
    this.maxValue = 1.0,
    this.divisions = 5,
    period = Globals.defaultPeriod,
  }) {
    super.topic = topic;
    super.period = period;

    init();
  }

  NumberSlider.fromJson({super.key, required Map<String, dynamic> jsonData})
      : minValue = jsonData['min_value'] ?? -1.0,
        maxValue = jsonData['max_value'] ?? 1.0,
        divisions = jsonData['divisions'] {
    topic = jsonData['topic'] ?? '';
    period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'min_value': minValue,
      'max_value': maxValue,
      'divisions': divisions,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      // Min and max values
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMin = double.tryParse(value);
                if (newMin == null) {
                  return;
                }
                minValue = newMin;
                refresh();
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.-]")),
              label: 'Min Value',
              initialText: minValue.toString(),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMax = double.tryParse(value);
                if (newMax == null) {
                  return;
                }
                maxValue = newMax;
                refresh();
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.-]")),
              label: 'Max Value',
              initialText: maxValue.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Number of divisions
      DialogTextInput(
        onSubmit: (value) {
          int? newDivisions = int.tryParse(value);
          if (newDivisions == null || newDivisions < 2) {
            return;
          }
          divisions = newDivisions;
          refresh();
        },
        formatter: FilteringTextInputFormatter.digitsOnly,
        label: 'Divisions',
        initialText: divisions.toString(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        double value = snapshot.data as double? ?? 0.0;

        double clampedValue = value.clamp(minValue, maxValue);

        if (clampedValue != _previousValue) {
          _currentValue = clampedValue;
        }

        _previousValue = clampedValue;

        double divisionSeparation = (maxValue - minValue) / (divisions - 1);

        return Column(
          children: [
            Expanded(
              child: Text(
                _currentValue.toStringAsFixed(4),
                style: Theme.of(context).textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Slider(
                value: _currentValue,
                min: minValue,
                max: maxValue,
                focusNode: FocusNode(
                  canRequestFocus: false,
                ),
                onChanged: (value) {
                  _currentValue = value;
                },
                onChangeEnd: (value) {
                  bool publishTopic = nt4Topic == null;

                  createTopicIfNull();

                  if (nt4Topic == null) {
                    return;
                  }

                  if (publishTopic) {
                    nt4Connection.nt4Client.publishTopic(nt4Topic!);
                  }

                  nt4Connection.updateDataFromTopic(nt4Topic!, value);

                  _previousValue = value;
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                for (int i = 0; i < divisions; i++)
                  Text((minValue + divisionSeparation * i).toStringAsFixed(2)),
              ],
            ),
          ],
        );
      },
    );
  }
}
