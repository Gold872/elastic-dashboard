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

class NumberSlider extends NTWidget {
  static const String widgetType = 'Number Slider';
  @override
  final String type = widgetType;

  late double _minValue;
  late double _maxValue;
  late int _divisions;
  late bool _updateContinuously;

  double _currentValue = 0.0;

  bool _dragging = false;

  NumberSlider({
    super.key,
    required super.topic,
    double minValue = -1.0,
    double maxValue = 1.0,
    int divisions = 5,
    bool updateContinuously = false,
    super.dataType,
    super.period,
  })  : _updateContinuously = updateContinuously,
        _divisions = divisions,
        _minValue = minValue,
        _maxValue = maxValue,
        super();

  NumberSlider.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _minValue =
        tryCast(jsonData['min_value']) ?? tryCast(jsonData['min']) ?? -1.0;
    _maxValue =
        tryCast(jsonData['max_value']) ?? tryCast(jsonData['max']) ?? 1.0;
    _divisions = tryCast(jsonData['divisions']) ??
        tryCast(jsonData['numOfTickMarks']) ??
        5;

    _updateContinuously = tryCast(jsonData['update_continuously']) ?? false;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'min_value': _minValue,
      'max_value': _maxValue,
      'divisions': _divisions,
      'publish_all': _updateContinuously,
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
                _minValue = newMin;
                refresh();
              },
              formatter: Constants.decimalTextFormatter(allowNegative: true),
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
                _maxValue = newMax;
                refresh();
              },
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              label: 'Max Value',
              initialText: _maxValue.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Number of divisions
      Row(
        children: [
          Flexible(
            flex: 2,
            child: DialogTextInput(
              onSubmit: (value) {
                int? newDivisions = int.tryParse(value);
                if (newDivisions == null || newDivisions < 2) {
                  return;
                }
                _divisions = newDivisions;
                refresh();
              },
              formatter: FilteringTextInputFormatter.digitsOnly,
              label: 'Divisions',
              initialText: _divisions.toString(),
            ),
          ),
          Flexible(
            flex: 3,
            child: DialogToggleSwitch(
              initialValue: _updateContinuously,
              label: 'Update While Dragging',
              onToggle: (value) {
                _updateContinuously = value;
              },
            ),
          ),
        ],
      ),
    ];
  }

  void _publishValue(double value) {
    bool publishTopic =
        ntTopic == null || !ntConnection.isTopicPublished(ntTopic);

    createTopicIfNull();

    if (ntTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(ntTopic!);
    }

    ntConnection.updateDataFromTopic(ntTopic!, value);
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        double value = tryCast(snapshot.data) ?? 0.0;

        double clampedValue = value.clamp(_minValue, _maxValue);

        if (!_dragging) {
          _currentValue = clampedValue;
        }

        double divisionSeparation = (_maxValue - _minValue) / (_divisions - 1);

        return Column(
          children: [
            Text(
              _currentValue.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
            Expanded(
              child: SfLinearGauge(
                key: UniqueKey(),
                minimum: _minValue,
                maximum: _maxValue,
                labelPosition: LinearLabelPosition.inside,
                tickPosition: LinearElementPosition.cross,
                interval: divisionSeparation,
                axisTrackStyle: const LinearAxisTrackStyle(
                  edgeStyle: LinearEdgeStyle.bothCurve,
                ),
                markerPointers: [
                  LinearShapePointer(
                    value: _currentValue,
                    color: Theme.of(context).colorScheme.primary,
                    height: 15.0,
                    width: 15.0,
                    animationDuration: 0,
                    shapeType: LinearShapePointerType.circle,
                    position: LinearElementPosition.cross,
                    dragBehavior: LinearMarkerDragBehavior.free,
                    onChangeStart: (_) {
                      _dragging = true;
                    },
                    onChanged: (value) {
                      _currentValue = value;

                      if (_updateContinuously) {
                        _publishValue(_currentValue);
                      }
                    },
                    onChangeEnd: (value) {
                      _publishValue(_currentValue);

                      _dragging = false;
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
