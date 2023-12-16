import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class VoltageView extends NTWidget {
  static const String widgetType = 'Voltage View';
  @override
  String type = widgetType;

  late double minValue;
  late double maxValue;
  late int? divisions;
  late bool inverted;
  late String orientation;

  VoltageView({
    super.key,
    required super.topic,
    this.minValue = 4.0,
    this.maxValue = 13.0,
    this.divisions = 5,
    this.inverted = false,
    this.orientation = 'horizontal',
    super.dataType,
    super.period,
  }) : super();

  VoltageView.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    minValue = tryCast(jsonData['min_value']) ?? tryCast(jsonData['min']) ?? 4;
    maxValue =
        tryCast(jsonData['max_value']) ?? tryCast(jsonData['max']) ?? 13.0;
    divisions =
        tryCast(jsonData['divisions']) ?? tryCast(jsonData['numOfTickMarks']);
    inverted = tryCast(jsonData['inverted']) ?? false;
    orientation = tryCast(jsonData['orientation']) ?? 'horizontal';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
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
    notifier = context.watch<NTWidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NTWidgetNotifier?>();

        double voltage = tryCast(snapshot.data) ?? 0.0;

        double clampedVoltage = voltage.clamp(minValue, maxValue);

        double? divisionInterval = (divisions != null)
            ? (maxValue - minValue) / (divisions! - 1)
            : null;

        LinearGaugeOrientation gaugeOrientation = (orientation == 'vertical')
            ? LinearGaugeOrientation.vertical
            : LinearGaugeOrientation.horizontal;

        List<Widget> children = [
          Text(
            '${voltage.toStringAsFixed(2)} V',
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
                value: clampedVoltage,
                color: Colors.yellow.shade600,
                animationDuration: 0,
                thickness: 7.5,
              ),
            ],
            axisTrackStyle: const LinearAxisTrackStyle(
              thickness: 7.5,
            ),
            labelFormatterCallback: (value) => '$value V',
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
