import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt4_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:flutter/material.dart';

class DraggableListLayout extends DraggableLayoutContainer {
  @override
  String type = 'List Layout';

  List<DraggableNT4WidgetContainer> children = [];

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

  DraggableListLayout.fromJson({
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

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      ...getChildrenJson(),
    };
  }

  Map<String, dynamic> getChildrenJson() {
    var childrenJson = [];

    for (DraggableWidgetContainer childContainer in children) {
      childrenJson.add(childContainer.toJson());
    }

    return {
      'children': childrenJson,
    };
  }

  @override
  bool willAcceptWidget(DraggableWidgetContainer widget) {
    return widget is DraggableNT4WidgetContainer;
  }

  @override
  void addWidget(WidgetContainer widget) {}

  List<Widget> getListColumn() {
    List<Widget> column = [];

    for (DraggableNT4WidgetContainer widget in children) {
      column.add(widget.child!);
      column.add(const SizedBox(height: 5));
    }

    if (column.isNotEmpty) {
      column.removeLast();
    }

    return column;
  }

  @override
  WidgetContainer getWidgetContainer() {
    return WidgetContainer(
      title: title,
      width: displayRect.width,
      height: displayRect.height,
      opacity: (model?.previewVisible ?? false) ? 0.25 : 1.00,
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
          child: getWidgetContainer(),
        ),
        ...super.getStackChildren(model!),
      ],
    );
  }
}
