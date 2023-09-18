import 'package:contextmenu/contextmenu.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt4_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Used to refresh the dashboard grid when a widget is added or removed
// This doesn't use a stateless widget since everything has to be rendered at program startup or data will be lost
class DashboardGridModel extends ChangeNotifier {
  void onUpdate() {
    notifyListeners();
  }
}

class DashboardGrid extends StatelessWidget {
  final Map<String, dynamic>? jsonData;

  final List<DraggableWidgetContainer> _widgetContainers = [];
  final List<DraggableNT4WidgetContainer> _nt4DraggingContainers = [];
  final List<DraggableLayoutContainer> _layoutDraggingContainers = [];

  MapEntry<DraggableWidgetContainer, Offset>? _containerDraggingIn;

  final VoidCallback? onAddWidgetPressed;

  DashboardGridModel? model;

  DashboardGrid({super.key, this.jsonData, this.onAddWidgetPressed}) {
    init();
  }

  DashboardGrid.fromJson(
      {super.key, required this.jsonData, this.onAddWidgetPressed}) {
    init();
  }

  void init() {
    if (jsonData == null) {
      return;
    }

    if (jsonData!['containers'] != null) {
      loadContainersFromJson(jsonData!);
    }

    if (jsonData!['layouts'] != null) {
      loadLayoutsFromJson(jsonData!);
    }
  }

  void loadContainersFromJson(Map<String, dynamic> jsonData) {
    for (Map<String, dynamic> containerData in jsonData['containers']) {
      _widgetContainers.add(DraggableNT4WidgetContainer.fromJson(
        key: UniqueKey(),
        enabled: nt4Connection.isNT4Connected,
        validMoveLocation: isValidMoveLocation,
        validLayoutLocation: isValidLayoutLocation,
        jsonData: containerData,
        onUpdate: _nt4ContainerOnUpdate,
        onDragBegin: _nt4ContainerOnDragBegin,
        onDragEnd: _nt4ContainerOnDragEnd,
        onResizeBegin: _nt4ContainerOnResizeBegin,
        onResizeEnd: _nt4ContainerOnResizeEnd,
      ));
    }
  }

