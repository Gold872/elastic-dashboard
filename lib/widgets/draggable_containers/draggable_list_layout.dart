import 'package:elastic_dashboard/services/globals.dart';
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

  @override
  void fromJson(Map<String, dynamic> jsonData) {
    super.fromJson(jsonData);

    for (Map<String, dynamic> childData in jsonData['children']) {
      children.add(DraggableNT4WidgetContainer.fromJson(
        validMoveLocation: validMoveLocation,
        jsonData: childData,
      ));
    }
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
  void addWidget(DraggableNT4WidgetContainer widget, {Offset? localPosition}) {
    children.add(widget);

    refresh();
  }

  List<Widget> getListColumn() {
    List<Widget> column = [];

    for (DraggableNT4WidgetContainer widget in children) {
      column.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            constraints: BoxConstraints(
              minHeight: 96,
              // maxWidth: widget.displayRect.width,
              maxHeight: widget.displayRect.height - 32,
            ),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 45, 45, 45),
              borderRadius: BorderRadius.circular(Globals.cornerRadius),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(2, 2),
                  blurRadius: 10.5,
                  spreadRadius: 0,
                  color: Colors.black,
                ),
              ],
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.title ?? ''),
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: widget.child!,
                ),
              ],
            ),
          ),
        ),
      );
      column.add(const Divider(height: 5));
    }

    if (column.isNotEmpty) {
      column.removeLast();
    }

    return column;
  }

  @override
  WidgetContainer getDraggingWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: draggablePositionRect.width,
      height: draggablePositionRect.height,
      opacity: 0.80,
      child: ClipRRect(
        child: Wrap(
          children: [
            ...getListColumn(),
          ],
        ),
      ),
    );
  }

  @override
  WidgetContainer getWidgetContainer(BuildContext context) {
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
            child: ClipRRect(
              child: Wrap(
                children: [
                  ...getListColumn(),
                ],
              ),
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
          child: getWidgetContainer(context),
        ),
        ...super.getStackChildren(model!),
      ],
    );
  }
}
