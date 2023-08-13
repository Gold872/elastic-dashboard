import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:provider/provider.dart';

import '../services/globals.dart';
import 'dialog_widgets/dialog_text_input.dart';
import 'nt4_widgets/single_topic/boolean_box.dart';
import 'nt4_widgets/single_topic/graph.dart';
import 'nt4_widgets/nt4_widget.dart';
import 'nt4_widgets/single_topic/number_bar.dart';

class WidgetContainerModel extends ChangeNotifier {
  Rect rect = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());
  Rect preview = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());
  bool previewVisible = false;
  bool validLocation = true;

  void setDraggableRect(Rect newRect) {
    rect = newRect;
    notifyListeners();
  }

  void setPreview(Rect newPreview) {
    preview = newPreview;
    notifyListeners();
  }

  void setPreviewVisible(bool visible) {
    previewVisible = visible;
    notifyListeners();
  }

  void setValidLocation(bool valid) {
    validLocation = valid;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}

class DraggableWidgetContainer extends StatelessWidget {
  String? title;

  NT4Widget? child;

  Rect? initialPosition;

  Rect draggablePositionRect = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());

  Rect displayRect = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());

  late Rect dragStartLocation;

  bool enabled = false;
  bool dragging = false;

  Map<String, dynamic>? jsonData = {};

  bool Function(DraggableWidgetContainer widget, Rect location)
      validMoveLocation;
  Function(DraggableWidgetContainer widget)? onUpdate;
  Function(DraggableWidgetContainer widget)? onDragBegin;
  Function(DraggableWidgetContainer widget)? onDragEnd;
  Function(DraggableWidgetContainer widget)? onResizeBegin;
  Function(DraggableWidgetContainer widget)? onResizeEnd;

  WidgetContainerModel? model;

  DraggableWidgetContainer({
    super.key,
    required this.title,
    required this.child,
    required this.validMoveLocation,
    this.enabled = false,
    this.initialPosition,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onResizeBegin,
    this.onResizeEnd,
  }) {
    init();
  }

  DraggableWidgetContainer.fromJson({
    super.key,
    required this.validMoveLocation,
    required this.jsonData,
    this.enabled = false,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onResizeBegin,
    this.onResizeEnd,
  }) {
    init();
  }

  static double snapToGrid(double value) {
    if (Globals.snapToGrid) {
      return (value / Globals.gridSize).roundToDouble() * Globals.gridSize;
    } else {
      return value;
    }
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

  void refresh() {
    Future(() async {
      model?.refresh();
    });
  }

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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'x': displayRect.left,
      'y': displayRect.top,
      'width': displayRect.width,
      'height': displayRect.height,
      'type': child?.type,
      'properties': getChildJson(),
    };
  }

  void init() {
    if (title == null) {
      fromJson(jsonData!);
    } else {
      displayRect = initialPosition!;
    }

    draggablePositionRect = displayRect;
    dragStartLocation = displayRect;
  }

  void fromJson(Map<String, dynamic> jsonData) {
    title = jsonData['title'];

    double x = jsonData['x'];

    double y = jsonData['y'];

    double width = jsonData['width'];

    double height = jsonData['height'];

    displayRect = Rect.fromLTWH(x, y, width, height);

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
    WidgetContainerModel model = context.watch<WidgetContainerModel>();

    this.model = model;

    return Stack(
      children: [
        // Positioned(
        //   left: model.preview.left,
        //   top: model.preview.top,
        //   width: model.preview.width,
        //   height: model.preview.height,
        //   child: Visibility(
        //     visible: model.previewVisible,
        //     child: Container(
        //       decoration: BoxDecoration(
        //         color: (model.validLocation)
        //             ? Colors.white.withOpacity(0.25)
        //             : Colors.black.withOpacity(0.1),
        //         borderRadius: BorderRadius.circular(25.0),
        //         border: Border.all(
        //             color: (model.validLocation)
        //                 ? Colors.lightGreenAccent.shade400
        //                 : Colors.red,
        //             width: 5.0),
        //       ),
        //     ),
        //   ),
        // ),
        Positioned(
          left: displayRect.left,
          top: displayRect.top,
          child: WidgetContainer(
            title: title,
            width: displayRect.width,
            height: displayRect.height,
            opacity: (model.previewVisible) ? 0.25 : 1.00,
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
        TransformableBox(
          handleAlignment: HandleAlignment.inside,
          constraints: BoxConstraints(
            minWidth: Globals.gridSize.toDouble(),
            minHeight: Globals.gridSize.toDouble(),
          ),
          clampingRect:
              const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
          rect: draggablePositionRect,
          resizeModeResolver: () => ResizeMode.freeform,
          allowFlippingWhileResizing: false,
          visibleHandles: const {},
          contentBuilder: (BuildContext context, Rect rect, Flip flip) {
            return Container();
          },
          onDragStart: (event) {
            dragging = true;
            dragStartLocation = displayRect;
            onDragBegin?.call(this);
          },
          onResizeStart: (handle, event) {
            dragging = true;
            dragStartLocation = displayRect;
            onResizeBegin?.call(this);
          },
          onChanged: (result, event) {
            Rect newRect = result.rect;

            double newX = snapToGrid(newRect.left);
            double newY = snapToGrid(newRect.top);

            double newWidth = snapToGrid(newRect.width);
            double newHeight = snapToGrid(newRect.height);

            if (newWidth < Globals.gridSize) {
              newWidth = Globals.gridSize.toDouble();
            }

            if (newHeight < Globals.gridSize) {
              newHeight = Globals.gridSize.toDouble();
            }

            Rect preview = Rect.fromLTWH(
                newX, newY, newWidth.toDouble(), newHeight.toDouble());
            draggablePositionRect = result.rect;

            model.setPreview(preview);
            model.setDraggableRect(draggablePositionRect);
            model.setPreviewVisible(true);
            model.setValidLocation(validMoveLocation.call(this, preview));

            onUpdate?.call(this);
          },
          onDragEnd: (event) {
            dragging = false;
            if (model.validLocation) {
              draggablePositionRect = model.preview;
            } else {
              draggablePositionRect = dragStartLocation;
            }

            displayRect = draggablePositionRect;

            model.setPreview(draggablePositionRect);
            model.setPreviewVisible(false);
            model.setValidLocation(true);

            onDragEnd?.call(this);
          },
          onDragCancel: () {
            dragging = false;
            if (model.validLocation) {
              draggablePositionRect = model.preview;
            } else {
              draggablePositionRect = dragStartLocation;
            }

            displayRect = draggablePositionRect;

            model.setPreview(draggablePositionRect);
            model.setPreviewVisible(false);
            model.setValidLocation(true);

            onDragEnd?.call(this);
          },
          onResizeEnd: (handle, event) {
            dragging = false;
            if (model.validLocation) {
              draggablePositionRect = model.preview;
            } else {
              draggablePositionRect = dragStartLocation;
            }

            displayRect = draggablePositionRect;

            model.setPreview(draggablePositionRect);
            model.setPreviewVisible(false);
            model.setValidLocation(true);

            onResizeEnd?.call(this);
          },
          onResizeCancel: (handle) {
            dragging = false;
            if (model.validLocation) {
              draggablePositionRect = model.preview;
            } else {
              draggablePositionRect = dragStartLocation;
            }

            displayRect = draggablePositionRect;

            model.setPreview(draggablePositionRect);
            model.setPreviewVisible(false);
            model.setValidLocation(true);

            onResizeEnd?.call(this);
          },
        ),
      ],
    );
  }
}

class WidgetContainer extends StatelessWidget {
  const WidgetContainer({
    super.key,
    required this.title,
    required this.child,
    required this.width,
    required this.height,
    this.opacity = 1.0,
  });

  final double opacity;
  final String? title;
  final Widget? child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Opacity(
          opacity: opacity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              color: const Color.fromARGB(255, 40, 40, 40),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(2, 2),
                  blurRadius: 10.5,
                  spreadRadius: 0,
                  color: Colors.black,
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  // Title
                  LayoutBuilder(builder: (context, constraints) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25.0),
                          topRight: Radius.circular(25.0),
                        ),
                        color: theme.colorScheme.primaryContainer,
                      ),
                      width: constraints.maxWidth,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          title!,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    );
                  }),
                  // The child widget
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          top: 5.0, left: 10.0, right: 10.0, bottom: 10.0),
                      child: Container(
                        alignment: Alignment.center,
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
