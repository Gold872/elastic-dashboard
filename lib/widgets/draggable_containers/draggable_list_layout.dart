import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt4_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

class DraggableListLayout extends DraggableLayoutContainer {
  @override
  String type = 'List Layout';

  List<DraggableNT4WidgetContainer> children = [];

  String labelPosition = 'TOP';

  List<String> labelPositions = const [
    'Top',
    'Left',
    'Right',
    'Bottom',
    'Hidden',
  ];

  DraggableListLayout({
    super.key,
    required super.tabGrid,
    required super.title,
    required super.initialPosition,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
    this.labelPosition = 'TOP',
  }) : super();

  DraggableListLayout.fromJson({
    super.key,
    required super.tabGrid,
    required super.jsonData,
    required super.nt4ContainerBuilder,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
    super.onJsonLoadingWarning,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...getContainerEditProperties(),
                    const Divider(),
                    const Center(
                      child: Text('Label Position'),
                    ),
                    DialogDropdownChooser(
                      onSelectionChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        if (!labelPositions.contains(value)) {
                          return;
                        }

                        setState(() {
                          labelPosition = value.toUpperCase();

                          refresh();
                        });
                      },
                      choices: labelPositions,
                      initialValue:
                          labelPosition.substring(0, 1).toUpperCase() +
                              labelPosition.substring(1).toLowerCase(),
                    ),
                    const Divider(),
                    if (children.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(
                          maxHeight: 300,
                        ),
                        child: ReorderableListView(
                          header: const Text('Children Order & Properties'),
                          children: children
                              .map(
                                (container) => Padding(
                                  key: UniqueKey(),
                                  padding: EdgeInsets.zero,
                                  child: ExpansionTile(
                                    title: Text(container.title ?? ''),
                                    subtitle: Text(container.child.type),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            children.remove(container);

                                            container.unSubscribe();
                                            container.dispose(deleting: true);

                                            refresh();
                                          });
                                        }),
                                    tilePadding:
                                        const EdgeInsets.only(right: 40.0),
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
        container.child.getEditProperties(context);

    return [
      ...containerEditProperties,
      container.getWidgetTypeProperties((fn) {
        setState(fn);
        refresh();
      }),
      if (childEditProperties.isNotEmpty) ...[
        const Divider(),
        Text('${container.child.type} Widget Settings'),
        const SizedBox(height: 5),
        ...childEditProperties,
      ],
      const Divider(),
      ...container.getNT4EditProperties(),
      const SizedBox(height: 5),
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
  void fromJson(Map<String, dynamic> jsonData,
      {Function(String errorMessage)? onJsonLoadingWarning}) {
    super.fromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);

    if (jsonData.containsKey('properties') &&
        jsonData['properties'] is Map<String, dynamic>) {
      labelPosition = tryCast(jsonData['properties']['label_position']) ??
          tryCast(jsonData['properties']['Label position']) ??
          'TOP';

      if (!labelPositions
          .map((e) => e.toUpperCase())
          .contains(labelPosition.toUpperCase())) {
        labelPosition = 'TOP';
      }
    }

    if (!jsonData.containsKey('children')) {
      onJsonLoadingWarning
          ?.call('List Layout JSON data does not contain any children');
      return;
    }

    if (jsonData['children'] is! List<dynamic>) {
      onJsonLoadingWarning
          ?.call('List Layout JSON data does not contain any children');
      return;
    }

    for (Map<String, dynamic> childData in jsonData['children']) {
      children.add(nt4ContainerBuilder?.call(childData) ??
          DraggableNT4WidgetContainer.fromJson(
            tabGrid: tabGrid,
            jsonData: childData,
            onJsonLoadingWarning: onJsonLoadingWarning,
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
  Map<String, dynamic> getProperties() {
    return {
      'label_position': labelPosition,
    };
  }

  @override
  void dispose({bool deleting = false}) {
    super.dispose(deleting: deleting);

    for (var child in children) {
      child.dispose(deleting: deleting);
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
      Widget widgetInContainer = Container(
        constraints: BoxConstraints(
          maxHeight: (widget.minHeight ?? 128.0) - 64.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2.0),
                child: widget.child,
              ),
            ),
          ],
        ),
      );

      Widget containerContent;

      switch (labelPosition.toUpperCase()) {
        case 'LEFT':
          containerContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Flexible(
                child: widgetInContainer,
              ),
            ],
          );
          break;
        case 'RIGHT':
          containerContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: widgetInContainer,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
          break;
        case 'BOTTOM':
          containerContent = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              widgetInContainer,
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
          break;
        case 'HIDDEN':
          containerContent = widgetInContainer;
        case 'TOP':
        default:
          containerContent = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              widgetInContainer,
            ],
          );
          break;
      }

      column.add(
        GestureDetector(
          supportedDevices: PointerDeviceKind.values
              .whereNot((element) => element == PointerDeviceKind.trackpad)
              .toSet(),
          onPanDown: (details) {
            widget.cursorGlobalLocation = details.globalPosition;

            Future(() {
              onDragCancel?.call(this);
              if (dragging || resizing) {
                onDragCancel?.call(this);
                controller?.setRect(draggablePositionRect);
              }

              model?.setDraggable(false);
            });
          },
          onPanUpdate: (details) {
            widget.cursorGlobalLocation = details.globalPosition;

            Offset location = details.globalPosition -
                Offset(widget.displayRect.width, widget.displayRect.height) / 2;

            tabGrid.layoutDragOutUpdate(widget, location);
          },
          onPanEnd: (details) {
            Future(() => model?.setDraggable(true));

            Rect previewLocation = Rect.fromLTWH(
              DraggableWidgetContainer.snapToGrid(
                  widget.draggablePositionRect.left),
              DraggableWidgetContainer.snapToGrid(
                  widget.draggablePositionRect.top),
              widget.displayRect.width,
              widget.displayRect.height,
            );

            if ((tabGrid.isValidLocation(previewLocation) ||
                    tabGrid
                        .isValidLayoutLocation(widget.cursorGlobalLocation)) &&
                tabGrid.isDraggingInContainer()) {
              children.remove(widget);
            }

            tabGrid.layoutDragOutEnd(widget);
          },
          onPanCancel: () {
            Future(() {
              if (dragging || resizing) {
                onDragCancel?.call(this);
                controller?.setRect(draggablePositionRect);
              }

              model?.setDraggable(true);
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.5),
                color: const Color.fromARGB(255, 45, 45, 45),
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black,
                  ),
                ],
              ),
              child: containerContent,
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
      horizontalPadding: 5.0,
      verticalPadding: 5.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Column(
                children: [
                  ..._getListColumn(),
                ],
              ),
            ),
          ),
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
      horizontalPadding: 5.0,
      verticalPadding: 5.0,
      child: Opacity(
        opacity: (enabled) ? 1.00 : 0.50,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(
                  children: [
                    ..._getListColumn(),
                  ],
                ),
              ),
            ),
          ],
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
