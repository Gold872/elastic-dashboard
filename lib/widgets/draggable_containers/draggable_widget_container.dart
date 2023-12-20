import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

abstract class WidgetContainerModel extends ChangeNotifier {
  final Key key = UniqueKey();

  String? title;

  bool draggable = true;
  bool _disposed = false;

  Rect draggingRect = Rect.fromLTWH(
      0, 0, Settings.gridSize.toDouble(), Settings.gridSize.toDouble());

  Offset cursorGlobalLocation = const Offset(double.nan, double.nan);

  Rect displayRect = Rect.fromLTWH(
      0, 0, Settings.gridSize.toDouble(), Settings.gridSize.toDouble());

  Rect previewRect = Rect.fromLTWH(
      0, 0, Settings.gridSize.toDouble(), Settings.gridSize.toDouble());

  bool enabled = false;
  bool dragging = false;
  bool resizing = false;
  bool draggingIntoLayout = false;
  bool previewVisible = false;
  bool validLocation = true;

  double minWidth = Settings.gridSize.toDouble();
  double minHeight = Settings.gridSize.toDouble();

  late Rect dragStartLocation;

  WidgetContainerModel({
    required Rect initialPosition,
    required this.title,
    this.minWidth = 128.0,
    this.minHeight = 128.0,
  }) {
    displayRect = initialPosition;
    init();
  }

  WidgetContainerModel.fromJson({
    required Map<String, dynamic> jsonData,
    this.enabled = false,
    this.minWidth = 128.0,
    this.minHeight = 128.0,
    Function(String errorMessage)? onJsonLoadingWarning,
  }) {
    fromJson(jsonData);
    init();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (!hasListeners) {
      super.dispose();
      _disposed = true;
    }
  }

  void init() {
    draggingRect = displayRect;
    dragStartLocation = displayRect;
  }

  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'x': displayRect.left,
      'y': displayRect.top,
      'width': displayRect.width,
      'height': displayRect.height,
    };
  }

  @mustCallSuper
  void fromJson(Map<String, dynamic> jsonData,
      {Function(String warningMessage)? onJsonLoadingWarning}) {
    title = tryCast(jsonData['title']) ?? '';

    double x = tryCast(jsonData['x']) ?? 0.0;

    double y = tryCast(jsonData['y']) ?? 0.0;

    double width = tryCast(jsonData['width']) ?? Settings.gridSize.toDouble();

    double height = tryCast(jsonData['height']) ?? Settings.gridSize.toDouble();

    displayRect = Rect.fromLTWH(x, y, width, height);
  }

  List<ContextMenuEntry> getContextMenuItems() {
    return [];
  }

  void disposeModel({bool deleting = false}) {}

  void unSubscribe() {}

  void setTitle(String title) {
    this.title = title;

    notifyListeners();
  }

  void setDraggable(bool draggable) {
    this.draggable = draggable;
    notifyListeners();
  }

  void setDragging(bool dragging) {
    this.dragging = dragging;
    notifyListeners();
  }

  void setResizing(bool resizing) {
    this.resizing = resizing;
    notifyListeners();
  }

  void setPreviewVisible(bool previewVisible) {
    this.previewVisible = previewVisible;
    notifyListeners();
  }

  void setValidLocation(bool validLocation) {
    this.validLocation = validLocation;
    notifyListeners();
  }

  void setDraggingIntoLayout(bool draggingIntoLayout) {
    this.draggingIntoLayout = draggingIntoLayout;
    notifyListeners();
  }

  void setEnabled(bool enabled) {
    this.enabled = enabled;
    notifyListeners();
  }

  void setDisplayRect(Rect displayRect) {
    this.displayRect = displayRect;
    notifyListeners();
  }

  void setDraggingRect(Rect draggingRect) {
    this.draggingRect = draggingRect;
    notifyListeners();
  }

  void setPreviewRect(Rect previewRect) {
    this.previewRect = previewRect;
    notifyListeners();
  }

  void setDragStartLocation(Rect dragStartLocation) {
    this.dragStartLocation = dragStartLocation;
    notifyListeners();
  }

  void setCursorGlobalLocation(Offset globalLocation) {
    cursorGlobalLocation = globalLocation;
    notifyListeners();
  }

  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Properties'),
          content: SizedBox(
            width: 353,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: getContainerEditProperties(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> getContainerEditProperties() {
    return [
      // Settings for the widget container
      const Text('Container Settings'),
      const SizedBox(height: 5),
      DialogTextInput(
        onSubmit: (value) {
          setTitle(value);
        },
        label: 'Title',
        initialText: title,
      ),
    ];
  }

  WidgetContainer getDraggingWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: draggingRect.width,
      height: draggingRect.height,
      opacity: 0.80,
      child: Container(),
    );
  }

  WidgetContainer getWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: displayRect.width,
      height: displayRect.height,
      child: Container(),
    );
  }

  Widget getDefaultPreview() {
    return Positioned(
      left: previewRect.left,
      top: previewRect.top,
      width: previewRect.width,
      height: previewRect.height,
      child: Visibility(
        visible: previewVisible,
        child: Container(
          decoration: BoxDecoration(
            color: (validLocation)
                ? Colors.white.withOpacity(0.25)
                : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(Settings.cornerRadius),
            border: Border.all(
                color: (validLocation)
                    ? Colors.lightGreenAccent.shade400
                    : Colors.red,
                width: 5.0),
          ),
        ),
      ),
    );
  }
}

