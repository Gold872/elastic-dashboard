import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:provider/provider.dart';

class WidgetContainerModel extends ChangeNotifier {
  bool draggable = true;

  void setDraggable(bool draggable) {
    this.draggable = draggable;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}

class DraggableWidgetContainer extends StatelessWidget {
  final DashboardGrid dashboardGrid;

  String? title;

  Rect draggablePositionRect = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());

  Offset cursorGlobalLocation = const Offset(double.nan, double.nan);

  Rect displayRect = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());

  Rect previewRect = Rect.fromLTWH(
      0, 0, Globals.gridSize.toDouble(), Globals.gridSize.toDouble());

  late Rect dragStartLocation;

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
  Function(dynamic widget)? onResizeBegin;
  Function(dynamic widget, Rect releaseRect)? onResizeEnd;

  WidgetContainerModel? model;

  DraggableWidgetContainer({
    super.key,
    required this.dashboardGrid,
    required this.title,
    required Rect initialPosition,
    this.enabled = false,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onResizeBegin,
    this.onResizeEnd,
  }) {
    displayRect = initialPosition;

    init();
  }

  DraggableWidgetContainer.fromJson({
    super.key,
    required this.dashboardGrid,
    required Map<String, dynamic> jsonData,
    this.enabled = false,
    this.onUpdate,
    this.onDragBegin,
    this.onDragEnd,
    this.onResizeBegin,
    this.onResizeEnd,
  }) {
    fromJson(jsonData);

    init();
  }

  static double snapToGrid(double value) {
    if (Globals.snapToGrid) {
      return (value / Globals.gridSize).roundToDouble() * Globals.gridSize;
    } else {
      return value;
    }
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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'x': displayRect.left,
      'y': displayRect.top,
      'width': displayRect.width,
      'height': displayRect.height,
    };
  }

  void init() {
    draggablePositionRect = displayRect;
    dragStartLocation = displayRect;
  }

  @mustCallSuper
  void fromJson(Map<String, dynamic> jsonData) {
    title = tryCast(jsonData['title']) ?? '';

    double x = tryCast(jsonData['x']) ?? 0.0;

    double y = tryCast(jsonData['y']) ?? 0.0;

    double width = tryCast(jsonData['width']) ?? Globals.gridSize.toDouble();

    double height = tryCast(jsonData['height']) ?? Globals.gridSize.toDouble();

    displayRect = Rect.fromLTWH(x, y, width, height);
  }

  void dispose() {}

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
        constraints: BoxConstraints(
          minWidth: Globals.gridSize.toDouble(),
          minHeight: Globals.gridSize.toDouble(),
        ),
        clampingRect:
            const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
        rect: draggablePositionRect,
        resizeModeResolver: () => ResizeMode.freeform,
        allowFlippingWhileResizing: false,
        handleTapSize: 12,
        visibleHandles: const {},
        draggable: model.draggable,
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
          resizing = true;
          dragStartLocation = displayRect;
          onResizeBegin?.call(this);
        },
        onChanged: (result, event) {
          cursorGlobalLocation = event.globalPosition;

          onUpdate?.call(this, result.rect);

          refresh();
        },
        onDragEnd: (event) {
          dragging = false;

          onDragEnd?.call(this, draggablePositionRect,
              globalPosition: cursorGlobalLocation);

          refresh();
        },
        onDragCancel: () {
          dragging = false;

          onDragEnd?.call(this, draggablePositionRect,
              globalPosition: cursorGlobalLocation);

          refresh();
        },
        onResizeEnd: (handle, event) {
          dragging = false;
          resizing = false;

          onResizeEnd?.call(this, draggablePositionRect);

          refresh();
        },
        onResizeCancel: (handle) {
          dragging = false;
          resizing = false;

          onResizeEnd?.call(this, draggablePositionRect);

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
            borderRadius: BorderRadius.circular(Globals.cornerRadius),
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
              borderRadius: BorderRadius.circular(Globals.cornerRadius),
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
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(Globals.cornerRadius),
                          topRight: Radius.circular(Globals.cornerRadius),
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
