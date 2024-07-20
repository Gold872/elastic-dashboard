import 'package:flutter/material.dart';

import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'models/widget_container_model.dart';

typedef DraggableContainerUpdateFunctions = ({
  Function(WidgetContainerModel widget, Rect newRect,
      TransformResult result) onUpdate,
  Function(WidgetContainerModel widget) onDragBegin,
  Function(WidgetContainerModel widget, Rect releaseRect,
      {Offset? globalPosition}) onDragEnd,
  Function(WidgetContainerModel widget) onDragCancel,
  Function(WidgetContainerModel widget) onResizeBegin,
  Function(WidgetContainerModel widget, Rect releaseRect) onResizeEnd,
  bool Function(WidgetContainerModel widget, Rect location) isValidMoveLocation,
});

class DraggableWidgetContainer extends StatelessWidget {
  final DraggableContainerUpdateFunctions? updateFunctions;

  const DraggableWidgetContainer({
    super.key,
    this.updateFunctions,
  });

  static double snapToGrid(double value, [int? gridSize]) {
    gridSize ??= Defaults.gridSize;
    return (value / gridSize).roundToDouble() * gridSize;
  }

  List<Widget> getStackChildren(WidgetContainerModel model) {
    TransformableBoxController? controller;
    return [
      TransformableBox(
        handleAlignment: HandleAlignment.inside,
        rect: model.draggingRect,
        clampingRect:
            const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
        resizeModeResolver: () => ResizeMode.freeform,
        allowFlippingWhileResizing: false,
        handleTapSize: 12,
        visibleHandles: const {},
        draggable: model.draggable,
        resizable: model.draggable,
        contentBuilder: (BuildContext context, Rect rect, Flip flip) {
          return Builder(
            builder: (context) {
              controller = TransformableBox.controllerOf(context);
              return Container();
            },
          );
        },
        onDragStart: (event) {
          model.setDragging(true);
          model.setPreviewVisible(true);
          model.setDraggingIntoLayout(false);
          model.setDragStartLocation(model.displayRect);
          model.setPreviewRect(model.dragStartLocation);
          model.setValidLocation(
              updateFunctions?.isValidMoveLocation(model, model.previewRect) ??
                  true);

          updateFunctions?.onDragBegin(model);

          controller?.setRect(model.draggingRect);
        },
        onResizeStart: (handle, event) {
          model.setDragging(true);
          model.setResizing(true);
          model.setPreviewVisible(true);
          model.setDraggingIntoLayout(false);
          model.setDragStartLocation(model.displayRect);
          model.setPreviewRect(model.dragStartLocation);
          model.setValidLocation(
              updateFunctions?.isValidMoveLocation(model, model.previewRect) ??
                  true);

          updateFunctions?.onResizeBegin.call(model);

          controller?.setRect(model.draggingRect);
        },
        onChanged: (result, event) {
          if (!model.dragging && !model.resizing) {
            updateFunctions?.onDragCancel(model);
            return;
          }

          model.setCursorGlobalLocation(event.globalPosition);

          updateFunctions?.onUpdate(model, result.rect, result);

          controller?.setRect(model.draggingRect);
        },
        onDragEnd: (event) {
          if (!model.dragging) {
            return;
          }
          model.setDragging(false);

          updateFunctions?.onDragEnd(model, model.draggingRect,
              globalPosition: model.cursorGlobalLocation);

          controller?.setRect(model.draggingRect);
        },
        onDragCancel: () {
          Future(() {
            model.setDragging(false);
          });

          updateFunctions?.onDragCancel(model);

          controller?.setRect(model.draggingRect);
        },
        onResizeEnd: (handle, event) {
          if (!model.dragging && !model.resizing) {
            return;
          }
          model.setDragging(false);
          model.setResizing(false);

          updateFunctions?.onResizeEnd(model, model.draggingRect);

          controller?.setRect(model.draggingRect);
        },
        onResizeCancel: (handle) {
          model.setDragging(false);
          model.setResizing(false);

          updateFunctions?.onDragCancel(model);

          controller?.setRect(model.draggingRect);
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
    this.horizontalPadding = 7.5,
    this.verticalPadding = 7.5,
    this.cornerRadius = Defaults.cornerRadius,
  });

  final double opacity;
  final String? title;
  final Widget? child;
  final double width;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double cornerRadius;

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
              borderRadius: BorderRadius.circular(cornerRadius),
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
                            topLeft: Radius.circular(cornerRadius),
                            topRight: Radius.circular(cornerRadius),
                          ),
                          color: theme.colorScheme.primaryContainer,
                        ),
                        width: constraints.maxWidth,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 6.50),
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
                        top: verticalPadding * 0.75,
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