class DraggableWidgetContainer extends StatelessWidget {
  final TabGrid tabGrid;

  final Function(
          WidgetContainerModel widget, Rect newRect, TransformResult result)?
      onUpdate;
  final Function(WidgetContainerModel widget)? onDragBegin;
  final Function(WidgetContainerModel widget, Rect releaseRect,
      {Offset? globalPosition})? onDragEnd;
  final Function(WidgetContainerModel widget)? onDragCancel;
  final Function(WidgetContainerModel widget)? onResizeBegin;
  final Function(WidgetContainerModel widget, Rect releaseRect)? onResizeEnd;

  const DraggableWidgetContainer({
    super.key,
    required this.tabGrid,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onDragCancel,
    this.onResizeBegin,
    this.onResizeEnd,
  });

  static double snapToGrid(double value) {
    return (value / Settings.gridSize).roundToDouble() * Settings.gridSize;
  }

  List<Widget> getStackChildren(WidgetContainerModel model) {
    return [
      TransformableBox(
        handleAlignment: HandleAlignment.inside,
        rect: model.draggingRect,
        clampingRect:
            const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
        constraints: const BoxConstraints(
          minWidth: 128.0,
          minHeight: 128.0,
        ),
        resizeModeResolver: () => ResizeMode.freeform,
        allowFlippingWhileResizing: false,
        handleTapSize: 12,
        visibleHandles: const {},
        draggable: model.draggable,
        resizable: model.draggable,
        contentBuilder: (BuildContext context, Rect rect, Flip flip) {
          return Container();
        },
        onDragStart: (event) {
          model.setDragging(true);
          model.setPreviewVisible(true);
          model.setDraggingIntoLayout(false);
          model.setDragStartLocation(model.displayRect);
          model.setPreviewRect(model.dragStartLocation);
          model.setValidLocation(
              tabGrid.isValidMoveLocation(model, model.previewRect));

          onDragBegin?.call(model);
        },
        onResizeStart: (handle, event) {
          model.setDragging(true);
          model.setResizing(true);
          model.setPreviewVisible(true);
          model.setDraggingIntoLayout(false);
          model.setDragStartLocation(model.displayRect);
          model.setPreviewRect(model.dragStartLocation);
          model.setValidLocation(
              tabGrid.isValidMoveLocation(model, model.previewRect));

          onResizeBegin?.call(model);
        },
        onChanged: (result, event) {
          if (!model.dragging && !model.resizing) {
            onDragCancel?.call(model);
            return;
          }

          model.setCursorGlobalLocation(event.globalPosition);

          onUpdate?.call(model, result.rect, result);
        },
        onDragEnd: (event) {
          if (!model.dragging) {
            return;
          }
          model.setDragging(false);

          onDragEnd?.call(model, model.draggingRect,
              globalPosition: model.cursorGlobalLocation);
        },
        onDragCancel: () {
          Future(() {
            model.setDragging(false);
          });

          onDragCancel?.call(model);
        },
        onResizeEnd: (handle, event) {
          if (!model.dragging && !model.resizing) {
            return;
          }
          model.setDragging(false);
          model.setResizing(false);

          onResizeEnd?.call(model, model.draggingRect);
        },
        onResizeCancel: (handle) {
          model.setDragging(false);
          model.setResizing(false);

          onDragCancel?.call(model);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    WidgetContainerModel model = context.read<WidgetContainerModel>();

    return Stack(
      children: getStackChildren(model),
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
    this.horizontalPadding = 10.0,
    this.verticalPadding = 10.0,
  });

  final double opacity;
  final String? title;
  final Widget? child;
  final double width;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;

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
              borderRadius: BorderRadius.circular(Settings.cornerRadius),
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(Settings.cornerRadius),
                            topRight: Radius.circular(Settings.cornerRadius),
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
                    },
                  ),
                  // The child widget
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: verticalPadding / 2,
                        left: horizontalPadding,
                        right: horizontalPadding,
                        bottom: verticalPadding,
                      ),
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
