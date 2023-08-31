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

  MapEntry<WidgetContainer, Offset>? _nt4ContainerDraggingIn;
  MapEntry<DraggableWidgetContainer, Offset>? _layoutContainerDraggingIn;

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
        jsonData: containerData,
        onUpdate: (widget) {
          refresh();
        },
        onDragBegin: (widget) {
          _nt4DraggingContainers.add(widget);
          refresh();
        },
        onDragEnd: (widget, {localPosition}) {
          _nt4DraggingContainers.toSet().lookup(widget)?.child?.dispose();
          _nt4DraggingContainers.remove(widget);
          refresh();
        },
        onResizeBegin: (widget) {
          _nt4DraggingContainers.add(widget);
          refresh();
        },
        onResizeEnd: (widget) {
          _nt4DraggingContainers.toSet().lookup(widget)?.child?.dispose();
          _nt4DraggingContainers.remove(widget);
          refresh();
        },
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
            onUpdate: (widget) {
              refresh();
            },
            onDragBegin: (widget) {
              _layoutDraggingContainers.add(widget);
              refresh();
            },
            onDragEnd: (widget, {localPosition}) {
              _layoutDraggingContainers.remove(widget);
              refresh();
            },
            onResizeBegin: (widget) {
              _layoutDraggingContainers.add(widget);
              refresh();
            },
            onResizeEnd: (widget) {
              _layoutDraggingContainers.remove(widget);
              refresh();
            },
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

  /// Returns weather `location` will overlap with widgets already on the dashboard
  bool isValidLocation(Rect location) {
    for (DraggableWidgetContainer container in _widgetContainers) {
      if (container.displayRect.overlaps(location)) {
        return false;
      }
    }
    return true;
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
    _layoutContainerDraggingIn = MapEntry(widget, globalOffset);
    refresh();
  }

  void placeLayoutDragInWidget(DraggableLayoutContainer widget) {
    if (_layoutContainerDraggingIn == null) {
      return;
    }

    Offset globalPosition = _layoutContainerDraggingIn!.value;

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
      _layoutContainerDraggingIn = null;

      refresh();
      return;
    }

    double width = widget.displayRect.width;
    double height = widget.displayRect.height;

    widget.displayRect = Rect.fromLTWH(previewX, previewY, width, height);
    widget.draggablePositionRect =
        Rect.fromLTWH(previewX, previewY, width, height);

    addWidget(widget);
    _layoutContainerDraggingIn = null;

    refresh();
  }

  void addNT4DragInWidget(WidgetContainer widget, Offset globalOffset) {
    _nt4ContainerDraggingIn = MapEntry(widget, globalOffset);
    refresh();
  }

  void placeNT4DragInWidget(WidgetContainer widget) {
    if (_nt4ContainerDraggingIn == null) {
      return;
    }

    Offset globalPosition = _nt4ContainerDraggingIn!.value;

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

    Rect previewLocation =
        Rect.fromLTWH(previewX, previewY, widget.width, widget.height);

    if (!isValidLocation(previewLocation)) {
      _nt4ContainerDraggingIn = null;

      if (widget.child is NT4Widget) {
        (widget.child as NT4Widget)
          ..dispose()
          ..unSubscribe();
      }

      refresh();
      return;
    }

    addNT4Widget(
        widget,
        Rect.fromLTWH(previewLocation.left, previewLocation.top,
            previewLocation.width, previewLocation.height),
        enabled: nt4Connection.isNT4Connected);

    _nt4ContainerDraggingIn = null;

    if (widget.child is NT4Widget) {
      (widget.child as NT4Widget).dispose();
    }

    refresh();
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
      validMoveLocation: isValidMoveLocation,
      onUpdate: (widget) {
        refresh();
      },
      onDragBegin: (widget) {
        _layoutDraggingContainers.add(widget);
        refresh();
      },
      onDragEnd: (widget, {localPosition}) {
        _layoutDraggingContainers.remove(widget);
        refresh();
      },
      onResizeBegin: (widget) {
        _layoutDraggingContainers.add(widget);
        refresh();
      },
      onResizeEnd: (widget) {
        _layoutDraggingContainers.remove(widget);
        refresh();
      },
    );
  }

  void addWidget(DraggableWidgetContainer widget) {
    _widgetContainers.add(widget);
  }

  void addNT4Widget(WidgetContainer widget, Rect initialPosition,
      {bool enabled = true}) {
    _widgetContainers.add(DraggableNT4WidgetContainer(
        key: UniqueKey(),
        title: widget.title,
        initialPosition: initialPosition,
        validMoveLocation: isValidMoveLocation,
        enabled: enabled,
        onUpdate: (widget) {
          refresh();
        },
        onDragBegin: (widget) {
          _nt4DraggingContainers.add(widget);
          refresh();
        },
        onDragEnd: (widget, {localPosition}) {
          _nt4DraggingContainers.remove(widget);
          refresh();
        },
        onResizeBegin: (widget) {
          _nt4DraggingContainers.add(widget);
          refresh();
        },
        onResizeEnd: (widget) {
          _nt4DraggingContainers.remove(widget);
          refresh();
        },
        child: widget.child! as NT4Widget));
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
      jsonData: widgetData,
      onUpdate: (widget) {
        refresh();
      },
      onDragBegin: (widget) {
        _nt4DraggingContainers.add(widget);
        refresh();
      },
      onDragEnd: (widget, {Offset? localPosition}) {
        _nt4DraggingContainers
            .whereType<DraggableNT4WidgetContainer>()
            .toSet()
            .lookup(widget)
            ?.child
            ?.dispose();
        _nt4DraggingContainers.remove(widget);
        refresh();
      },
      onResizeBegin: (widget) {
        _nt4DraggingContainers.add(widget);
        refresh();
      },
      onResizeEnd: (widget) {
        _nt4DraggingContainers.toSet().lookup(widget)?.child?.dispose();
        _nt4DraggingContainers.remove(widget);
        refresh();
      },
    ));
  }

  void removeWidget(DraggableWidgetContainer widget) {
    _widgetContainers.remove(widget);
    if (widget is DraggableNT4WidgetContainer) {
      widget.child?.dispose();
      widget.child?.unSubscribe();
    }
    refresh();
  }

  void clearWidgets() {
    _widgetContainers.clear();
    refresh();
  }

  void refresh() {
    Future(() async {
      model?.onUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    model = context.watch<DashboardGridModel?>();

    List<Widget> dashboardWidgets = [];
    List<Widget> draggingWidgets = [];
    List<Widget> draggingInWidgets = [];
    List<Widget> previewOutlines = [];

    for (DraggableWidgetContainer container in _nt4DraggingContainers) {
      // Add the widget container above the others
      draggingWidgets.add(
        Positioned(
          left: container.draggablePositionRect.left,
          top: container.draggablePositionRect.top,
          child: container.getDraggingWidgetContainer(),
        ),
      );

      // Display the outline so it doesn't get covered
      previewOutlines.add(
        container.getPreview(),
      );
    }

    for (DraggableWidgetContainer container in _layoutDraggingContainers) {
      // Add the widget container above the others
      draggingWidgets.add(
        Positioned(
          left: container.draggablePositionRect.left,
          top: container.draggablePositionRect.top,
          child: container.getDraggingWidgetContainer(),
        ),
      );

      // Display the outline so it doesn't get covered
      previewOutlines.add(
        container.getPreview(),
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
    if (_nt4ContainerDraggingIn != null) {
      WidgetContainer container = _nt4ContainerDraggingIn!.key;
      Offset globalOffset = _nt4ContainerDraggingIn!.value;

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
          child: container,
        ),
      );

      double previewX = DraggableWidgetContainer.snapToGrid(localPosition.dx);
      double previewY = DraggableWidgetContainer.snapToGrid(localPosition.dy);

      Rect previewLocation =
          Rect.fromLTWH(previewX, previewY, container.width, container.height);

      previewOutlines.add(
        Positioned(
          left: previewLocation.left,
          top: previewLocation.top,
          width: previewLocation.width,
          height: previewLocation.height,
          child: Container(
            decoration: BoxDecoration(
              color: (isValidLocation(previewLocation))
                  ? Colors.white.withOpacity(0.25)
                  : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25.0),
              border: Border.all(
                  color: (isValidLocation(previewLocation))
                      ? Colors.lightGreenAccent.shade400
                      : Colors.red,
                  width: 5.0),
            ),
          ),
        ),
      );
    }

    if (_layoutContainerDraggingIn != null) {
      DraggableWidgetContainer container = _layoutContainerDraggingIn!.key;
      Offset globalOffset = _layoutContainerDraggingIn!.value;

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
          child: container.getWidgetContainer(),
        ),
      );

      double previewX = DraggableWidgetContainer.snapToGrid(localPosition.dx);
      double previewY = DraggableWidgetContainer.snapToGrid(localPosition.dy);

      Rect previewLocation = Rect.fromLTWH(previewX, previewY,
          container.displayRect.width, container.displayRect.height);

      previewOutlines.add(
        Positioned(
          left: previewLocation.left,
          top: previewLocation.top,
          width: previewLocation.width,
          height: previewLocation.height,
          child: Container(
            decoration: BoxDecoration(
              color: (isValidLocation(previewLocation))
                  ? Colors.white.withOpacity(0.25)
                  : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25.0),
              border: Border.all(
                  color: (isValidLocation(previewLocation))
                      ? Colors.lightGreenAccent.shade400
                      : Colors.red,
                  width: 5.0),
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
