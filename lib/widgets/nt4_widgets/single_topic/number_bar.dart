import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class NumberBar extends NT4Widget {
  static const String widgetType = 'Number Bar';
  @override
  String type = widgetType;

  late double minValue;
  late double maxValue;
  late int? divisions;
  late bool inverted;
  late String orientation;

  NumberBar({
    super.key,
    required super.topic,
    this.minValue = -1.0,
    this.maxValue = 1.0,
    this.divisions = 5,
    this.inverted = false,
    this.orientation = 'horizontal',
    super.period,
  }) : super();

  NumberBar.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    minValue = tryCast(jsonData['min_value']) ?? -1.0;
    maxValue = tryCast(jsonData['max_value']) ?? 1.0;
    divisions = tryCast(jsonData['divisions']);
    inverted = tryCast(jsonData['inverted']) ?? false;
    orientation = tryCast(jsonData['orientation']) ?? 'horizontal';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
      'min_value': minValue,
      'max_value': maxValue,
      'divisions': divisions,
      'inverted': inverted,
      'orientation': orientation,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      // Orientation
      Column(
        children: [
          const Text('Orientation'),
          DialogDropdownChooser<String>(
            initialValue:
                '${orientation[0].toUpperCase()}${orientation.substring(1)}',
            choices: const ['Horizontal', 'Vertical'],
            onSelectionChanged: (value) {
              if (value == null) {
                return;
              }

              orientation = value.toLowerCase();
              refresh();
            },
          ),
        ],
      ),
      const SizedBox(height: 5),
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
      // Number of divisions and orientation
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: DialogTextInput(
              onSubmit: (value) {
                int? newDivisions = int.tryParse(value);
                if (newDivisions != null && newDivisions < 2) {
                  return;
                }
                divisions = newDivisions;
                refresh();
              },
              formatter: FilteringTextInputFormatter.digitsOnly,
              label: 'Divisions',
              initialText: (divisions != null) ? divisions.toString() : '',
              allowEmptySubmission: true,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Center(
              child: DialogToggleSwitch(
                initialValue: inverted,
                label: 'Inverted',
                onToggle: (value) {
                  inverted = value;
                  refresh();
                },
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        double value = tryCast(snapshot.data) ?? 0.0;

        double clampedValue = value.clamp(minValue, maxValue);

        double? divisionInterval = (divisions != null)
            ? (maxValue - minValue) / (divisions! - 1)
            : null;

        LinearGaugeOrientation gaugeOrientation = (orientation == 'vertical')
            ? LinearGaugeOrientation.vertical
            : LinearGaugeOrientation.horizontal;

        List<Widget> children = [
          Text(
            value.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
          const Flexible(
            child: SizedBox(width: 5.0, height: 5.0),
          ),
          SfLinearGauge(
            key: UniqueKey(),
            maximum: maxValue,
            minimum: minValue,
            barPointers: [
              LinearBarPointer(
                value: clampedValue,
                animationDuration: 0,
                thickness: 7.5,
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
            ],
            axisTrackStyle: const LinearAxisTrackStyle(
              thickness: 7.5,
              edgeStyle: LinearEdgeStyle.bothCurve,
            ),
            orientation: gaugeOrientation,
            isAxisInversed: inverted,
            interval: divisionInterval,
          ),
        ];

        if (gaugeOrientation == LinearGaugeOrientation.vertical) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        }
      },
    );
  }
}
