import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
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
    required super.dashboardGrid,
    required super.title,
    required super.initialPosition,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();

  DraggableListLayout.fromJson({
    super.key,
    required super.dashboardGrid,
    required super.jsonData,
    required super.nt4ContainerBuilder,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super.fromJson();

  @override
  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Properties'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 353,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...getContainerEditProperties(),
                      const Divider(),
                      if (children.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 350,
                          ),
                          child: ReorderableListView(
                            header: const Text('Children Order & Properties'),
                            children: children
                                .map(
                                  (container) => Padding(
                                    key: UniqueKey(),
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ExpansionTile(
                                      title: Text(container.title ?? ''),
                                      subtitle: Text(
                                          container.child?.type ?? 'NT4Widget'),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      trailing: IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            setState(() {
                                              children.remove(container);

                                              container.unSubscribe();
                                              container.dispose();

                                              refresh();
                                            });
                                          }),
                                      childrenPadding: const EdgeInsets.only(
                                        left: 16.0,
                                        top: 8.0,
                                        right: 32.0,
                                        bottom: 8.0,
                                      ),
                                      expandedCrossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: getChildEditProperties(
                                          context, container, setState),
                                    ),
                                  ),
                                )
                                .toList(),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) {
                                  newIndex--;
                                }
                                var temp = children[newIndex];
                                children[newIndex] = children[oldIndex];
                                children[oldIndex] = temp;

                                refresh();
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
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

  List<Widget> getChildEditProperties(BuildContext context,
      DraggableNT4WidgetContainer container, StateSetter setState) {
    List<Widget> containerEditProperties = [
      // Settings for the widget container
      const Text('Container Settings'),
      const SizedBox(height: 5),
      DialogTextInput(
        onSubmit: (value) {
          setState(() {
            container.title = value;

            container.refresh();
            
            refresh();
          });
        },
        label: 'Title',
        initialText: container.title,
      ),
    ];

    List<Widget> childEditProperties =
        container.child!.getEditProperties(context);

    return [
      ...containerEditProperties,
      const Divider(),
      if (childEditProperties.isNotEmpty) ...[
        ...childEditProperties,
        const Divider()
      ],
      ...container.getNT4EditProperties(),
    ];
  }

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
      children.add(nt4ContainerBuilder?.call(childData) ??
          DraggableNT4WidgetContainer.fromJson(
            dashboardGrid: dashboardGrid,
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
  void dispose() {
    super.dispose();

    for (var child in children) {
      child.dispose();
    }
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    for (var child in children) {
      child.unSubscribe();
    }
  }

  @override
  void setEnabled(bool enabled) {
    for (DraggableNT4WidgetContainer container in children) {
      container.setEnabled(enabled);
    }

    super.setEnabled(enabled);
  }

  @override
  bool willAcceptWidget(DraggableWidgetContainer widget,
      {Offset? globalPosition}) {
    return widget is DraggableNT4WidgetContainer;
  }

  @override
  void addWidget(DraggableNT4WidgetContainer widget) {
    children.add(widget);

    refresh();
  }

  List<Widget> _getListColumn() {
    List<Widget> column = [];

    for (DraggableNT4WidgetContainer widget in children) {
      column.add(
        // Detectors for dragging so widgets can be dragged out of list layout
        GestureDetector(
          supportedDevices: PointerDeviceKind.values
              .whereNot((element) => element == PointerDeviceKind.trackpad)
              .toSet(),
          onPanDown: (details) {
            if (dragging) {
              dragging = false;
              refresh();
            }
            Future.delayed(Duration.zero, () => model?.setDraggable(false));

            widget.cursorGlobalLocation = details.globalPosition;
          },
          onPanUpdate: (details) {
            widget.cursorGlobalLocation = details.globalPosition;

            Offset location = details.globalPosition -
                Offset(widget.displayRect.width, widget.displayRect.height) / 2;

            dashboardGrid.layoutDragOutUpdate(widget, location);
          },
          onPanEnd: (details) {
            Future.delayed(Duration.zero, () => model?.setDraggable(true));

            Rect previewLocation = Rect.fromLTWH(
              DraggableWidgetContainer.snapToGrid(
                  widget.draggablePositionRect.left),
              DraggableWidgetContainer.snapToGrid(
                  widget.draggablePositionRect.top),
              widget.displayRect.width,
              widget.displayRect.height,
            );

            if (dashboardGrid.isValidLocation(previewLocation) ||
                dashboardGrid
                    .isValidLayoutLocation(widget.cursorGlobalLocation)) {
              children.remove(widget);
            }

            dashboardGrid.layoutDragOutEnd(widget);
          },
          onPanCancel: () {
            Future.delayed(Duration.zero, () => model?.setDraggable(true));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.5),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              constraints: BoxConstraints(
                minHeight: 96,
                maxHeight: widget.displayRect.height - 32,
              ),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 45, 45, 45),
                borderRadius: BorderRadius.circular(Globals.cornerRadius),
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(2, 2),
                    blurRadius: 8.0,
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
                    child: AbsorbPointer(
                      absorbing: !enabled,
                      child: widget.child!,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
      child: Wrap(
        children: [
          ..._getListColumn(),
        ],
      ),
    );
  }

  @override
  WidgetContainer getWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: displayRect.width,
      height: displayRect.height,
      opacity: (previewVisible) ? 0.25 : 1.00,
      child: Opacity(
        opacity: (enabled) ? 1.00 : 0.50,
        child: SingleChildScrollView(
          child: Wrap(
            children: [
              ..._getListColumn(),
            ],
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