  void loadLayoutsFromJson(Map<String, dynamic> jsonData) {
    for (Map<String, dynamic> layoutData in jsonData['layouts']) {
      if (layoutData['type'] == null) {
        continue;
      }

      late DraggableWidgetContainer widget;

      switch (layoutData['type']) {
        case 'List Layout':
          widget = DraggableListLayout.fromJson(
            key: UniqueKey(),
            enabled: nt4Connection.isNT4Connected,
            validMoveLocation: isValidMoveLocation,
            jsonData: layoutData,
            nt4ContainerBuilder: (Map<String, dynamic> jsonData) {
              return DraggableNT4WidgetContainer.fromJson(
                key: UniqueKey(),
                enabled: nt4Connection.isNT4Connected,
                validMoveLocation: isValidMoveLocation,
                validLayoutLocation: isValidLayoutLocation,
                jsonData: jsonData,
                onUpdate: _nt4ContainerOnUpdate,
                onDragBegin: _nt4ContainerOnDragBegin,
                onDragEnd: _nt4ContainerOnDragEnd,
                onResizeBegin: _nt4ContainerOnResizeBegin,
                onResizeEnd: _nt4ContainerOnResizeEnd,
              );
            },
            onDragOutUpdate: _layoutOnDragOutUpdate,
            onDragOutEnd: _layoutOnDragOutEnd,
            onUpdate: _layoutContainerOnUpdate,
            onDragBegin: _layoutContainerOnDragBegin,
            onDragEnd: _layoutContainerOnDragEnd,
            onResizeBegin: _layoutContainerOnResizeBegin,
            onResizeEnd: _layoutContainerOnResizeEnd,
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
      if (container is DraggableNT4WidgetContainer) {
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

  bool isValidLayoutLocation(
      DraggableWidgetContainer widget, Rect location, Offset localPosition) {
    return getLayoutAtLocation(location, localPosition) != null;
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

  DraggableLayoutContainer? getLayoutAtLocation(
      Rect location, Offset localPosition) {
    for (DraggableLayoutContainer container
        in _widgetContainers.whereType<DraggableLayoutContainer>()) {
      if (container.displayRect.contains(location.topLeft + localPosition)) {
        return container;
      }
    }

    return null;
  }

  void _nt4ContainerOnUpdate(dynamic widget) {
    refresh();
  }

  void _nt4ContainerOnDragBegin(dynamic widget) {
    _nt4DraggingContainers.add(widget);
    refresh();
  }

  void _nt4ContainerOnDragEnd(dynamic widget, Rect releaseRect,
      {Offset? localPosition}) {
    DraggableNT4WidgetContainer nt4Container =
        widget as DraggableNT4WidgetContainer;

    if (widget.draggingIntoLayout && localPosition != null) {
      DraggableLayoutContainer? layoutContainer =
          getLayoutAtLocation(releaseRect, localPosition);

      if (layoutContainer != null) {
        layoutContainer.addWidget(nt4Container, localPosition: localPosition);
        _widgetContainers.remove(nt4Container);
      }
    } else {
      _nt4DraggingContainers.toSet().lookup(widget)?.dispose();
    }
    _nt4DraggingContainers.remove(widget);
    refresh();
  }

  void _nt4ContainerOnResizeBegin(dynamic widget) {
    _nt4DraggingContainers.add(widget);
    refresh();
  }

  void _nt4ContainerOnResizeEnd(dynamic widget, Rect releaseRect) {
    _nt4DraggingContainers.toSet().lookup(widget)?.dispose();
    _nt4DraggingContainers.remove(widget);
    refresh();
  }

  void _layoutContainerOnUpdate(dynamic widget) {
    refresh();
  }

  void _layoutContainerOnDragBegin(dynamic widget) {
    _layoutDraggingContainers.add(widget);
    refresh();
  }

  void _layoutContainerOnDragEnd(dynamic widget, Rect releaseRect,
      {Offset? localPosition}) {
    _layoutDraggingContainers.remove(widget);
    refresh();
  }

  void _layoutContainerOnResizeBegin(dynamic widget) {
    _layoutDraggingContainers.add(widget);
    refresh();
  }

  void _layoutContainerOnResizeEnd(dynamic widget, Rect releaseRect) {
    _layoutDraggingContainers.remove(widget);
    refresh();
  }

  void _layoutOnDragOutEnd(DraggableWidgetContainer widget) {
    if (widget is DraggableNT4WidgetContainer) {
      placeNT4DragInWidget(widget);
    }
  }

  void _layoutOnDragOutUpdate(
      DraggableWidgetContainer widget, Offset location) {
    _containerDraggingIn = MapEntry(widget, location);
    refresh();
  }

  void onNTConnect() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.enabled = true;

      container.refresh();
    }

    refresh();
  }

  void onNTDisconnect() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.enabled = false;

      container.refresh();
    }

    refresh();
  }

  void addLayoutDragInWidget(
      DraggableLayoutContainer widget, Offset globalOffset) {
    _containerDraggingIn = MapEntry(widget, globalOffset);
    refresh();
  }

  void placeLayoutDragInWidget(DraggableLayoutContainer widget) {
    if (_containerDraggingIn == null) {
      return;
    }

    Offset globalPosition = _containerDraggingIn!.value;

    BuildContext? context = (key as GlobalKey).currentContext;

    if (context == null) {
      return;
    }

    RenderBox? ancestor = context.findAncestorRenderObjectOfType<RenderBox>();

    Offset localPosition = ancestor!.globalToLocal(globalPosition);

    if (localPosition.dy < 0) {
      localPosition = Offset(localPosition.dx, 0);
    }

    if (localPosition.dx < 0) {
      localPosition = Offset(0, localPosition.dy);
    }

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
    widget.draggablePositionRect =
        Rect.fromLTWH(previewX, previewY, width, height);

    addWidget(widget);
    _containerDraggingIn = null;

    refresh();
  }

  void addNT4DragInWidget(
      DraggableNT4WidgetContainer widget, Offset globalOffset) {
    _containerDraggingIn = MapEntry(widget, globalOffset);
    refresh();
  }

  void placeNT4DragInWidget(DraggableNT4WidgetContainer widget) {
    if (_containerDraggingIn == null) {
      return;
    }

    Offset globalPosition = _containerDraggingIn!.value;

    BuildContext? context = (key as GlobalKey).currentContext;

    if (context == null) {
      return;
    }

    RenderBox? ancestor = context.findAncestorRenderObjectOfType<RenderBox>();

    Offset localPosition = ancestor!.globalToLocal(globalPosition);

    if (localPosition.dy < 0) {
      localPosition = Offset(localPosition.dx, 0);
    }

    if (localPosition.dx < 0) {
      localPosition = Offset(0, localPosition.dy);
    }

    double previewX = DraggableWidgetContainer.snapToGrid(localPosition.dx);
    double previewY = DraggableWidgetContainer.snapToGrid(localPosition.dy);

    double width = widget.displayRect.width;
    double height = widget.displayRect.height;

    Rect previewLocation = Rect.fromLTWH(previewX, previewY, width, height);

    if (isValidLayoutLocation(widget, previewLocation, widget.cursorLocation)) {
      DraggableLayoutContainer layoutContainer =
          getLayoutAtLocation(previewLocation, widget.cursorLocation)!;

      if (layoutContainer.willAcceptWidget(widget)) {
        layoutContainer.addWidget(widget, localPosition: widget.cursorLocation);
      }
    } else if (!isValidLocation(previewLocation)) {
      _containerDraggingIn = null;

      if (widget.child is NT4Widget) {
        (widget.child as NT4Widget)
          ..dispose()
          ..unSubscribe();
      }

      refresh();
      return;
    } else {
      widget.displayRect = previewLocation;
      widget.draggablePositionRect =
          Rect.fromLTWH(previewX, previewY, width, height);

      addNT4Widget(
          widget,
          Rect.fromLTWH(previewLocation.left, previewLocation.top,
              previewLocation.width, previewLocation.height),
          enabled: nt4Connection.isNT4Connected);
    }

    _containerDraggingIn = null;

    if (widget.child is NT4Widget) {
      (widget.child as NT4Widget).dispose();
    }

    refresh();
  }

  DraggableNT4WidgetContainer? createNT4WidgetContainer(
      WidgetContainer? widget) {
    if (widget == null || widget.child == null) {
      return null;
    }

    if (widget.child is! NT4Widget) {
      return null;
    }

    return DraggableNT4WidgetContainer(
      key: UniqueKey(),
      title: widget.title,
      validMoveLocation: isValidMoveLocation,
      validLayoutLocation: isValidLayoutLocation,
      enabled: nt4Connection.isNT4Connected,
      initialPosition: Rect.fromLTWH(
        0.0,
        0.0,
        Globals.gridSize.toDouble(),
        Globals.gridSize.toDouble(),
      ),
      onUpdate: _nt4ContainerOnUpdate,
      onDragBegin: _nt4ContainerOnDragBegin,
      onDragEnd: _nt4ContainerOnDragEnd,
      onResizeBegin: _nt4ContainerOnResizeBegin,
      onResizeEnd: _nt4ContainerOnResizeEnd,
      child: widget.child as NT4Widget,
    );
  }

  DraggableListLayout createListLayout() {
    return DraggableListLayout(
      key: UniqueKey(),
      title: 'List Layout',
      initialPosition: Rect.fromLTWH(
        0.0,
        0.0,
        Globals.gridSize.toDouble(),
        Globals.gridSize.toDouble(),
      ),
      enabled: nt4Connection.isNT4Connected,
      validMoveLocation: isValidMoveLocation,
      onDragOutUpdate: _layoutOnDragOutUpdate,
      onDragOutEnd: _layoutOnDragOutEnd,
      onUpdate: _layoutContainerOnUpdate,
      onDragBegin: _layoutContainerOnDragBegin,
      onDragEnd: _layoutContainerOnDragEnd,
      onResizeBegin: _layoutContainerOnResizeBegin,
      onResizeEnd: _layoutContainerOnResizeEnd,
    );
  }

  void addWidget(DraggableWidgetContainer widget) {
    _widgetContainers.add(widget);
  }

  void addNT4Widget(DraggableNT4WidgetContainer widget, Rect initialPosition,
      {bool enabled = true}) {
    _widgetContainers.add(widget);
  }

  void addWidgetFromTabJson(Map<String, dynamic> widgetData) {
    // If the widget is already in the tab, don't add it
    for (DraggableNT4WidgetContainer container
        in _widgetContainers.whereType<DraggableNT4WidgetContainer>()) {
      String? title = container.title;
      String? type = container.child?.type;
      String? topic = container.child?.topic;

      if (title == null || type == null || topic == null) {
        continue;
      }

      if (title == widgetData['title'] &&
          type == widgetData['type'] &&
          topic == widgetData['properties']['topic']) {
        return;
      }
    }

    _widgetContainers.add(DraggableNT4WidgetContainer.fromJson(
      key: UniqueKey(),
      enabled: nt4Connection.isNT4Connected,
      validMoveLocation: isValidMoveLocation,
      validLayoutLocation: isValidLayoutLocation,
      jsonData: widgetData,
      onUpdate: _nt4ContainerOnUpdate,
      onDragBegin: _nt4ContainerOnDragBegin,
      onDragEnd: _nt4ContainerOnDragEnd,
      onResizeBegin: _nt4ContainerOnResizeBegin,
      onResizeEnd: _nt4ContainerOnResizeEnd,
    ));

    refresh();
  }

  void removeWidget(DraggableWidgetContainer widget) {
    widget.dispose();
    widget.unSubscribe();
    _widgetContainers.remove(widget);
    refresh();
  }

  void clearWidgets() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.dispose();
      container.unSubscribe();
    }
    _widgetContainers.clear();
    refresh();
  }

