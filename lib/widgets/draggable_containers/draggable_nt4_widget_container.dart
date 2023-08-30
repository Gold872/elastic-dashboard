import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../dialog_widgets/dialog_text_input.dart';
import '../nt4_widgets/single_topic/boolean_box.dart';
import '../nt4_widgets/single_topic/graph.dart';
import '../nt4_widgets/nt4_widget.dart';
import '../nt4_widgets/single_topic/number_bar.dart';

class DraggableNT4WidgetContainer extends DraggableWidgetContainer {
  NT4Widget? child;

  DraggableNT4WidgetContainer({
    super.key,
    required super.title,
    required this.child,
    required super.validMoveLocation,
    super.enabled = false,
    super.initialPosition,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();

  DraggableNT4WidgetContainer.fromJson({
    super.key,
    required super.validMoveLocation,
    required super.jsonData,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super.fromJson();

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
      case 'Text Display':
        newWidget = TextDisplay(
            key: UniqueKey(), topic: child!.topic, period: child!.period);
        break;
      case 'Match Time':
        newWidget = MatchTimeWidget(
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

    child!.dispose();
    child = newWidget;

    refresh();
  }

  @override
  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        List<Widget>? childProperties = child?.getEditProperties(context);

        return AlertDialog(
          title: const Text('Edit Properties'),
          content: SizedBox(
            width: 353,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Settings for the widget container
                  const Text('Container Settings'),
                  const SizedBox(height: 5),
                  DialogTextInput(
                    onSubmit: (value) {
                      title = value;

                      refresh();
                    },
                    label: 'Title',
                    initialText: title,
                  ),
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
                          Navigator.of(context).pop();

                          changeChildToType(value);

                          showEditProperties(context);
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

                            child?.period = newPeriod;
                            child?.resetSubscription();
                          },
                          formatter: FilteringTextInputFormatter.allow(
                              RegExp(r"[0-9.]")),
                          label: 'Period',
                          initialText: child!.period.toString(),
                        ),
                      ),
                    ],
                  ),
                ],
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

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': child?.type,
      'properties': getChildJson(),
    };
  }

  @override
  void fromJson(Map<String, dynamic> jsonData) {
    super.fromJson(jsonData);

    child = createChildFromJson(jsonData);
  }

  NT4Widget? createChildFromJson(Map<String, dynamic> jsonData) {
    switch (jsonData['type']) {
      case 'Boolean Box':
        return BooleanBox.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Toggle Switch':
        return ToggleSwitch.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Toggle Button':
        return ToggleButton.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Graph':
        return GraphWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Match Time':
        return MatchTimeWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Number Bar':
        return NumberBar.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Text Display':
        return TextDisplay.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Gyro':
        return Gyro.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Field':
        return FieldWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'PowerDistribution':
        return PowerDistribution.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'PIDController':
        return PIDControllerWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'ComboBox Chooser':
        return ComboBoxChooser.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Split Button Chooser':
        return SplitButtonChooser.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Subsystem':
        return SubsystemWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Command':
        return CommandWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Scheduler':
        return CommandSchedulerWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'FMSInfo':
        return FMSInfo.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
      case 'Camera Stream':
        return CameraStreamWidget.fromJson(
          key: UniqueKey(),
          jsonData: jsonData['properties'],
        );
    }
    return null;
  }

  Map<String, dynamic>? getChildJson() {
    return child!.toJson();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        Positioned(
          left: displayRect.left,
          top: displayRect.top,
          child: WidgetContainer(
            title: title,
            width: displayRect.width,
            height: displayRect.height,
            opacity: (model!.previewVisible) ? 0.25 : 1.00,
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
          ),
        ),
        ...super.getStackChildren(model!),
      ],
    );
  }
}
