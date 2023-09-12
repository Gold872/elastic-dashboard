import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:provider/provider.dart';

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
  Function(dynamic widget)? onUpdate;
  Function(dynamic widget)? onDragBegin;
  Function(dynamic widget)? onDragEnd;
  Function(dynamic widget)? onResizeBegin;
  Function(dynamic widget)? onResizeEnd;

  WidgetContainerModel? model;

  DraggableWidgetContainer({
    super.key,
    required this.title,
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
                ],
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
    ];
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
