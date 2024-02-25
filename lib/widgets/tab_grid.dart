import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/field_widget.dart';
import 'draggable_containers/models/layout_container_model.dart';
import 'draggable_containers/models/list_layout_model.dart';
import 'draggable_containers/models/nt_widget_container_model.dart';
import 'draggable_containers/models/widget_container_model.dart';

// Used to refresh the tab grid when a widget is added or removed
// This doesn't use a stateful widget since everything has to be rendered at program startup or data will be lost
class TabGridModel extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

class TabGrid extends StatelessWidget {
  final List<WidgetContainerModel> _widgetModels = [];

  MapEntry<WidgetContainerModel, Offset>? _containerDraggingIn;

  final VoidCallback onAddWidgetPressed;

  TabGridModel? model;

  TabGrid({super.key, required this.onAddWidgetPressed});

  TabGrid.fromJson({
    super.key,
    required Map<String, dynamic> jsonData,
    required this.onAddWidgetPressed,
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
      _widgetModels.add(
        NTWidgetContainerModel.fromJson(
          enabled: ntConnection.isNT4Connected,
          jsonData: containerData,
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

      late WidgetContainerModel widget;

      switch (layoutData['type']) {
        case 'List Layout':
          widget = ListLayoutModel.fromJson(
            jsonData: layoutData,
            enabled: ntConnection.isNT4Connected,
            tabGrid: this,
            onDragCancel: _layoutContainerOnDragCancel,
            minWidth: 128.0 * 2,
            minHeight: 128.0 * 2,
            onJsonLoadingWarning: onJsonLoadingWarning,
          );
        default:
          continue;
      }

      _widgetModels.add(widget);
    }
  }

  Map<String, dynamic> toJson() {
    var containers = [];
    var layouts = [];
    for (WidgetContainerModel model in _widgetModels) {
      if (model is NTWidgetContainerModel) {
        containers.add(model.toJson());
      } else {
        layouts.add(model.toJson());
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
  bool isValidMoveLocation(WidgetContainerModel widget, Rect location) {
    BuildContext? context = (key as GlobalKey).currentContext;
    Size? gridSize;
    if (context != null) {
      gridSize = MediaQuery.of(context).size;
    }

    for (WidgetContainerModel container in _widgetModels) {
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
    for (WidgetContainerModel container in _widgetModels) {
      if (container.displayRect.overlaps(location)) {
        return false;
      }
    }
    return true;
  }

  LayoutContainerModel? getLayoutAtLocation(Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    for (LayoutContainerModel container
        in _widgetModels.whereType<LayoutContainerModel>()) {
      if (container.displayRect.contains(localPosition)) {
        return container;
      }
    }

    return null;
  }

  void onWidgetResizeEnd(WidgetContainerModel model) {
    if (model.validLocation) {
      model.setDraggingRect(model.previewRect);
    } else {
      model.setDraggingRect(model.dragStartLocation);
    }

    model.setDisplayRect(model.draggingRect);

    model.setPreviewRect(model.draggingRect);
    model.setPreviewVisible(false);
    model.setValidLocation(true);

    if (model is NTWidgetContainerModel &&
        model.childModel is FieldWidgetModel) {
      model.childModel.refresh();
    }

    model.disposeModel();
  }

  void onWidgetDragEnd(WidgetContainerModel model) {
    if (model.validLocation) {
      model.setDraggingRect(model.previewRect);
    } else {
      model.setDraggingRect(model.dragStartLocation);
    }

    model.setDisplayRect(model.draggingRect);

    model.setPreviewRect(model.draggingRect);
    model.setPreviewVisible(false);
    model.setValidLocation(true);

    model.disposeModel(deleting: false);
  }

  void onWidgetDragCancel(WidgetContainerModel model) {
    if (!model.dragging && !model.resizing) {
      return;
    }

    model.setDraggingRect(model.dragStartLocation);
    model.setDisplayRect(model.draggingRect);
    model.setPreviewRect(model.draggingRect);

    model.setPreviewVisible(false);
    model.setValidLocation(true);

    model.setDragging(false);
    model.setResizing(false);
    model.setDraggingIntoLayout(false);

    model.disposeModel();
  }

  void onWidgetUpdate(
      WidgetContainerModel model, Rect newRect, TransformResult result) {
    double newWidth = max(newRect.width, model.minWidth);
    double newHeight = max(newRect.height, model.minHeight);

    Rect constrainedRect = newRect;

    if (model.resizing) {
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
        constrainedRect.width.clamp(model.minWidth, double.infinity));
    double previewHeight = DraggableWidgetContainer.snapToGrid(
        constrainedRect.height.clamp(model.minHeight, double.infinity));

    if (previewWidth < model.minWidth) {
      previewWidth = DraggableWidgetContainer.snapToGrid(
          constrainedRect.width.clamp(model.minWidth, double.infinity) +
              Settings.gridSize);
    }

    if (previewHeight < model.minHeight) {
      previewHeight = DraggableWidgetContainer.snapToGrid(
          constrainedRect.height.clamp(model.minHeight, double.infinity) +
              Settings.gridSize);
    }

    Rect preview =
        Rect.fromLTWH(previewX, previewY, previewWidth, previewHeight);

    model.setDraggingRect(constrainedRect);
    model.setPreviewRect(preview);
    model.setPreviewVisible(true);

    bool validLocation = isValidMoveLocation(model, preview);

    if (validLocation) {
      model.setValidLocation(true);

      model.setDraggingIntoLayout(false);
    } else {
      validLocation = isValidLayoutLocation(model.cursorGlobalLocation) &&
          model is! LayoutContainerModel &&
          !model.resizing;

      model.setDraggingIntoLayout(validLocation);

      model.setValidLocation(validLocation);
    }
  }

  void _ntContainerOnUpdate(
      WidgetContainerModel widget, Rect newRect, TransformResult result) {
    onWidgetUpdate(widget, newRect, result);

    refresh();
  }

  void _ntContainerOnDragBegin(WidgetContainerModel widget) {
    refresh();
  }

  void _ntContainerOnDragEnd(WidgetContainerModel model, Rect releaseRect,
      {Offset? globalPosition}) {
    onWidgetDragEnd(model);

    NTWidgetContainerModel ntContainer = model as NTWidgetContainerModel;

    if (model.draggingIntoLayout && globalPosition != null) {
      LayoutContainerModel? layoutModel = getLayoutAtLocation(globalPosition);

      if (layoutModel != null) {
        layoutModel.addWidget(ntContainer);
        _widgetModels.remove(ntContainer);
      }
    }
    refresh();
  }

  void _ntContainerOnDragCancel(WidgetContainerModel widget) {
    onWidgetDragCancel(widget);

    refresh();
  }

  void _ntContainerOnResizeBegin(WidgetContainerModel widget) {
    refresh();
  }

  void _ntContainerOnResizeEnd(WidgetContainerModel widget, Rect releaseRect) {
    onWidgetResizeEnd(widget);

    refresh();
  }

  void _layoutContainerOnUpdate(
      WidgetContainerModel widget, Rect newRect, TransformResult result) {
    onWidgetUpdate(widget, newRect, result);

    refresh();
  }

  void _layoutContainerOnDragBegin(WidgetContainerModel widget) {
    refresh();
  }

  void _layoutContainerOnDragEnd(WidgetContainerModel widget, Rect releaseRect,
      {Offset? globalPosition}) {
    onWidgetDragEnd(widget);

    refresh();
  }

  void _layoutContainerOnDragCancel(WidgetContainerModel widget) {
    onWidgetDragCancel(widget);

    refresh();
  }

  void _layoutContainerOnResizeBegin(WidgetContainerModel widget) {
    refresh();
  }

  void _layoutContainerOnResizeEnd(
      WidgetContainerModel widget, Rect releaseRect) {
    onWidgetResizeEnd(widget);

    refresh();
  }

  void layoutDragOutEnd(WidgetContainerModel widget) {
    if (widget is NTWidgetContainerModel) {
      placeDragInWidget(widget, true);
    }
  }

  void layoutDragOutUpdate(WidgetContainerModel model, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    model.setDraggingRect(
      Rect.fromLTWH(
        localPosition.dx,
        localPosition.dy,
        model.draggingRect.width,
        model.draggingRect.height,
      ),
    );
    _containerDraggingIn = MapEntry(model, globalPosition);
    refresh();
  }

  void onNTConnect() {
    for (WidgetContainerModel model in _widgetModels) {
      model.setEnabled(true);
    }

    refresh();
  }

  void onNTDisconnect() {
    for (WidgetContainerModel container in _widgetModels) {
      container.setEnabled(false);
    }

    refresh();
  }

  void addDragInWidget(WidgetContainerModel widget, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    widget.setDraggingRect(
      Rect.fromLTWH(
        localPosition.dx,
        localPosition.dy,
        widget.draggingRect.width,
        widget.draggingRect.height,
      ),
    );
    _containerDraggingIn = MapEntry(widget, globalPosition);
    refresh();
  }

  void placeDragInWidget(WidgetContainerModel widget,
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
    widget.setPreviewRect(previewLocation);

    widget.tryCast<NTWidgetContainerModel>()?.updateMinimumSize();
    widget.setEnabled(ntConnection.isNT4Connected);

    // If dragging into layout
    if (widget is NTWidgetContainerModel &&
        isValidLayoutLocation(widget.cursorGlobalLocation)) {
      LayoutContainerModel layoutContainer =
          getLayoutAtLocation(widget.cursorGlobalLocation)!;

      if (layoutContainer.willAcceptWidget(widget)) {
        layoutContainer.addWidget(widget);
      }
    } else if (!isValidMoveLocation(widget, previewLocation)) {
      _containerDraggingIn = null;

      widget.disposeModel(deleting: !fromLayout);
      if (!fromLayout) {
        widget.unSubscribe();
        widget.forceDispose();
      }

      refresh();
      return;
    } else {
      widget.displayRect = previewLocation;
      widget.draggingRect = Rect.fromLTWH(previewX, previewY, width, height);

      addWidget(widget);
    }

    _containerDraggingIn = null;

    widget.disposeModel();

    refresh();
  }

  ListLayoutModel createListLayout(
      {String title = 'List Layout', List<NTWidgetContainerModel>? children}) {
    return ListLayoutModel(
      title: title,
      initialPosition: Rect.fromLTWH(
        0.0,
        0.0,
        Settings.gridSize.toDouble() * 2,
        Settings.gridSize.toDouble() * 2,
      ),
      children: children,
      minWidth: 128.0,
      minHeight: 128.0,
      tabGrid: this,
      onDragCancel: _layoutContainerOnDragCancel,
    );
  }

  void addWidget(WidgetContainerModel widget) {
    _widgetModels.add(widget);
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
      for (NTWidgetContainerModel container
          in _widgetModels.whereType<NTWidgetContainerModel>()) {
        String? title = container.title;
        String? type = container.childModel.type;
        String? topic = container.childModel.topic;
        bool validLocation = isValidLocation(newWidgetLocation);

        if (title == widgetData['title'] &&
            type == widgetData['type'] &&
            topic == widgetData['properties']['topic'] &&
            !validLocation) {
          return;
        }
      }
    } else {
      for (LayoutContainerModel container
          in _widgetModels.whereType<LayoutContainerModel>()) {
        String? title = container.title;
        String type = container.type;
        bool validLocation = isValidLocation(newWidgetLocation);

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
          _widgetModels.add(
            ListLayoutModel.fromJson(
              jsonData: widgetData,
              enabled: ntConnection.isNT4Connected,
              tabGrid: this,
              onDragCancel: _layoutContainerOnDragCancel,
              minWidth: 128.0 * 2,
              minHeight: 128.0 * 2,
            ),
          );
          break;
      }
    } else {
      _widgetModels.add(
        NTWidgetContainerModel.fromJson(
          enabled: ntConnection.isNT4Connected,
          jsonData: widgetData,
        ),
      );
    }

    refresh();
  }

  void removeWidget(WidgetContainerModel widget) {
    widget.disposeModel(deleting: true);
    widget.unSubscribe();
    widget.forceDispose();
    _widgetModels.remove(widget);
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

              for (WidgetContainerModel container in _widgetModels) {
                container.disposeModel(deleting: true);
                container.unSubscribe();
                container.forceDispose();
              }
              _widgetModels.clear();
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

  void lockLayout() {
    for (WidgetContainerModel container in _widgetModels) {
      container.setDraggable(false);
    }
  }

  void unlockLayout() {
    for (WidgetContainerModel container in _widgetModels) {
      container.setDraggable(true);
    }
  }

  void onDestroy() {
    for (WidgetContainerModel container in _widgetModels) {
      container.disposeModel(deleting: true);
      container.unSubscribe();
      container.forceDispose();
    }
    _widgetModels.clear();
  }

  void refresh() {
    Future(() async {
      model?.notify();
    });
  }

  void resizeGrid(int oldSize, int newSize) {
    for (WidgetContainerModel widget in _widgetModels) {
      widget.updateGridSize(oldSize, newSize);
    }
    refresh();
  }

  void refreshAllContainers() {
    Future(() async {
      for (WidgetContainerModel widget in _widgetModels) {
        widget.notifyListeners();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    model = context.watch<TabGridModel>();

    Widget getWidgetFromModel(WidgetContainerModel model) {
      if (model is NTWidgetContainerModel) {
        return ChangeNotifierProvider<NTWidgetContainerModel>.value(
          value: model,
          child: DraggableNTWidgetContainer(
            key: model.key,
            tabGrid: this,
            onUpdate: _ntContainerOnUpdate,
            onDragBegin: _ntContainerOnDragBegin,
            onDragEnd: _ntContainerOnDragEnd,
            onDragCancel: _ntContainerOnDragCancel,
            onResizeBegin: _ntContainerOnResizeBegin,
            onResizeEnd: _ntContainerOnResizeEnd,
          ),
        );
      } else if (model is ListLayoutModel) {
        return ChangeNotifierProvider<ListLayoutModel>.value(
          value: model,
          child: DraggableListLayout(
            key: model.key,
            tabGrid: this,
            onUpdate: _layoutContainerOnUpdate,
            onDragBegin: _layoutContainerOnDragBegin,
            onDragEnd: _layoutContainerOnDragEnd,
            onDragCancel: _layoutContainerOnDragCancel,
            onResizeBegin: _layoutContainerOnResizeBegin,
            onResizeEnd: _layoutContainerOnResizeEnd,
          ),
        );
      }
      return Container();
    }

    List<Widget> dashboardWidgets = [];
    List<Widget> draggingWidgets = [];
    List<Widget> draggingInWidgets = [];
    List<Widget> previewOutlines = [];

    for (WidgetContainerModel container in _widgetModels) {
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
          LayoutContainerModel? layoutContainer =
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
            if (Settings.layoutLocked) {
              return;
            }
            List<ContextMenuEntry> menuEntries = [
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
            ];

            ContextMenu contextMenu = ContextMenu(
              position: details.globalPosition,
              borderRadius: BorderRadius.circular(5.0),
              padding: const EdgeInsets.all(4.0),
              entries: menuEntries,
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
          child: getWidgetFromModel(container),
        ),
      );
    }

    // Also render any containers that are being dragged into the grid
    if (_containerDraggingIn != null) {
      WidgetContainerModel container = _containerDraggingIn!.key;

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

      bool validLocation = isValidMoveLocation(container, previewLocation) ||
          isValidLayoutLocation(container.cursorGlobalLocation);

      Color borderColor =
          (validLocation) ? Colors.lightGreenAccent.shade400 : Colors.red;

      if (isValidLayoutLocation(container.cursorGlobalLocation)) {
        LayoutContainerModel layoutContainer =
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
        if (Settings.layoutLocked) {
          return;
        }
        ContextMenu contextMenu = ContextMenu(
          position: details.globalPosition,
          borderRadius: BorderRadius.circular(5.0),
          padding: const EdgeInsets.all(4.0),
          entries: [
            MenuItem(
              label: 'Add Widget',
              icon: Icons.add,
              onSelected: () => onAddWidgetPressed.call(),
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
