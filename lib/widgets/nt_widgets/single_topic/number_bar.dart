import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class NumberBarModel extends NTWidgetModel {
  @override
  String type = NumberBar.widgetType;

  double _minValue = -1.0;
  double _maxValue = 1.0;
  int? _divisions = 5;
  bool _inverted = false;
  String _orientation = 'horizontal';

  double get minValue => _minValue;

  set minValue(value) {
    _minValue = value;
    refresh();
  }

  double get maxValue => _maxValue;

  set maxValue(value) {
    _maxValue = value;
    refresh();
  }

  int? get divisions => _divisions;

  set divisions(value) {
    _divisions = value;
    refresh();
  }

  bool get inverted => _inverted;

  set inverted(value) {
    _inverted = value;
    refresh();
  }

  String get orientation => _orientation;

  set orientation(value) {
    _orientation = value;
    refresh();
  }

  NumberBarModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    double minValue = -1.0,
    double maxValue = 1.0,
    int? divisions = 5,
    bool inverted = false,
    String orientation = 'horizontal',
    super.dataType,
    super.period,
  })  : _orientation = orientation,
        _divisions = divisions,
        _inverted = inverted,
        _maxValue = maxValue,
        _minValue = minValue,
        super();

  NumberBarModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _minValue = tryCast(jsonData['min_value']) ?? -1.0;
    _maxValue = tryCast(jsonData['max_value']) ?? 1.0;
    _divisions = tryCast(jsonData['divisions']);
    _inverted = tryCast(jsonData['inverted']) ?? false;
    _orientation = tryCast(jsonData['orientation']) ?? 'horizontal';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'min_value': minValue,
      'max_value': maxValue,
      if (divisions != null) 'divisions': divisions,
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
                '${_orientation[0].toUpperCase()}${_orientation.substring(1)}',
            choices: const ['Horizontal', 'Vertical'],
            onSelectionChanged: (value) {
              if (value == null) {
                return;
              }

              orientation = value.toLowerCase();
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
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              label: 'Min Value',
              initialText: _minValue.toString(),
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMax = double.tryParse(value);
                if (newMax == null) {
                  return;
                }
                maxValue = newMax;
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              label: 'Max Value',
              initialText: _maxValue.toString(),
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
              },
              formatter: FilteringTextInputFormatter.digitsOnly,
              label: 'Divisions',
              initialText: (_divisions != null) ? _divisions.toString() : '',
              allowEmptySubmission: true,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Center(
              child: DialogToggleSwitch(
                initialValue: _inverted,
                label: 'Inverted',
                onToggle: (value) {
                  inverted = value;
                },
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

class NumberBar extends NTWidget {
  static const String widgetType = 'Number Bar';

  const NumberBar({super.key});

  @override
  Widget build(BuildContext context) {
    NumberBarModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.subscription?.periodicStream(yieldAll: false),
      initialData: model.ntConnection.getLastAnnouncedValue(model.topic),
      builder: (context, snapshot) {
        double value = tryCast<num>(snapshot.data)?.toDouble() ?? 0.0;

        double clampedValue = value.clamp(model.minValue, model.maxValue);

        double? divisionInterval = (model.divisions != null)
            ? (model.maxValue - model.minValue) / (model.divisions! - 1)
            : null;

        int fractionDigits = (model.dataType == NT4TypeStr.kInt) ? 0 : 2;

        LinearGaugeOrientation gaugeOrientation =
            (model.orientation == 'vertical')
                ? LinearGaugeOrientation.vertical
                : LinearGaugeOrientation.horizontal;

        List<Widget> children = [
          Text(
            value.toStringAsFixed(fractionDigits),
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
          const Flexible(
            child: SizedBox(width: 5.0, height: 5.0),
          ),
          SfLinearGauge(
            key: UniqueKey(),
            maximum: model.maxValue,
            minimum: model.minValue,
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
            isAxisInversed: model.inverted,
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
