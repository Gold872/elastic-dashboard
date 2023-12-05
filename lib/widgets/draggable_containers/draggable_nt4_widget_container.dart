import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_widget_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/voltage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../dialog_widgets/dialog_text_input.dart';
import '../nt4_widgets/single_topic/boolean_box.dart';
import '../nt4_widgets/single_topic/graph.dart';
import '../nt4_widgets/nt4_widget.dart';
import '../nt4_widgets/single_topic/number_slider.dart';

class DraggableNT4WidgetContainer extends DraggableWidgetContainer {
  NT4Widget? child;

  DraggableNT4WidgetContainer({
    super.key,
    required super.dashboardGrid,
    required super.title,
    required super.initialPosition,
    required this.child,
    super.enabled = false,
    super.minWidth,
    super.minHeight,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();

  DraggableNT4WidgetContainer.fromJson({
    super.key,
    required super.dashboardGrid,
    required super.jsonData,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
    super.onJsonLoadingWarning,
  }) : super.fromJson();

  @override
  void init() {
    super.init();

    minWidth = NT4WidgetBuilder.getMinimumWidth(child);
    minHeight = NT4WidgetBuilder.getMinimumHeight(child);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': child?.type,
      'properties': getChildJson(),
    };
  }

  @override
  void fromJson(Map<String, dynamic> jsonData,
      {Function(String errorMessage)? onJsonLoadingWarning}) {
    super.fromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);

    if (!jsonData.containsKey('type')) {
      onJsonLoadingWarning?.call(
          'NetworkTables widget does not specify a widget type, defaulting to text display widget');
    }

    Map<String, dynamic> widgetProperties = {};

    if (jsonData.containsKey('properties')) {
      widgetProperties = tryCast(jsonData['properties']) ?? {};
    } else {
      onJsonLoadingWarning?.call(
          'Network tables widget does not have any properties, defaulting to an empty properties map.');
    }

    String type = tryCast(jsonData['type']) ?? '';

    child = NT4WidgetBuilder.buildNT4WidgetFromJson(type, widgetProperties,
        onWidgetTypeNotFound: onJsonLoadingWarning);
  }

  void refreshChild() {
    child?.refresh();
  }

  @override
  void dispose({bool deleting = false}) {
    super.dispose(deleting: deleting);

    child?.dispose(deleting: deleting);
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    child?.unSubscribe();
  }

  Map<String, dynamic>? getChildJson() {
    return child!.toJson();
  }

  void changeChildToType(String? type) {
    if (type == null) {
      return;
    }

    if (type == child!.type) {
      return;
    }

    NT4Widget? newWidget;

    switch (type) {
      case 'Boolean Box':
        newWidget = BooleanBox(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Toggle Switch':
        newWidget = ToggleSwitch(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Toggle Button':
        newWidget = ToggleButton(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Graph':
        newWidget = GraphWidget(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Number Bar':
        newWidget = NumberBar(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Number Slider':
        newWidget = NumberSlider(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Voltage View':
        newWidget = VoltageView(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Text Display':
        newWidget = TextDisplay(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Match Time':
        newWidget = MatchTimeWidget(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Single Color View':
        newWidget = SingleColorView(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Multi Color View':
        newWidget = MultiColorView(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'ComboBox Chooser':
        newWidget = ComboBoxChooser(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
      case 'Split Button Chooser':
        newWidget = SplitButtonChooser(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
    }

    if (newWidget == null) {
      return;
    }

    child!.dispose(deleting: true);
    child!.unSubscribe();
    child = newWidget;

    minWidth = NT4WidgetBuilder.getMinimumWidth(child);
    minHeight = NT4WidgetBuilder.getMinimumHeight(child);

    refresh();
  }

  @override
  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Properties'),
          content: SizedBox(
            width: 353,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  List<Widget>? childProperties =
                      child?.getEditProperties(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...getContainerEditProperties(),
                      const SizedBox(height: 5),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Text('Widget Type')),
                          DialogDropdownChooser<String>(
                            choices: child!.getAvailableDisplayTypes(),
                            initialValue: child!.type,
                            onSelectionChanged: (String? value) {
                              setState(() {
                                changeChildToType(value);
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      // Settings for the widget inside (only if there are properties)
                      if (childProperties != null &&
                          childProperties.isNotEmpty) ...[
                        Text('${child?.type} Widget Settings'),
                        const SizedBox(height: 5),
                        ...childProperties,
                        const Divider(),
                      ],
                      // Settings for the NT4 Connection
                      ...getNT4EditProperties(),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                child?.refresh();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> getNT4EditProperties() {
    return [
      const Text('Network Tables Settings (Advanced)'),
      const SizedBox(height: 5),
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Topic
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                child?.topic = value;
                child?.resetSubscription();
              },
              label: 'Topic',
              initialText: child?.topic,
            ),
          ),
          const SizedBox(width: 5),
          // Period
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newPeriod = double.tryParse(value);
                if (newPeriod == null) {
                  return;
                }

                child!.period = newPeriod;
                child!.resetSubscription();
              },
              formatter: FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
              label: 'Period',
              initialText: child!.period.toString(),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  WidgetContainer getDraggingWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: draggablePositionRect.width,
      height: draggablePositionRect.height,
      opacity: 0.80,
      child: ChangeNotifierProvider(
        create: (context) => NT4WidgetNotifier(),
        child: child,
      ),
    );
  }

  @override
  WidgetContainer getWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: displayRect.width,
      height: displayRect.height,
      opacity: (previewVisible) ? 0.25 : 1.00,
      child: Opacity(
        opacity: (enabled) ? 1.00 : 0.50,
        child: AbsorbPointer(
          absorbing: !enabled,
          child: ChangeNotifierProvider(
            create: (context) => NT4WidgetNotifier(),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        Positioned(
          left: displayRect.left,
          top: displayRect.top,
          child: getWidgetContainer(context),
        ),
        ...super.getStackChildren(model!),
      ],
    );
  }
}