  void onDestroy() {
    for (DraggableWidgetContainer container in _widgetContainers) {
      container.dispose();
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
    model = context.watch<DashboardGridModel?>();

    List<Widget> dashboardWidgets = [];
    List<Widget> draggingWidgets = [];
    List<Widget> draggingInWidgets = [];
    List<Widget> previewOutlines = [];

    for (DraggableNT4WidgetContainer container in _nt4DraggingContainers) {
      // Add the widget container above the others
      draggingWidgets.add(
        Positioned(
          left: container.draggablePositionRect.left,
          top: container.draggablePositionRect.top,
          child: container.getDraggingWidgetContainer(context),
        ),
      );

      // Display the outline so it doesn't get covered
      if (!container.draggingIntoLayout) {
        previewOutlines.add(
          container.getDefaultPreview(),
        );
      } else {
        DraggableLayoutContainer? layoutContainer = getLayoutAtLocation(
            container.draggablePositionRect, container.cursorLocation);

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
                visible: container.model?.previewVisible ?? false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(Globals.cornerRadius),
                    border: Border.all(color: Colors.yellow, width: 5.0),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    for (DraggableWidgetContainer container in _layoutDraggingContainers) {
      // Add the widget container above the others
      draggingWidgets.add(
        Positioned(
          left: container.draggablePositionRect.left,
          top: container.draggablePositionRect.top,
          child: container.getDraggingWidgetContainer(context),
        ),
      );

      // Display the outline so it doesn't get covered
      previewOutlines.add(
        container.getDefaultPreview(),
      );
    }

    for (DraggableWidgetContainer container in _widgetContainers) {
      dashboardWidgets.add(
        ContextMenuArea(
          builder: (context) => [
            ListTile(
              enabled: false,
              dense: true,
              visualDensity:
                  const VisualDensity(horizontal: 0.0, vertical: -4.0),
              title: Center(child: Text(container.title ?? '')),
            ),
            ListTile(
              dense: true,
              visualDensity:
                  const VisualDensity(horizontal: 0.0, vertical: -4.0),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Properties'),
              onTap: () {
                Navigator.of(context).pop();
                container.showEditProperties(context);
              },
            ),
            ListTile(
              dense: true,
              visualDensity:
                  const VisualDensity(horizontal: 0.0, vertical: -4.0),
              leading: const Icon(Icons.delete_outlined),
              title: const Text('Remove'),
              onTap: () {
                Navigator.of(context).pop();
                removeWidget(container);
              },
            ),
          ],
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
      Offset globalOffset = _containerDraggingIn!.value;

      RenderBox? ancestor = context.findAncestorRenderObjectOfType<RenderBox>();

      Offset localPosition = ancestor!.globalToLocal(globalOffset);

      if (localPosition.dx < 0) {
        localPosition = Offset(0, localPosition.dy);
      }

      if (localPosition.dy < 0) {
        localPosition = Offset(localPosition.dx, 0);
      }

      draggingInWidgets.add(
        Positioned(
          left: localPosition.dx,
          top: localPosition.dy,
          child: container.getWidgetContainer(context),
        ),
      );

      double previewX = DraggableWidgetContainer.snapToGrid(localPosition.dx);
      double previewY = DraggableWidgetContainer.snapToGrid(localPosition.dy);

      Rect previewLocation = Rect.fromLTWH(previewX, previewY,
          container.displayRect.width, container.displayRect.height);

      bool validLocation = isValidLocation(previewLocation) ||
          isValidLayoutLocation(
              container, previewLocation, container.cursorLocation);

      Color borderColor =
          (validLocation) ? Colors.lightGreenAccent.shade400 : Colors.red;

      if (isValidLayoutLocation(
          container, previewLocation, container.cursorLocation)) {
        DraggableLayoutContainer layoutContainer =
            getLayoutAtLocation(previewLocation, container.cursorLocation)!;

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
              borderRadius: BorderRadius.circular(Globals.cornerRadius),
              border: Border.all(color: borderColor, width: 5.0),
            ),
          ),
        ),
      );
    }

    defaultMenuBuilder(context) => [
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: 0.0, vertical: -4.0),
            leading: const Icon(Icons.add),
            title: const Text('Add Widget'),
            onTap: () {
              Navigator.of(context).pop();
              onAddWidgetPressed?.call();
            },
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: 0.0, vertical: -4.0),
            leading: const Icon(Icons.clear),
            title: const Text('Clear Layout'),
            onTap: () {
              Navigator.of(context).pop();
              clearWidgets();
            },
          ),
        ];

    return GestureDetector(
      // Needed to prevent 2 context menus from showing at the same time
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        if (!isValidLocation(Rect.fromLTWH(
            details.localPosition.dx, details.localPosition.dy, 0, 0))) {
          return;
        }
        showContextMenu(
          details.globalPosition,
          context,
          defaultMenuBuilder,
          8.0,
          320.0,
        );
      },
      onLongPressStart: (details) {
        if (!isValidLocation(Rect.fromLTWH(
            details.localPosition.dx, details.localPosition.dy, 0, 0))) {
          return;
        }
        showContextMenu(
          details.globalPosition,
          context,
          defaultMenuBuilder,
          8.0,
          320.0,
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
