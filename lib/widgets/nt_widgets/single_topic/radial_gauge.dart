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

  double _startAngle = -140.0;
  double _endAngle = 140.0;
  double _minValue = 0.0;
  double _maxValue = 100.0;

  int _numberOfLabels = 8;

  bool _wrapValue = false;
  bool _showPointer = true;
  bool _showTicks = true;

  RadialGauge({
    super.key,
    required super.topic,
    double startAngle = -140.0,
    double endAngle = 140.0,
    double minValue = 0.0,
    double maxValue = 100.0,
    int numberOfLabels = 8,
    bool wrapValue = false,
    bool showPointer = true,
    bool showTicks = true,
    super.dataType,
    super.period,
  })  : _wrapValue = wrapValue,
        _showTicks = showTicks,
        _showPointer = showPointer,
        _numberOfLabels = numberOfLabels,
        _maxValue = maxValue,
        _minValue = minValue,
        _startAngle = startAngle,
        _endAngle = endAngle,
        super();

  RadialGauge.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _startAngle = tryCast(jsonData['start_angle']) ?? _startAngle;
    _endAngle = tryCast(jsonData['end_angle']) ?? _endAngle;
    _minValue = tryCast(jsonData['min_value']) ?? _minValue;
    _maxValue = tryCast(jsonData['max_value']) ?? _maxValue;

    _numberOfLabels = tryCast(jsonData['number_of_labels']) ?? _numberOfLabels;

    _wrapValue = tryCast(jsonData['wrap_value']) ?? _wrapValue;
    _showPointer = tryCast(jsonData['show_pointer']) ?? _showPointer;
    _showTicks = tryCast(jsonData['show_ticks']) ?? _showTicks;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'start_angle': _startAngle,
      'end_angle': _endAngle,
      'min_value': _minValue,
      'max_value': _maxValue,
      'number_of_labels': _numberOfLabels,
      'wrap_value': _wrapValue,
      'show_pointer': _showPointer,
      'show_ticks': _showTicks,
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
              initialText: _startAngle.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newStartAngle = double.tryParse(value);

                if (newStartAngle == null) {
                  return;
                }
                _startAngle = newStartAngle;

                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogTextInput(
              label: 'End Angle (CW+)',
              initialText: _endAngle.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newEndAngle = double.tryParse(value);

                if (newEndAngle == null) {
                  return;
                }
                _endAngle = newEndAngle;

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
              initialText: _minValue.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newMin = double.tryParse(value);

                if (newMin == null) {
                  return;
                }
                _minValue = newMin;

                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogTextInput(
              label: 'Max Value',
              initialText: _maxValue.toString(),
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              onSubmit: (value) {
                double? newMax = double.tryParse(value);

                if (newMax == null) {
                  return;
                }
                _maxValue = newMax;

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
              initialValue: _wrapValue,
              onToggle: (value) {
                _wrapValue = value;

                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Pointer',
              initialValue: _showPointer,
              onToggle: (value) {
                _showPointer = value;

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
              initialText: _numberOfLabels.toString(),
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newLabelCount = int.tryParse(value);

                if (newLabelCount == null) {
                  return;
                }

                _numberOfLabels = newLabelCount;
                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogToggleSwitch(
              label: 'Show Ticks',
              initialValue: _showTicks,
              onToggle: (value) {
                _showTicks = value;

                refresh();
              },
            ),
          ),
        ],
      ),
    ];
  }

  static double _getWrappedValue(double value, double min, double max) {
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

        if (_wrapValue) {
          value = _getWrappedValue(value, _minValue, _maxValue);
        }

        return SfRadialGauge(
          axes: [
            RadialAxis(
              startAngle: _startAngle - 90.0,
              endAngle: _endAngle - 90.0,
              minimum: _minValue,
              maximum: _maxValue,
              showTicks: _showTicks,
              showLabels: _numberOfLabels != 0,
              interval: (_numberOfLabels != 0)
                  ? (_maxValue - _minValue) / _numberOfLabels
                  : null,
              showLastLabel:
                  _getWrappedValue(_endAngle - _startAngle, -180.0, 180.0) !=
                      0.0,
              canScaleToFit: true,
              annotations: [
                GaugeAnnotation(
                  horizontalAlignment: GaugeAlignment.center,
                  verticalAlignment: GaugeAlignment.center,
                  angle: 90.0,
                  positionFactor: (_showPointer) ? 0.35 : 0.05,
                  widget: Text(
                    value.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: (_showPointer) ? 18.0 : 28.0,
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
                if (_showPointer)
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
