import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class BooleanBoxModel extends NTWidgetModel {
  @override
  String type = BooleanBox.widgetType;

  Color _trueColor = Colors.green;
  Color _falseColor = Colors.red;

  static const List<String> _trueIconOptions = [
    'None',
    'Checkmark',
  ];
  static const List<String> _falseIconOptions = [
    'None',
    'X',
    'Exclamation Point',
  ];

  String _trueIcon = 'None';
  String _falseIcon = 'None';

  get trueColor => _trueColor;

  set trueColor(value) {
    _trueColor = value;
    refresh();
  }

  get falseColor => _falseColor;

  set falseColor(value) {
    _falseColor = value;
    refresh();
  }

  String get trueIcon => _trueIcon;

  set trueIcon(value) {
    _trueIcon = value;
    refresh();
  }

  String get falseIcon => _falseIcon;

  set falseIcon(value) {
    _falseIcon = value;
    refresh();
  }

  BooleanBoxModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    Color trueColor = Colors.green,
    Color falseColor = Colors.red,
    String trueIcon = 'None',
    String falseIcon = 'None',
    super.dataType,
    super.period,
  })  : _falseColor = falseColor,
        _trueColor = trueColor,
        _trueIcon = trueIcon,
        _falseIcon = falseIcon,
        super();

  BooleanBoxModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    int? trueColorValue =
        tryCast(jsonData['true_color']) ?? tryCast(jsonData['colorWhenTrue']);
    int? falseColorValue =
        tryCast(jsonData['false_color']) ?? tryCast(jsonData['colorWhenFalse']);

    if (trueColorValue == null) {
      String? hexString = tryCast(jsonData['colorWhenTrue']);

      if (hexString != null) {
        hexString = hexString.toUpperCase().replaceAll('#', '');

        if (hexString.length == 6) {
          hexString = 'FF$hexString';
        }

        trueColorValue = int.tryParse(hexString, radix: 16);
      }
    }

    if (falseColorValue == null) {
      String? hexString = tryCast(jsonData['colorWhenFalse']);

      if (hexString != null) {
        hexString = hexString.toUpperCase().replaceAll('#', '');

        if (hexString.length == 6) {
          hexString = 'FF$hexString';
        }

        falseColorValue = int.tryParse(hexString, radix: 16);
      }
    }

    _trueColor = Color(trueColorValue ?? Colors.green.value);
    _falseColor = Color(falseColorValue ?? Colors.red.value);

    _trueIcon = tryCast(jsonData['true_icon']) ?? 'None';
    _falseIcon = tryCast(jsonData['false_icon']) ?? 'None';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'true_color': _trueColor.value,
      'false_color': _falseColor.value,
      'true_icon': _trueIcon,
      'false_icon': _falseIcon,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          DialogColorPicker(
            onColorPicked: (Color color) {
              trueColor = color;
            },
            label: 'True Color',
            initialColor: _trueColor,
            defaultColor: Colors.green,
          ),
          const SizedBox(width: 10),
          DialogColorPicker(
            onColorPicked: (Color color) {
              falseColor = color;
            },
            label: 'False Color',
            initialColor: _falseColor,
            defaultColor: Colors.red,
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: Column(
              children: [
                const Text('True Icon'),
                DialogDropdownChooser(
                  onSelectionChanged: (value) {
                    trueIcon = value;
                  },
                  choices: _trueIconOptions,
                  initialValue:
                      (_trueIconOptions.contains(_trueIcon)) ? _trueIcon : null,
                ),
              ],
            ),
          ),
          Flexible(
            child: Column(
              children: [
                const Text('False Icon'),
                DialogDropdownChooser(
                  onSelectionChanged: (value) {
                    falseIcon = value;
                  },
                  choices: _falseIconOptions,
                  initialValue: (_falseIconOptions.contains(_falseIcon))
                      ? _falseIcon
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }
}

class BooleanBox extends NTWidget {
  static const String widgetType = 'Boolean Box';

  const BooleanBox({super.key});

  @override
  Widget build(BuildContext context) {
    BooleanBoxModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.subscription?.periodicStream(yieldAll: false),
      initialData: model.ntConnection.getLastAnnouncedValue(model.topic),
      builder: (context, snapshot) {
        bool value = tryCast(snapshot.data) ?? false;

        Widget defaultWidget() => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15.0),
                color: (value) ? model.trueColor : model.falseColor,
              ),
            );

        Widget? widgetToDisplay;
        if (value && model.trueIcon.toUpperCase() != 'NONE') {
          switch (model.trueIcon.toUpperCase()) {
            case 'CHECKMARK':
              widgetToDisplay = SizedBox.expand(
                child: FittedBox(
                  child: Icon(Icons.check, color: model.trueColor),
                ),
              );
              break;
          }
        } else if (!value && model.falseIcon.toUpperCase() != 'NONE') {
          switch (model.falseIcon.toUpperCase()) {
            case 'X':
              widgetToDisplay = SizedBox.expand(
                child: FittedBox(
                  child: Icon(Icons.clear, color: model.falseColor),
                ),
              );
              break;
            case 'EXCLAMATION POINT':
              widgetToDisplay = SizedBox.expand(
                child: FittedBox(
                  child: Icon(Icons.priority_high, color: model.falseColor),
                ),
              );
              break;
          }
        }

        return widgetToDisplay ?? defaultWidget();

        // return Container(
        //   decoration: BoxDecoration(
        //     borderRadius: BorderRadius.circular(15.0),
        //     color: (value) ? model.trueColor : model.falseColor,
        //   ),
        // );
      },
    );
  }
}
