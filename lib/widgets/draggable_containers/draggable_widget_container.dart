import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

class WidgetContainerModel extends ChangeNotifier {
  bool draggable = true;
  bool _disposed = false;

  void setDraggable(bool draggable) {
    this.draggable = draggable;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DraggableWidgetContainer extends StatelessWidget {
  final TabGrid tabGrid;

  String? title;

  Rect draggablePositionRect = Rect.fromLTWH(
      0, 0, Settings.gridSize.toDouble(), Settings.gridSize.toDouble());

  Offset cursorGlobalLocation = const Offset(double.nan, double.nan);

  Rect displayRect = Rect.fromLTWH(
      0, 0, Settings.gridSize.toDouble(), Settings.gridSize.toDouble());

  Rect previewRect = Rect.fromLTWH(
      0, 0, Settings.gridSize.toDouble(), Settings.gridSize.toDouble());

  late Rect dragStartLocation;

  TransformableBoxController? controller;

  double? minWidth;
  double? minHeight;

  bool enabled = false;
  bool dragging = false;
  bool resizing = false;
  bool draggingIntoLayout = false;
  bool previewVisible = false;
  bool validLocation = true;

  Function(dynamic widget, Rect newRect)? onUpdate;
  Function(dynamic widget)? onDragBegin;
  Function(dynamic widget, Rect releaseRect, {Offset? globalPosition})?
      onDragEnd;
  Function(dynamic widget)? onDragCancel;
  Function(dynamic widget)? onResizeBegin;
  Function(dynamic widget, Rect releaseRect)? onResizeEnd;

  WidgetContainerModel? model;

  DraggableWidgetContainer({
    super.key,
    required this.tabGrid,
    required this.title,
    required Rect initialPosition,
    this.enabled = false,
    this.minWidth = 128,
    this.minHeight = 128,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onDragCancel,
    this.onResizeBegin,
    this.onResizeEnd,
  }) {
    displayRect = initialPosition;

    init();
  }

  DraggableWidgetContainer.fromJson({
    super.key,
    required this.tabGrid,
    required Map<String, dynamic> jsonData,
    this.enabled = false,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onDragCancel,
    this.onResizeBegin,
    this.onResizeEnd,
    Function(String errorMessage)? onJsonLoadingWarning,
  }) {
    fromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);

    init();
  }

  static double snapToGrid(double value) {
    return (value / Settings.gridSize).roundToDouble() * Settings.gridSize;
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
          title = value;

          refresh();
        },
        label: 'Title',
        initialText: title,
      ),
    ];
  }

  List<ContextMenuEntry> getContextMenuItems() {
    return [];
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
  void init() {
    draggablePositionRect = displayRect;
    dragStartLocation = displayRect;
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

  void dispose({bool deleting = false}) {}

  void unSubscribe() {}

  @mustCallSuper
  void setEnabled(bool enabled) {
    this.enabled = enabled;

    refresh();
  }

  WidgetContainer getDraggingWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: draggablePositionRect.width,
      height: draggablePositionRect.height,
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

  List<Widget> getStackChildren(WidgetContainerModel model) {
    return [
      TransformableBox(
        handleAlignment: HandleAlignment.inside,
        rect: draggablePositionRect,
        clampingRect:
            const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
        constraints: BoxConstraints(
          minWidth: minWidth ?? Settings.gridSize.toDouble(),
          minHeight: minHeight ?? Settings.gridSize.toDouble(),
        ),
        resizeModeResolver: () => ResizeMode.freeform,
        allowFlippingWhileResizing: false,
        handleTapSize: 12,
        visibleHandles: const {},
        draggable: model.draggable,
        resizable: model.draggable,
        contentBuilder: (BuildContext context, Rect rect, Flip flip) {
          return Builder(builder: (context) {
            controller = TransformableBox.controllerOf(context);

            return Container();
          });
        },
        onDragStart: (event) {
          dragging = true;
          dragStartLocation = displayRect;
          onDragBegin?.call(this);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
        onResizeStart: (handle, event) {
          dragging = true;
          resizing = true;
          dragStartLocation = displayRect;
          onResizeBegin?.call(this);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
        onChanged: (result, event) {
          if (!dragging && !resizing) {
            onDragCancel?.call(this);

            controller?.setRect(draggablePositionRect);
            refresh();
            return;
          }

          cursorGlobalLocation = event.globalPosition;

          onUpdate?.call(this, result.rect);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
        onDragEnd: (event) {
          if (!dragging) {
            return;
          }
          dragging = false;

          onDragEnd?.call(this, draggablePositionRect,
              globalPosition: cursorGlobalLocation);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
        onDragCancel: () {
          dragging = false;

          onDragCancel?.call(this);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
        onResizeEnd: (handle, event) {
          if (!dragging && !resizing) {
            return;
          }
          dragging = false;
          resizing = false;

          onResizeEnd?.call(this, draggablePositionRect);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
        onResizeCancel: (handle) {
          dragging = false;
          resizing = false;

          onDragCancel?.call(this);

          controller?.setRect(draggablePositionRect);
          refresh();
        },
      ),
    ];
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

  @override
  Widget build(BuildContext context) {
    WidgetContainerModel model = context.watch<WidgetContainerModel>();

    this.model = model;

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
