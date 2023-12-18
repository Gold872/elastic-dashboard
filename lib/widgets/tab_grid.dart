import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

// Used to refresh the tab grid when a widget is added or removed
// This doesn't use a stateless widget since everything has to be rendered at program startup or data will be lost
class TabGridModel extends ChangeNotifier {
  void onUpdate() {
    notifyListeners();
  }
}

class TabGrid extends StatelessWidget {
  final List<DraggableWidgetContainer> _widgetContainers = [];

  MapEntry<DraggableWidgetContainer, Offset>? _containerDraggingIn;

  final VoidCallback? onAddWidgetPressed;

  TabGridModel? model;

  TabGrid({super.key, this.onAddWidgetPressed});

  TabGrid.fromJson({
    super.key,
    required Map<String, dynamic> jsonData,
    this.onAddWidgetPressed,
    Function(String message)? onJsonLoadingWarning,
  }) {
    if (jsonData['containers'] != null) {
      loadContainersFromJson(jsonData,
          onJsonLoadingWarning: onJsonLoadingWarning);
    }

    if (jsonData['layouts'] != null) {
      loadLayoutsFromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);
    }
  }

  void loadContainersFromJson(Map<String, dynamic> jsonData,
      {Function(String message)? onJsonLoadingWarning}) {
    for (Map<String, dynamic> containerData in jsonData['containers']) {
      _widgetContainers.add(
        DraggableNTWidgetContainer.fromJson(
          key: UniqueKey(),
          tabGrid: this,
          enabled: ntConnection.isNT4Connected,
          jsonData: containerData,
          onUpdate: _ntContainerOnUpdate,
          onDragBegin: _ntContainerOnDragBegin,
          onDragEnd: _ntContainerOnDragEnd,
          onDragCancel: _ntContainerOnDragCancel,
          onResizeBegin: _ntContainerOnResizeBegin,
          onResizeEnd: _ntContainerOnResizeEnd,
          onJsonLoadingWarning: onJsonLoadingWarning,
        ),
      );
    }
  }

  void loadLayoutsFromJson(Map<String, dynamic> jsonData,
      {Function(String warningMessage)? onJsonLoadingWarning}) {
    for (Map<String, dynamic> layoutData in jsonData['layouts']) {
      if (layoutData['type'] == null) {
        onJsonLoadingWarning
            ?.call('Layout widget type not specified, ignoring data.');
        continue;
      }

      late DraggableWidgetContainer widget;

      switch (layoutData['type']) {
        case 'List Layout':
          widget = DraggableListLayout.fromJson(
            key: UniqueKey(),
            tabGrid: this,
            enabled: ntConnection.isNT4Connected,
            jsonData: layoutData,
            ntContainerBuilder: (Map<String, dynamic> jsonData) {
              return DraggableNTWidgetContainer.fromJson(
                key: UniqueKey(),
                tabGrid: this,
                enabled: ntConnection.isNT4Connected,
                jsonData: jsonData,
                onUpdate: _ntContainerOnUpdate,
                onDragBegin: _ntContainerOnDragBegin,
                onDragEnd: _ntContainerOnDragEnd,
                onDragCancel: _ntContainerOnDragCancel,
                onResizeBegin: _ntContainerOnResizeBegin,
                onResizeEnd: _ntContainerOnResizeEnd,
                onJsonLoadingWarning: onJsonLoadingWarning,
              );
            },
            onUpdate: _layoutContainerOnUpdate,
            onDragBegin: _layoutContainerOnDragBegin,
            onDragEnd: _layoutContainerOnDragEnd,
            onDragCancel: _layoutContainerOnDragCancel,
            onResizeBegin: _layoutContainerOnResizeBegin,
            onResizeEnd: _layoutContainerOnResizeEnd,
            onJsonLoadingWarning: onJsonLoadingWarning,
          );
        default:
          continue;
      }

      _widgetContainers.add(widget);
    }
  }

  Map<String, dynamic> toJson() {
    var containers = [];
    var layouts = [];
    for (DraggableWidgetContainer container in _widgetContainers) {
      if (container is DraggableNTWidgetContainer) {
        containers.add(container.toJson());
      } else {
        layouts.add(container.toJson());
      }
    }

    return {
      'layouts': layouts,
      'containers': containers,
    };
  }

  Offset getLocalPosition(Offset globalPosition) {
    BuildContext? context = (key as GlobalKey).currentContext;

    if (context == null) {
      return Offset.zero;
    }

    RenderBox? ancestor = context.findAncestorRenderObjectOfType<RenderBox>();

    Offset localPosition = ancestor!.globalToLocal(globalPosition);

    if (localPosition.dy < 0) {
      localPosition = Offset(localPosition.dx, 0);
    }

    if (localPosition.dx < 0) {
      localPosition = Offset(0, localPosition.dy);
    }

    return localPosition;
  }

  bool isDraggingInContainer() {
    return _containerDraggingIn != null;
  }

  /// Returns weather `widget` is able to be moved to `location` without overlapping anything else.
  ///
  /// This only applies to widgets that already have a place on the grid
  bool isValidMoveLocation(DraggableWidgetContainer widget, Rect location) {
    BuildContext? context = (key as GlobalKey).currentContext;
    Size? gridSize;
    if (context != null) {
      gridSize = MediaQuery.of(context).size;
    }

    for (DraggableWidgetContainer container in _widgetContainers) {
      if (container.displayRect.overlaps(location) && widget != container) {
        return false;
      } else if (gridSize != null &&
          (location.right > gridSize.width ||
              location.bottom > gridSize.height)) {
        return false;
      }
    }
    return true;
  }

  bool isValidLayoutLocation(Offset globalPosition) {
    return getLayoutAtLocation(globalPosition) != null;
  }

  /// Returns weather `location` will overlap with widgets already on the dashboard
  bool isValidLocation(Rect location) {
    for (DraggableWidgetContainer container in _widgetContainers) {
      if (container.displayRect.overlaps(location)) {
        return false;
      }
    }
    return true;
  }

  DraggableLayoutContainer? getLayoutAtLocation(Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    for (DraggableLayoutContainer container
        in _widgetContainers.whereType<DraggableLayoutContainer>()) {
      if (container.displayRect.contains(localPosition)) {
        return container;
      }
    }

    return null;
  }

  void onWidgetResizeEnd(DraggableWidgetContainer widget) {
    if (widget.validLocation) {
      widget.draggingRect = widget.previewRect;
    } else {
      widget.draggingRect = widget.dragStartLocation;
    }

    widget.displayRect = widget.draggingRect;

    widget.previewRect = widget.draggingRect;
    widget.previewVisible = false;
    widget.validLocation = true;

    widget.dispose();
    widget.refresh();
    widget.tryCast<DraggableNTWidgetContainer>()?.refreshChild();
  }

  void onWidgetDragEnd(DraggableWidgetContainer widget) {
    if (widget.validLocation) {
      widget.draggingRect = widget.previewRect;
    } else {
      widget.draggingRect = widget.dragStartLocation;
    }

    widget.displayRect = widget.draggingRect;

    widget.previewRect = widget.draggingRect;
    widget.previewVisible = false;
    widget.validLocation = true;

    widget.dispose();
    widget.refresh();
    widget.tryCast<DraggableNTWidgetContainer>()?.refreshChild();
  }

  void onWidgetDragCancel(DraggableWidgetContainer widget) {
    if (!widget.dragging && !widget.resizing) {
      return;
    }

    widget.draggingRect = widget.dragStartLocation;
    widget.displayRect = widget.draggingRect;
    widget.previewRect = widget.draggingRect;

    widget.previewVisible = false;
    widget.validLocation = true;

    widget.dragging = false;
    widget.resizing = false;
    widget.draggingIntoLayout = false;

    widget.dispose();
  }

  void onWidgetUpdate(
      DraggableWidgetContainer widget, Rect newRect, TransformResult result) {
    double newWidth = max(newRect.width, widget.minWidth);
    double newHeight = max(newRect.height, widget.minHeight);

    Rect constrainedRect = newRect;

    if (widget.resizing) {
      if (result.handle.influencesLeft) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.right - newWidth,
          constrainedRect.top,
          constrainedRect.right,
          constrainedRect.bottom,
        );
      } else if (result.handle.influencesRight) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.left,
          constrainedRect.top,
          constrainedRect.left + newWidth,
          constrainedRect.bottom,
        );
      }

      if (result.handle.influencesTop) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.left,
          constrainedRect.bottom - newHeight,
          constrainedRect.right,
          constrainedRect.bottom,
        );
      } else if (result.handle.influencesBottom) {
        constrainedRect = Rect.fromLTRB(
          constrainedRect.left,
          constrainedRect.top,
          constrainedRect.right,
          constrainedRect.top + newHeight,
        );
      }
    } else {
      constrainedRect = Rect.fromLTWH(
        newRect.left,
        newRect.top,
        newWidth,
        newHeight,
      );
    }

    double previewX = DraggableWidgetContainer.snapToGrid(constrainedRect.left);
    double previewY = DraggableWidgetContainer.snapToGrid(constrainedRect.top);

    double previewWidth = DraggableWidgetContainer.snapToGrid(
        constrainedRect.width.clamp(widget.minWidth, double.infinity));
    double previewHeight = DraggableWidgetContainer.snapToGrid(
        constrainedRect.height.clamp(widget.minHeight, double.infinity));

    Rect preview =
        Rect.fromLTWH(previewX, previewY, previewWidth, previewHeight);

    widget.draggingRect = constrainedRect;
    widget.previewRect = preview;
    widget.previewVisible = true;

    bool validLocation = isValidMoveLocation(widget, preview);

    if (validLocation) {
      widget.validLocation = true;

      widget.draggingIntoLayout = false;
    } else {
      validLocation = isValidLayoutLocation(widget.cursorGlobalLocation) &&
          widget is! DraggableLayoutContainer &&
          !widget.resizing;

      widget.draggingIntoLayout = validLocation;

      widget.validLocation = validLocation;
    }
  }

  void _ntContainerOnUpdate(
      dynamic widget, Rect newRect, TransformResult result) {
    onWidgetUpdate(widget, newRect, result);

    refresh();
  }

  void _ntContainerOnDragBegin(dynamic widget) {
    refresh();
  }

  void _ntContainerOnDragEnd(dynamic widget, Rect releaseRect,
      {Offset? globalPosition}) {
    onWidgetDragEnd(widget);

    DraggableNTWidgetContainer ntContainer =
        widget as DraggableNTWidgetContainer;

    if (widget.draggingIntoLayout && globalPosition != null) {
      DraggableLayoutContainer? layoutContainer =
          getLayoutAtLocation(globalPosition);

      if (layoutContainer != null) {
        layoutContainer.addWidget(ntContainer);
        _widgetContainers.remove(ntContainer);
      }
    }
    refresh();
  }

  void _ntContainerOnDragCancel(dynamic widget) {
    onWidgetDragCancel(widget);

    refresh();
  }

  void _ntContainerOnResizeBegin(dynamic widget) {
    refresh();
  }

  void _ntContainerOnResizeEnd(dynamic widget, Rect releaseRect) {
    onWidgetResizeEnd(widget);

    refresh();
  }

  void _layoutContainerOnUpdate(
      dynamic widget, Rect newRect, TransformResult result) {
    onWidgetUpdate(widget, newRect, result);

    refresh();
  }

  void _layoutContainerOnDragBegin(dynamic widget) {
    refresh();
  }

  void _layoutContainerOnDragEnd(dynamic widget, Rect releaseRect,
      {Offset? globalPosition}) {
    onWidgetDragEnd(widget);

    refresh();
  }

  void _layoutContainerOnDragCancel(dynamic widget) {
    onWidgetDragCancel(widget);

    refresh();
  }

  void _layoutContainerOnResizeBegin(dynamic widget) {
    refresh();
  }

  void _layoutContainerOnResizeEnd(dynamic widget, Rect releaseRect) {
    onWidgetResizeEnd(widget);

    refresh();
  }

  void layoutDragOutEnd(DraggableWidgetContainer widget) {
    if (widget is DraggableNTWidgetContainer) {
      placeNTDragInWidget(widget, true);
    }
  }

  void layoutDragOutUpdate(
      DraggableWidgetContainer widget, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    widget.draggingRect = Rect.fromLTWH(
      localPosition.dx,
      localPosition.dy,
      widget.draggingRect.width,
      widget.draggingRect.height,
    );
    _containerDraggingIn = MapEntry(widget, globalPosition);
    refresh();
  }

  void onNTConnect() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.setEnabled(true);
    }

    refresh();
  }

  void onNTDisconnect() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.setEnabled(false);
    }

    refresh();
  }

  void addLayoutDragInWidget(
      DraggableLayoutContainer widget, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    widget.draggingRect = Rect.fromLTWH(
      localPosition.dx,
      localPosition.dy,
      widget.draggingRect.width,
      widget.draggingRect.height,
    );
    _containerDraggingIn = MapEntry(widget, globalPosition);
    refresh();
  }

  void placeLayoutDragInWidget(DraggableLayoutContainer widget) {
    if (_containerDraggingIn == null) {
      return;
    }

    Offset globalPosition = _containerDraggingIn!.value;

    Offset localPosition = getLocalPosition(globalPosition);

    double previewX = DraggableWidgetContainer.snapToGrid(localPosition.dx);
    double previewY = DraggableWidgetContainer.snapToGrid(localPosition.dy);

    Rect previewLocation = Rect.fromLTWH(previewX, previewY,
        widget.displayRect.width, widget.displayRect.height);

    if (!isValidLocation(previewLocation)) {
      _containerDraggingIn = null;

      refresh();
      return;
    }

    double width = widget.displayRect.width;
    double height = widget.displayRect.height;

    widget.displayRect = Rect.fromLTWH(previewX, previewY, width, height);
    widget.draggingRect = Rect.fromLTWH(previewX, previewY, width, height);
    widget.dragStartLocation = Rect.fromLTWH(previewX, previewY, width, height);

    addWidget(widget);
    _containerDraggingIn = null;

    refresh();
  }

  void addNTDragInWidget(
      DraggableNTWidgetContainer widget, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    widget.draggingRect = Rect.fromLTWH(
      localPosition.dx,
      localPosition.dy,
      widget.draggingRect.width,
      widget.draggingRect.height,
    );
    _containerDraggingIn = MapEntry(widget, globalPosition);
    refresh();
  }

  void placeNTDragInWidget(DraggableNTWidgetContainer widget,
      [bool fromLayout = false]) {
    if (_containerDraggingIn == null) {
      return;
    }

    Offset globalPosition = _containerDraggingIn!.value;

    Offset localPosition = getLocalPosition(globalPosition);

    double previewX = DraggableWidgetContainer.snapToGrid(localPosition.dx);
    double previewY = DraggableWidgetContainer.snapToGrid(localPosition.dy);

    double width = widget.displayRect.width;
    double height = widget.displayRect.height;

    Rect previewLocation = Rect.fromLTWH(previewX, previewY, width, height);
    widget.previewRect = previewLocation;

    if (isValidLayoutLocation(widget.cursorGlobalLocation)) {
      DraggableLayoutContainer layoutContainer =
          getLayoutAtLocation(widget.cursorGlobalLocation)!;

      if (layoutContainer.willAcceptWidget(widget)) {
        layoutContainer.addWidget(widget);
      }
    } else if (!isValidLocation(previewLocation)) {
      _containerDraggingIn = null;

      widget.child.dispose(deleting: !fromLayout);
      if (!fromLayout) {
        widget.child.unSubscribe();
      }

      refresh();
      return;
    } else {
      widget.displayRect = previewLocation;
      widget.draggingRect = Rect.fromLTWH(previewX, previewY, width, height);

      addWidget(widget);
    }

    _containerDraggingIn = null;

    widget.child.dispose();

    refresh();
  }

  DraggableNTWidgetContainer? createNTWidgetContainer(WidgetContainer? widget) {
    if (widget == null || widget.child == null) {
      return null;
    }

    if (widget.child is! NTWidget) {
      return null;
    }

    return DraggableNTWidgetContainer(
      key: UniqueKey(),
      tabGrid: this,
      title: widget.title,
      enabled: ntConnection.isNT4Connected,
      initialPosition: Rect.fromLTWH(
        0.0,
        0.0,
        widget.width,
        widget.height,
      ),
      onUpdate: _ntContainerOnUpdate,
      onDragBegin: _ntContainerOnDragBegin,
      onDragEnd: _ntContainerOnDragEnd,
      onDragCancel: _ntContainerOnDragCancel,
      onResizeBegin: _ntContainerOnResizeBegin,
      onResizeEnd: _ntContainerOnResizeEnd,
      child: widget.child as NTWidget,
    );
  }

  DraggableListLayout createListLayout() {
    return DraggableListLayout(
      key: UniqueKey(),
      tabGrid: this,
      title: 'List Layout',
      initialPosition: Rect.fromLTWH(
        0.0,
        0.0,
        Settings.gridSize.toDouble() * 2,
        Settings.gridSize.toDouble() * 2,
      ),
      enabled: ntConnection.isNT4Connected,
      onUpdate: _layoutContainerOnUpdate,
      onDragBegin: _layoutContainerOnDragBegin,
      onDragEnd: _layoutContainerOnDragEnd,
      onDragCancel: _layoutContainerOnDragCancel,
      onResizeBegin: _layoutContainerOnResizeBegin,
      onResizeEnd: _layoutContainerOnResizeEnd,
    );
  }

  void addWidget(DraggableWidgetContainer widget) {
    _widgetContainers.add(widget);
  }

  void addWidgetFromTabJson(Map<String, dynamic> widgetData) {
    Rect newWidgetLocation = Rect.fromLTWH(
      tryCast(widgetData['x']) ?? 0.0,
      tryCast(widgetData['y']) ?? 0.0,
      tryCast(widgetData['width']) ?? 0.0,
      tryCast(widgetData['height']) ?? 0.0,
    );
    // If the widget is already in the tab, don't add it
    if (!widgetData['layout']) {
      for (DraggableNTWidgetContainer container
          in _widgetContainers.whereType<DraggableNTWidgetContainer>()) {
        String? title = container.title;
        String? type = container.child.type;
        String? topic = container.child.topic;
        bool validLocation = isValidLocation(newWidgetLocation);

        if (title == null) {
          continue;
        }

        if (title == widgetData['title'] &&
            type == widgetData['type'] &&
            topic == widgetData['properties']['topic'] &&
            !validLocation) {
          return;
        }
      }
    } else {
      for (DraggableLayoutContainer container
          in _widgetContainers.whereType<DraggableLayoutContainer>()) {
        String? title = container.title;
        String type = container.type;
        bool validLocation = isValidLocation(newWidgetLocation);

        if (title == null) {
          continue;
        }

        if (title == widgetData['title'] &&
            type == widgetData['type'] &&
            !validLocation) {
          return;
        }
      }
    }

    if (widgetData['layout']) {
      switch (widgetData['type']) {
        case 'List Layout':
          _widgetContainers.add(
            DraggableListLayout.fromJson(
              key: UniqueKey(),
              tabGrid: this,
              enabled: ntConnection.isNT4Connected,
              ntContainerBuilder: (Map<String, dynamic> jsonData) {
                return DraggableNTWidgetContainer.fromJson(
                  key: UniqueKey(),
                  tabGrid: this,
                  enabled: ntConnection.isNT4Connected,
                  jsonData: jsonData,
                  onUpdate: _ntContainerOnUpdate,
                  onDragBegin: _ntContainerOnDragBegin,
                  onDragEnd: _ntContainerOnDragEnd,
                  onDragCancel: _ntContainerOnDragCancel,
                  onResizeBegin: _ntContainerOnResizeBegin,
                  onResizeEnd: _ntContainerOnResizeEnd,
                );
              },
              jsonData: widgetData,
              onUpdate: _layoutContainerOnUpdate,
              onDragBegin: _layoutContainerOnDragBegin,
              onDragEnd: _layoutContainerOnDragEnd,
              onDragCancel: _layoutContainerOnDragCancel,
              onResizeBegin: _layoutContainerOnResizeBegin,
              onResizeEnd: _layoutContainerOnResizeEnd,
            ),
          );
          break;
      }
    } else {
      _widgetContainers.add(DraggableNTWidgetContainer.fromJson(
        key: UniqueKey(),
        tabGrid: this,
        enabled: ntConnection.isNT4Connected,
        jsonData: widgetData,
        onUpdate: _ntContainerOnUpdate,
        onDragBegin: _ntContainerOnDragBegin,
        onDragEnd: _ntContainerOnDragEnd,
        onDragCancel: _ntContainerOnDragCancel,
        onResizeBegin: _ntContainerOnResizeBegin,
        onResizeEnd: _ntContainerOnResizeEnd,
      ));
    }

    refresh();
  }

  void removeWidget(DraggableWidgetContainer widget) {
    widget.dispose(deleting: true);
    widget.unSubscribe();
    _widgetContainers.remove(widget);
    refresh();
  }

  void clearWidgets(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Clear'),
        content: const Text(
            'Are you sure you want to remove all widgets from this tab?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

              for (DraggableWidgetContainer container in _widgetContainers) {
                container.dispose(deleting: true);
                container.unSubscribe();
              }
              _widgetContainers.clear();
              refresh();
            },
            child: const Text('Confirm'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void onDestroy() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.dispose(deleting: true);
      container.unSubscribe();
    }
    _widgetContainers.clear();
  }

  void refresh() {
    Future(() async {
      model?.onUpdate();
    });
  }

  void refreshAllContainers() {
    Future(() async {
      for (DraggableWidgetContainer widget in _widgetContainers) {
        widget.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    model = context.watch<TabGridModel?>();

    List<Widget> dashboardWidgets = [];
    List<Widget> draggingWidgets = [];
    List<Widget> draggingInWidgets = [];
    List<Widget> previewOutlines = [];

    for (DraggableWidgetContainer container in _widgetContainers) {
      if (container.dragging) {
        draggingWidgets.add(
          Positioned(
            left: container.draggingRect.left,
            top: container.draggingRect.top,
            child: IgnorePointer(
              child: container.getDraggingWidgetContainer(context),
            ),
          ),
        );

        if (!container.draggingIntoLayout) {
          previewOutlines.add(
            container.getDefaultPreview(),
          );
        } else {
          DraggableLayoutContainer? layoutContainer =
              getLayoutAtLocation(container.cursorGlobalLocation);

          if (layoutContainer == null) {
            previewOutlines.add(
              container.getDefaultPreview(),
            );
          } else {
            previewOutlines.add(
              Positioned(
                left: layoutContainer.displayRect.left,
                top: layoutContainer.displayRect.top,
                width: layoutContainer.displayRect.width,
                height: layoutContainer.displayRect.height,
                child: Visibility(
                  visible: container.previewVisible,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius:
                          BorderRadius.circular(Settings.cornerRadius),
                      border: Border.all(color: Colors.yellow, width: 5.0),
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }

      dashboardWidgets.add(
        GestureDetector(
          onTap: () {},
          onSecondaryTapUp: (details) {
            ContextMenu contextMenu = ContextMenu(
              position: details.globalPosition,
              borderRadius: BorderRadius.circular(5.0),
              padding: const EdgeInsets.all(4.0),
              entries: [
                MenuHeader(
                  text: container.title ?? '',
                  disableUppercase: true,
                ),
                const MenuDivider(),
                MenuItem(
                  label: 'Edit Properties',
                  icon: Icons.edit_outlined,
                  onSelected: () {
                    container.showEditProperties(context);
                  },
                ),
                ...container.getContextMenuItems(),
                MenuItem(
                    label: 'Remove',
                    icon: Icons.delete_outlined,
                    onSelected: () {
                      removeWidget(container);
                    }),
              ],
            );

            showContextMenu(
              context,
              contextMenu: contextMenu,
              transitionDuration: const Duration(milliseconds: 100),
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
          child: ChangeNotifierProvider(
            create: (context) => WidgetContainerModel(),
            child: container,
          ),
        ),
      );
    }

    // Also render any containers that are being dragged into the grid
    if (_containerDraggingIn != null) {
      DraggableWidgetContainer container = _containerDraggingIn!.key;

      draggingWidgets.add(
        Positioned(
          left: container.draggingRect.left,
          top: container.draggingRect.top,
          child: IgnorePointer(
            child: container.getDraggingWidgetContainer(context),
          ),
        ),
      );

      double previewX =
          DraggableWidgetContainer.snapToGrid(container.draggingRect.left);
      double previewY =
          DraggableWidgetContainer.snapToGrid(container.draggingRect.top);

      Rect previewLocation = Rect.fromLTWH(previewX, previewY,
          container.displayRect.width, container.displayRect.height);

      bool validLocation = isValidLocation(previewLocation) ||
          isValidLayoutLocation(container.cursorGlobalLocation);

      Color borderColor =
          (validLocation) ? Colors.lightGreenAccent.shade400 : Colors.red;

      if (isValidLayoutLocation(container.cursorGlobalLocation)) {
        DraggableLayoutContainer layoutContainer =
            getLayoutAtLocation(container.cursorGlobalLocation)!;

        previewLocation = layoutContainer.displayRect;

        borderColor = Colors.yellow;
      }

      previewOutlines.add(
        Positioned(
          left: previewLocation.left,
          top: previewLocation.top,
          width: previewLocation.width,
          height: previewLocation.height,
          child: Container(
            decoration: BoxDecoration(
              color: (validLocation)
                  ? Colors.white.withOpacity(0.25)
                  : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(Settings.cornerRadius),
              border: Border.all(color: borderColor, width: 5.0),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {},
      onSecondaryTapUp: (details) {
        ContextMenu contextMenu = ContextMenu(
          position: details.globalPosition,
          borderRadius: BorderRadius.circular(5.0),
          padding: const EdgeInsets.all(4.0),
          entries: [
            MenuItem(
              label: 'Add Widget',
              icon: Icons.add,
              onSelected: () => onAddWidgetPressed?.call(),
            ),
            MenuItem(
              label: 'Clear Layout',
              icon: Icons.clear,
              onSelected: () => clearWidgets(context),
            ),
          ],
        );

        showContextMenu(
          context,
          contextMenu: contextMenu,
          transitionDuration: const Duration(milliseconds: 100),
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
      },
      child: Stack(
        children: [
          ...dashboardWidgets,
          ...previewOutlines,
          ...draggingWidgets,
          ...draggingInWidgets,
        ],
      ),
    );
  }
}
