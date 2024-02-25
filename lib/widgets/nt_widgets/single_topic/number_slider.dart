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

class NumberSliderModel extends NTWidgetModel {
  @override
  String type = NumberSlider.widgetType;

  double _minValue = -1.0;
  double _maxValue = 1.0;
  int _divisions = 5;
  bool _updateContinuously = false;

  double _currentValue = 0.0;

  bool _dragging = false;

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

  int get divisions => _divisions;

  set divisions(value) {
    _divisions = value;
    refresh();
  }

  bool get updateContinuously => _updateContinuously;

  set updateContinuously(value) => _updateContinuously = value;

  double get currentValue => _currentValue;

  set currentValue(value) => _currentValue = value;

  bool get dragging => _dragging;

  set dragging(value) => _dragging = value;

  NumberSliderModel({
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

  NumberSliderModel.fromJson({required Map<String, dynamic> jsonData})
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
                minValue = newMin;
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
                maxValue = newMax;
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
                divisions = newDivisions;
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
                updateContinuously = value;
              },
            ),
          ),
        ],
      ),
    ];
  }

  void publishValue(double value) {
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
}

class NumberSlider extends NTWidget {
  static const String widgetType = 'Number Slider';

  const NumberSlider({super.key});

  @override
  Widget build(BuildContext context) {
    NumberSliderModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.subscription?.periodicStream(),
      initialData: ntConnection.getLastAnnouncedValue(model.topic),
      builder: (context, snapshot) {
        double value = tryCast(snapshot.data) ?? 0.0;

        double clampedValue = value.clamp(model.minValue, model.maxValue);

        if (!model.dragging) {
          model.currentValue = clampedValue;
        }

        double divisionSeparation =
            (model.maxValue - model.minValue) / (model.divisions - 1);

        return Column(
          children: [
            Text(
              model.currentValue.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
            Expanded(
              child: SfLinearGauge(
                key: UniqueKey(),
                minimum: model.minValue,
                maximum: model.maxValue,
                labelPosition: LinearLabelPosition.inside,
                tickPosition: LinearElementPosition.cross,
                interval: divisionSeparation,
                axisTrackStyle: const LinearAxisTrackStyle(
                  edgeStyle: LinearEdgeStyle.bothCurve,
                ),
                markerPointers: [
                  LinearShapePointer(
                    value: model.currentValue,
                    color: Theme.of(context).colorScheme.primary,
                    height: 15.0,
                    width: 15.0,
                    animationDuration: 0,
                    shapeType: LinearShapePointerType.circle,
                    position: LinearElementPosition.cross,
                    dragBehavior: LinearMarkerDragBehavior.free,
                    onChangeStart: (_) {
                      model.dragging = true;
                    },
                    onChanged: (value) {
                      model.currentValue = value;

                      if (model.updateContinuously) {
                        model.publishValue(model.currentValue);
                      }
                    },
                    onChangeEnd: (value) {
                      model.publishValue(model.currentValue);

                      model.dragging = false;
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
