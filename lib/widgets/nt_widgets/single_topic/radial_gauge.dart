import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RadialGauge extends NTWidget {
  static const String widgetType = 'Radial Gauge';
  @override
  String type = widgetType;

  double startAngle = -140.0;
  double endAngle = 140.0;
  double minValue = 0.0;
  double maxValue = 100.0;

  int numberOfLabels = 8;

  bool wrapValue = false;
  bool showPointer = true;
  bool showTicks = true;

  RadialGauge({
    super.key,
    required super.topic,
    this.startAngle = -140.0,
    this.endAngle = 140.0,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.numberOfLabels = 8,
    this.wrapValue = false,
    this.showPointer = true,
    this.showTicks = true,
    super.dataType,
    super.period,
  }) : super();

  RadialGauge.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    startAngle = tryCast(jsonData['start_angle']) ?? startAngle;
    endAngle = tryCast(jsonData['end_angle']) ?? endAngle;
    minValue = tryCast(jsonData['min_value']) ?? minValue;
    maxValue = tryCast(jsonData['max_value']) ?? maxValue;

    numberOfLabels = tryCast(jsonData['number_of_labels']) ?? numberOfLabels;

    wrapValue = tryCast(jsonData['wrap_value']) ?? wrapValue;
    showPointer = tryCast(jsonData['show_pointer']) ?? showPointer;
    showTicks = tryCast(jsonData['show_ticks']) ?? showTicks;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'start_angle': startAngle,
      'end_angle': endAngle,
      'min_value': minValue,
      'max_value': maxValue,
      'number_of_labels': numberOfLabels,
      'wrap_value': wrapValue,
      'show_pointer': showPointer,
      'show_ticks': showTicks,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      // Start/End angles
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              label: 'Start Angle (CW+)',
              initialText: startAngle.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newStartAngle = double.tryParse(value);

                if (newStartAngle == null) {
                  return;
                }
                startAngle = newStartAngle;

                refresh();
              },
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogTextInput(
              label: 'End Angle (CW+)',
              initialText: endAngle.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newEndAngle = double.tryParse(value);

                if (newEndAngle == null) {
                  return;
                }
                endAngle = newEndAngle;

                refresh();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Min/Max values
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              label: 'Min Value',
              initialText: minValue.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newMin = double.tryParse(value);

                if (newMin == null) {
                  return;
                }
                minValue = newMin;

                refresh();
              },
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogTextInput(
              label: 'Max Value',
              initialText: maxValue.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newMax = double.tryParse(value);

                if (newMax == null) {
                  return;
                }
                maxValue = newMax;

                refresh();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Wrap value & Show pointer
      Row(
        children: [
          Flexible(
            child: DialogToggleSwitch(
              label: 'Wrap Value',
              initialValue: wrapValue,
              onToggle: (value) {
                wrapValue = value;

                refresh();
              },
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Pointer',
              initialValue: showPointer,
              onToggle: (value) {
                showPointer = value;

                refresh();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Label & tick customization
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              label: 'Number of Labels',
              initialText: numberOfLabels.toString(),
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newLabelCount = int.tryParse(value);

                if (newLabelCount == null) {
                  return;
                }

                numberOfLabels = newLabelCount;
                refresh();
              },
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Ticks',
              initialValue: showTicks,
              onToggle: (value) {
                showTicks = value;

                refresh();
              },
            ),
          ),
        ],
      ),
    ];
  }

  static double _wrapValue(double value, double min, double max) {
    if (value >= min && value <= max) {
      return value;
    }
    double modulus = max - min;

    // Wrap input if it's above the maximum input
    int numMax = (value - min) ~/ modulus;
    value -= numMax * modulus;

    // Wrap input if it's below the minimum input
    int numMin = (value - max) ~/ modulus;
    value -= numMin * modulus;

    return value;
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        double value = tryCast(snapshot.data) ?? 0.0;

        if (wrapValue) {
          value = _wrapValue(value, minValue, maxValue);
        }

        return SfRadialGauge(
          axes: [
            RadialAxis(
              startAngle: startAngle - 90.0,
              endAngle: endAngle - 90.0,
              minimum: minValue,
              maximum: maxValue,
              showTicks: showTicks,
              showLabels: numberOfLabels != 0,
              interval: (numberOfLabels != 0)
                  ? (maxValue - minValue) / numberOfLabels
                  : null,
              showLastLabel:
                  _wrapValue(endAngle - startAngle, -180.0, 180.0) != 0.0,
              canScaleToFit: true,
              annotations: [
                GaugeAnnotation(
                  horizontalAlignment: GaugeAlignment.center,
                  verticalAlignment: GaugeAlignment.center,
                  angle: 90.0,
                  positionFactor: (showPointer) ? 0.35 : 0.05,
                  widget: Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: (showPointer) ? 18.0 : 28.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              pointers: [
                RangePointer(
                  enableAnimation: false,
                  enableDragging: false,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  value: value,
                ),
                if (showPointer)
                  NeedlePointer(
                    enableAnimation: false,
                    enableDragging: false,
                    needleColor: Colors.red,
                    needleEndWidth: 3.5,
                    needleStartWidth: 0.5,
                    needleLength: 0.5,
                    knobStyle: const KnobStyle(
                      borderColor: Colors.grey,
                      borderWidth: 0.025,
                      knobRadius: 0.05,
                    ),
                    value: value,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
