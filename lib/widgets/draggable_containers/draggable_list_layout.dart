import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';

class DraggableListLayout extends DraggableWidgetContainer {
  List<NT4Widget> children = [];

  DraggableListLayout({
    super.key,
    required super.title,
    required super.validMoveLocation,
    super.enabled = false,
    super.initialPosition,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();

  List<Widget> getListColumn() {
    List<Widget> column = [];

    for (NT4Widget widget in children) {
      column.add(widget);
      column.add(const SizedBox(height: 5));
    }

    column.removeLast();

    return column;
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...getListColumn(),
                    ],
                  ),
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
