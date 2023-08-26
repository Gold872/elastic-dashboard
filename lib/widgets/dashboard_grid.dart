import 'package:contextmenu/contextmenu.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
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

  final List<DraggableNT4WidgetContainer> _widgetContainers = [];
  final List<DraggableNT4WidgetContainer> _draggingContainers = [];

  MapEntry<WidgetContainer, Offset>? _containerDraggingIn;

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
    if (jsonData != null && jsonData!['containers'] != null) {
      loadFromJson(jsonData!);
    }
  }

  void loadFromJson(Map<String, dynamic> jsonData) {
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
          _draggingContainers.add(widget);
          refresh();
        },
        onDragEnd: (widget) {
          _draggingContainers.toSet().lookup(widget)?.child?.dispose();
          _draggingContainers.remove(widget);
          refresh();
        },
        onResizeBegin: (widget) {
          _draggingContainers.add(widget);
          refresh();
        },
        onResizeEnd: (widget) {
          _draggingContainers.toSet().lookup(widget)?.child?.dispose();
          _draggingContainers.remove(widget);
          refresh();
        },
      ));
    }
  }

  Map<String, dynamic> toJson() {
    var containers = [];
    for (DraggableNT4WidgetContainer container in _widgetContainers) {
      containers.add(container.toJson());
    }

    return {
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

    for (DraggableNT4WidgetContainer container in _widgetContainers) {
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
    for (DraggableNT4WidgetContainer container in _widgetContainers) {
      if (container.displayRect.overlaps(location)) {
        return false;
      }
    }
    return true;
  }

  void onNTConnect() {
    for (DraggableNT4WidgetContainer container in _widgetContainers) {
      container.enabled = true;

      container.refresh();
    }

    refresh();
  }

  void onNTDisconnect() {
    for (DraggableNT4WidgetContainer container in _widgetContainers) {
      container.enabled = false;

      container.refresh();
    }

    refresh();
  }

  void addDragInWidget(WidgetContainer widget, Offset globalOffset) {
    _containerDraggingIn = MapEntry(widget, globalOffset);
    refresh();
  }

  void placeDragInWidget(WidgetContainer widget) {
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

    Rect previewLocation =
        Rect.fromLTWH(previewX, previewY, widget.width, widget.height);

    if (!isValidLocation(previewLocation)) {
      _containerDraggingIn = null;

      if (widget.child is NT4Widget) {
        (widget.child as NT4Widget)
          ..dispose()
          ..unSubscribe();
      }

      refresh();
      return;
    }

    addWidget(
        widget,
        Rect.fromLTWH(previewLocation.left, previewLocation.top,
            previewLocation.width, previewLocation.height),
        enabled: nt4Connection.isNT4Connected);

    _containerDraggingIn = null;

    if (widget.child is NT4Widget) {
      (widget.child as NT4Widget).dispose();
    }

    refresh();
  }

  void addWidget(WidgetContainer widget, Rect initialPosition,
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
          _draggingContainers.add(widget);
          refresh();
        },
        onDragEnd: (widget) {
          _draggingContainers.remove(widget);
          refresh();
        },
        onResizeBegin: (widget) {
          _draggingContainers.add(widget);
          refresh();
        },
        onResizeEnd: (widget) {
          _draggingContainers.remove(widget);
          refresh();
        },
        child: widget.child! as NT4Widget));
  }

  void removeWidget(DraggableNT4WidgetContainer widget) {
    _widgetContainers.remove(widget);
    widget.child?.dispose();
    widget.child?.unSubscribe();
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

    for (DraggableNT4WidgetContainer container in _draggingContainers) {
      // Add the widget container above the others
      draggingWidgets.add(
        Positioned(
          left: container.draggablePositionRect.left,
          top: container.draggablePositionRect.top,
          child: WidgetContainer(
            title: container.title,
            width: container.draggablePositionRect.width,
            height: container.draggablePositionRect.height,
            opacity: (container.model?.previewVisible ?? false) ? 0.80 : 1.00,
            child: container.child,
          ),
        ),
      );

      // Display the outline so it doesn't get covered
      previewOutlines.add(
        Positioned(
          left: container.model?.preview.left,
          top: container.model?.preview.top,
          width: container.model?.preview.width,
          height: container.model?.preview.height,
          child: Visibility(
            visible: container.model?.previewVisible ?? false,
            child: Container(
              decoration: BoxDecoration(
                color: (container.model?.validLocation ?? false)
                    ? Colors.white.withOpacity(0.25)
                    : Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25.0),
                border: Border.all(
                    color: (container.model?.validLocation ?? false)
                        ? Colors.lightGreenAccent.shade400
                        : Colors.red,
                    width: 5.0),
              ),
            ),
          ),
        ),
      );
    }

    for (DraggableNT4WidgetContainer container in _widgetContainers) {
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
      WidgetContainer container = _containerDraggingIn!.key;
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
