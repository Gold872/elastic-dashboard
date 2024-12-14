import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
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
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final List<WidgetContainerModel> _widgetModels = [];

  static Map<String, dynamic>? copyJsonData;

  MapEntry<WidgetContainerModel, Offset>? _containerDraggingIn;
  BuildContext? tabGridContext;

  final VoidCallback onAddWidgetPressed;

  TabGridModel(
      {required this.ntConnection,
      required this.preferences,
      required this.onAddWidgetPressed});

  TabGridModel.fromJson({
    required this.ntConnection,
    required this.preferences,
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

    for (WidgetContainerModel model in _widgetModels) {
      model.addListener(notifyListeners);
    }
  }

  void loadContainersFromJson(Map<String, dynamic> jsonData,
      {Function(String message)? onJsonLoadingWarning}) {
    for (Map<String, dynamic> containerData in jsonData['containers']) {
      _widgetModels.add(
        NTWidgetContainerModel.fromJson(
          ntConnection: ntConnection,
          preferences: preferences,
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
            preferences: preferences,
            jsonData: layoutData,
            ntWidgetBuilder: (preferences, jsonData, enabled,
                    {onJsonLoadingWarning}) =>
                NTWidgetContainerModel.fromJson(
              ntConnection: ntConnection,
              jsonData: jsonData,
              preferences: preferences,
              onJsonLoadingWarning: onJsonLoadingWarning,
            ),
            enabled: ntConnection.isNT4Connected,
            dragOutFunctions: (
              dragOutUpdate: layoutDragOutUpdate,
              dragOutEnd: layoutDragOutEnd,
            ),
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
    if (tabGridContext == null) {
      return Offset.zero;
    }

    RenderBox? ancestor =
        tabGridContext!.findAncestorRenderObjectOfType<RenderBox>();

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
    Size? gridSize;
    if (tabGridContext != null) {
      gridSize = MediaQuery.of(tabGridContext!).size;
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
      model.draggingRect = model.previewRect;
    } else {
      model.draggingRect = model.dragStartLocation;
    }

    model.displayRect = model.draggingRect;

    model.previewRect = model.draggingRect;
    model.previewVisible = false;
    model.validLocation = true;

    if (model is NTWidgetContainerModel &&
        model.childModel is FieldWidgetModel) {
      model.childModel.refresh();
    }

    model.disposeModel();
  }

  void onWidgetDragEnd(WidgetContainerModel model) {
    if (model.validLocation) {
      model.draggingRect = model.previewRect;
    } else {
      model.draggingRect = model.dragStartLocation;
    }

    model.displayRect = model.draggingRect;

    model.previewRect = model.draggingRect;
    model.previewVisible = false;
    model.validLocation = true;

    model.disposeModel(deleting: false);
  }

  void onWidgetDragCancel(WidgetContainerModel model) {
    if (!model.dragging && !model.resizing) {
      return;
    }

    model.draggingRect = model.dragStartLocation;
    model.displayRect = model.draggingRect;
    model.previewRect = model.draggingRect;

    model.previewVisible = false;
    model.validLocation = true;

    model.dragging = false;
    model.resizing = false;
    model.draggingIntoLayout = false;

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

    int? gridSize = preferences.getInt(PrefKeys.gridSize);

    double previewX =
        DraggableWidgetContainer.snapToGrid(constrainedRect.left, gridSize);
    double previewY =
        DraggableWidgetContainer.snapToGrid(constrainedRect.top, gridSize);

    double previewWidth = DraggableWidgetContainer.snapToGrid(
        constrainedRect.width.clamp(model.minWidth, double.infinity), gridSize);
    double previewHeight = DraggableWidgetContainer.snapToGrid(
        constrainedRect.height.clamp(model.minHeight, double.infinity),
        gridSize);

    if (previewWidth < model.minWidth) {
      previewWidth = DraggableWidgetContainer.snapToGrid(
          constrainedRect.width.clamp(model.minWidth, double.infinity) +
              (gridSize ?? Defaults.gridSize),
          gridSize);
    }

    if (previewHeight < model.minHeight) {
      previewHeight = DraggableWidgetContainer.snapToGrid(
          constrainedRect.height.clamp(model.minHeight, double.infinity) +
              (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize),
          gridSize);
    }

    Rect preview =
        Rect.fromLTWH(previewX, previewY, previewWidth, previewHeight);

    model.draggingRect = constrainedRect;
    model.previewRect = preview;
    model.previewVisible = true;

    bool validLocation = isValidMoveLocation(model, preview);

    if (validLocation) {
      model.validLocation = true;
      model.draggingIntoLayout = false;
    } else {
      validLocation = isValidLayoutLocation(model.cursorGlobalLocation) &&
          model is! LayoutContainerModel &&
          !model.resizing;

      model.draggingIntoLayout = validLocation;
      model.validLocation = validLocation;
    }
  }

  void _ntContainerOnUpdate(
      WidgetContainerModel widget, Rect newRect, TransformResult result) {
    onWidgetUpdate(widget, newRect, result);
  }

  void _ntContainerOnDragBegin(WidgetContainerModel widget) {}

  void _ntContainerOnDragEnd(WidgetContainerModel model, Rect releaseRect,
      {Offset? globalPosition}) {
    onWidgetDragEnd(model);

    NTWidgetContainerModel ntContainer = model as NTWidgetContainerModel;

    if (model.draggingIntoLayout && globalPosition != null) {
      LayoutContainerModel? layoutModel = getLayoutAtLocation(globalPosition);

      if (layoutModel != null) {
        layoutModel.addWidget(ntContainer);
        _widgetModels.remove(ntContainer);
        ntContainer.removeListener(notifyListeners);
      }
    }
  }

  void _ntContainerOnDragCancel(WidgetContainerModel widget) {
    onWidgetDragCancel(widget);
  }

  void _ntContainerOnResizeBegin(WidgetContainerModel widget) {}

  void _ntContainerOnResizeEnd(WidgetContainerModel widget, Rect releaseRect) {
    onWidgetResizeEnd(widget);
  }

  void _layoutContainerOnUpdate(
      WidgetContainerModel widget, Rect newRect, TransformResult result) {
    onWidgetUpdate(widget, newRect, result);
  }

  void _layoutContainerOnDragBegin(WidgetContainerModel widget) {}

  void _layoutContainerOnDragEnd(WidgetContainerModel widget, Rect releaseRect,
      {Offset? globalPosition}) {
    onWidgetDragEnd(widget);
  }

  void _layoutContainerOnDragCancel(WidgetContainerModel widget) {
    onWidgetDragCancel(widget);
  }

  void _layoutContainerOnResizeBegin(WidgetContainerModel widget) {}

  void _layoutContainerOnResizeEnd(
      WidgetContainerModel widget, Rect releaseRect) {
    onWidgetResizeEnd(widget);
  }

  bool layoutDragOutEnd(WidgetContainerModel widget) {
    if (widget is NTWidgetContainerModel) {
      return placeDragInWidget(widget, true);
    }
    return false;
  }

  void layoutDragOutUpdate(WidgetContainerModel model, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    model.draggingRect = Rect.fromLTWH(
      localPosition.dx,
      localPosition.dy,
      model.draggingRect.width,
      model.draggingRect.height,
    );
    _containerDraggingIn = MapEntry(model, globalPosition);
    notifyListeners();
  }

  void onNTConnect() {
    for (WidgetContainerModel model in _widgetModels) {
      model.enabled = true;
    }
  }

  void onNTDisconnect() {
    for (WidgetContainerModel container in _widgetModels) {
      container.enabled = false;
    }
  }

  void addDragInWidget(WidgetContainerModel widget, Offset globalPosition) {
    Offset localPosition = getLocalPosition(globalPosition);
    widget.draggingRect = Rect.fromLTWH(
      localPosition.dx,
      localPosition.dy,
      widget.draggingRect.width,
      widget.draggingRect.height,
    );

    _containerDraggingIn = MapEntry(widget, globalPosition);
    notifyListeners();
  }

  bool placeDragInWidget(WidgetContainerModel widget,
      [bool fromLayout = false]) {
    if (_containerDraggingIn == null) {
      return false;
    }

    Offset globalPosition = _containerDraggingIn!.value;

    Offset localPosition = getLocalPosition(globalPosition);

    int? gridSize = preferences.getInt(PrefKeys.gridSize);

    double previewX =
        DraggableWidgetContainer.snapToGrid(localPosition.dx, gridSize);
    double previewY =
        DraggableWidgetContainer.snapToGrid(localPosition.dy, gridSize);

    double width = widget.displayRect.width;
    double height = widget.displayRect.height;

    Rect previewLocation = Rect.fromLTWH(previewX, previewY, width, height);
    widget.previewRect = previewLocation;

    widget.tryCast<NTWidgetContainerModel>()?.updateMinimumSize();
    widget.enabled = ntConnection.isNT4Connected;

    // If dragging into layout
    if (widget is NTWidgetContainerModel &&
        isValidLayoutLocation(widget.cursorGlobalLocation)) {
      LayoutContainerModel layoutContainer =
          getLayoutAtLocation(widget.cursorGlobalLocation)!;

      if (layoutContainer.willAcceptWidget(widget)) {
        layoutContainer.addWidget(widget);
      } else {
        widget.disposeModel(deleting: !fromLayout);
        if (!fromLayout) {
          widget.unSubscribe();
          widget.forceDispose();
        }

        notifyListeners();
        return false;
      }
    } else if (!isValidMoveLocation(widget, previewLocation)) {
      _containerDraggingIn = null;

      widget.disposeModel(deleting: !fromLayout);
      if (!fromLayout) {
        widget.unSubscribe();
        widget.forceDispose();
      }

      notifyListeners();
      return false;
    } else {
      widget.displayRect = previewLocation;
      widget.draggingRect = Rect.fromLTWH(previewX, previewY, width, height);

      addWidget(widget);
    }

    _containerDraggingIn = null;

    widget.disposeModel();
    notifyListeners();

    return true;
  }

  ListLayoutModel createListLayout(
      {String title = 'List Layout', List<NTWidgetContainerModel>? children}) {
    return ListLayoutModel(
      preferences: preferences,
      title: title,
      initialPosition: Rect.fromLTWH(
        0.0,
        0.0,
        NTWidgetBuilder.getNormalSize(preferences.getInt(PrefKeys.gridSize)) *
            2,
        NTWidgetBuilder.getNormalSize(preferences.getInt(PrefKeys.gridSize)) *
            2,
      ),
      children: children,
      minWidth: 128.0,
      minHeight: 128.0,
      dragOutFunctions: (
        dragOutUpdate: layoutDragOutUpdate,
        dragOutEnd: layoutDragOutEnd,
      ),
      onDragCancel: _layoutContainerOnDragCancel,
    );
  }

  void addWidget(WidgetContainerModel widget) {
    _widgetModels.add(widget);
    widget.addListener(notifyListeners);
    notifyListeners();
  }

  void addWidgetFromTabJson(Map<String, dynamic> widgetData) {
    Rect newWidgetLocation = Rect.fromLTWH(
      tryCast(widgetData['x']) ?? 0.0,
      tryCast(widgetData['y']) ?? 0.0,
      tryCast(widgetData['width']) ?? 0.0,
      tryCast(widgetData['height']) ?? 0.0,
    );
    // If the widget is already in the tab, don't add it
    if (!(widgetData.containsKey('layout') && widgetData['layout'])) {
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

    if (widgetData.containsKey('layout') && widgetData['layout']) {
      switch (widgetData['type']) {
        case 'List Layout':
          addWidget(
            ListLayoutModel.fromJson(
              preferences: preferences,
              jsonData: widgetData,
              ntWidgetBuilder: (preferences, jsonData, enabled,
                      {onJsonLoadingWarning}) =>
                  NTWidgetContainerModel.fromJson(
                ntConnection: ntConnection,
                jsonData: jsonData,
                preferences: preferences,
                onJsonLoadingWarning: onJsonLoadingWarning,
              ),
              enabled: ntConnection.isNT4Connected,
              dragOutFunctions: (
                dragOutUpdate: layoutDragOutUpdate,
                dragOutEnd: layoutDragOutEnd,
              ),
              onDragCancel: _layoutContainerOnDragCancel,
              minWidth: 128.0 * 2,
              minHeight: 128.0 * 2,
            ),
          );
          break;
      }
    } else {
      addWidget(
        NTWidgetContainerModel.fromJson(
          ntConnection: ntConnection,
          preferences: preferences,
          enabled: ntConnection.isNT4Connected,
          jsonData: widgetData,
        ),
      );
    }
  }

  void removeWidget(WidgetContainerModel widget) {
    widget.removeListener(notifyListeners);
    widget.disposeModel(deleting: true);
    widget.unSubscribe();
    widget.forceDispose();
    _widgetModels.remove(widget);
    notifyListeners();
  }

  @visibleForTesting
  void clearWidgets() {
    for (WidgetContainerModel container in _widgetModels) {
      container.removeListener(notifyListeners);
      container.disposeModel(deleting: true);
      container.unSubscribe();
      container.forceDispose();
    }
    _widgetModels.clear();
    notifyListeners();
  }

  void confirmClearWidgets(BuildContext context) {
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

              clearWidgets();
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

  void copyWidget(WidgetContainerModel widget) {
    copyJsonData = widget.toJson();
  }

  void lockLayout() {
    for (WidgetContainerModel container in _widgetModels) {
      container.draggable = false;
    }
  }

  void unlockLayout() {
    for (WidgetContainerModel container in _widgetModels) {
      container.draggable = true;
    }
  }

  void onDestroy() {
    for (WidgetContainerModel container in _widgetModels) {
      container.removeListener(notifyListeners);
      container.disposeModel(deleting: true);
      container.unSubscribe();
      container.forceDispose();
    }
    _widgetModels.clear();
  }

  void resizeGrid(int oldSize, int newSize) {
    for (WidgetContainerModel widget in _widgetModels) {
      widget.updateGridSize(oldSize, newSize);
    }
    notifyListeners();
  }

  void refreshAllContainers() {
    Future(() async {
      for (WidgetContainerModel widget in _widgetModels) {
        widget.notifyListeners();
      }
    });
  }
}

class TabGrid extends StatelessWidget {
  const TabGrid({super.key});

  @override
  Widget build(BuildContext context) {
    TabGridModel model = context.watch<TabGridModel>();

    model.tabGridContext = context;

    Widget getWidgetFromModel(WidgetContainerModel widgetModel) {
      if (widgetModel is NTWidgetContainerModel) {
        return ChangeNotifierProvider<NTWidgetContainerModel>.value(
          value: widgetModel,
          child: DraggableNTWidgetContainer(
            key: widgetModel.key,
            updateFunctions: (
              onUpdate: model._ntContainerOnUpdate,
              onDragBegin: model._ntContainerOnDragBegin,
              onDragEnd: model._ntContainerOnDragEnd,
              onDragCancel: model._ntContainerOnDragCancel,
              onResizeBegin: model._ntContainerOnResizeBegin,
              onResizeEnd: model._ntContainerOnResizeEnd,
              isValidMoveLocation: model.isValidMoveLocation,
            ),
          ),
        );
      } else if (widgetModel is ListLayoutModel) {
        return ChangeNotifierProvider<ListLayoutModel>.value(
          value: widgetModel,
          child: DraggableListLayout(
            key: widgetModel.key,
            updateFunctions: (
              onUpdate: model._layoutContainerOnUpdate,
              onDragBegin: model._layoutContainerOnDragBegin,
              onDragEnd: model._layoutContainerOnDragEnd,
              onDragCancel: model._layoutContainerOnDragCancel,
              onResizeBegin: model._layoutContainerOnResizeBegin,
              onResizeEnd: model._layoutContainerOnResizeEnd,
              isValidMoveLocation: model.isValidMoveLocation,
            ),
          ),
        );
      }
      return Container();
    }

    List<Widget> dashboardWidgets = [];
    List<Widget> draggingWidgets = [];
    List<Widget> draggingInWidgets = [];
    List<Widget> previewOutlines = [];

    for (WidgetContainerModel container in model._widgetModels) {
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
              model.getLayoutAtLocation(container.cursorGlobalLocation);

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
                      borderRadius: BorderRadius.circular(
                          model.preferences.getDouble(PrefKeys.cornerRadius) ??
                              Defaults.cornerRadius),
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
          onSecondaryTapUp: (details) {
            if (model.preferences.getBool(PrefKeys.layoutLocked) ??
                Defaults.layoutLocked) {
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
                  label: 'Copy',
                  icon: Icons.copy_outlined,
                  onSelected: () {
                    model.copyWidget(container);
                  }),
              MenuItem(
                  label: 'Remove',
                  icon: Icons.delete_outlined,
                  onSelected: () {
                    model.removeWidget(container);
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
    if (model._containerDraggingIn != null) {
      WidgetContainerModel container = model._containerDraggingIn!.key;

      draggingWidgets.add(
        Positioned(
          left: container.draggingRect.left,
          top: container.draggingRect.top,
          child: IgnorePointer(
            child: container.getDraggingWidgetContainer(context),
          ),
        ),
      );

      int? gridSize = model.preferences.getInt(PrefKeys.gridSize);

      double previewX = DraggableWidgetContainer.snapToGrid(
          container.draggingRect.left, gridSize);
      double previewY = DraggableWidgetContainer.snapToGrid(
          container.draggingRect.top, gridSize);

      Rect previewLocation = Rect.fromLTWH(previewX, previewY,
          container.displayRect.width, container.displayRect.height);

      bool validLocation =
          model.isValidMoveLocation(container, previewLocation) ||
              model.isValidLayoutLocation(container.cursorGlobalLocation);

      Color borderColor =
          (validLocation) ? Colors.lightGreenAccent.shade400 : Colors.red;

      if (model.isValidLayoutLocation(container.cursorGlobalLocation)) {
        LayoutContainerModel layoutContainer =
            model.getLayoutAtLocation(container.cursorGlobalLocation)!;

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
              borderRadius: BorderRadius.circular(
                  model.preferences.getDouble(PrefKeys.cornerRadius) ??
                      Defaults.cornerRadius),
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
        if (model.preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }

        List<MenuItem> contextMenuEntries = [
          MenuItem(
            label: 'Add Widget',
            icon: Icons.add,
            onSelected: () => model.onAddWidgetPressed.call(),
          ),
          MenuItem(
            label: 'Clear Layout',
            icon: Icons.clear,
            onSelected: () => model.confirmClearWidgets(context),
          ),
        ];

        if (TabGridModel.copyJsonData != null) {
          contextMenuEntries.add(
            MenuItem(
              label: 'Paste',
              icon: Icons.paste_outlined,
              onSelected: () {
                pasteWidget(
                    model, TabGridModel.copyJsonData, details.localPosition);
              },
            ),
          );
        }

        ContextMenu contextMenu = ContextMenu(
          position: details.globalPosition,
          borderRadius: BorderRadius.circular(5.0),
          padding: const EdgeInsets.all(4.0),
          entries: contextMenuEntries,
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

  void pasteWidget(TabGridModel grid, Map<String, dynamic>? widgetJson,
      Offset localPosition) {
    if (widgetJson == null) return;

    int gridSize =
        grid.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

    // Put the top left corner of the widget in the square the user pastes it in
    double snappedX = (localPosition.dx ~/ gridSize) * gridSize.toDouble();
    double snappedY = (localPosition.dy ~/ gridSize) * gridSize.toDouble();

    widgetJson['x'] = snappedX;
    widgetJson['y'] = snappedY;

    Rect pasteLocation = Rect.fromLTWH(
      snappedX,
      snappedY,
      widgetJson['width'],
      widgetJson['height'],
    );

    if (grid.isValidLocation(pasteLocation)) {
      WidgetContainerModel copiedWidget =
          createWidgetFromJson(grid, widgetJson);

      grid.addWidget(copiedWidget);
    }
  }

  WidgetContainerModel createWidgetFromJson(
      TabGridModel grid, Map<String, dynamic> json) {
    if (json['type'] == 'List Layout') {
      return ListLayoutModel.fromJson(
        preferences: grid.preferences,
        jsonData: json,
        dragOutFunctions: (
          dragOutUpdate: grid.layoutDragOutUpdate,
          dragOutEnd: grid.layoutDragOutEnd,
        ),
        ntWidgetBuilder: (preferences, jsonData, enabled,
                {onJsonLoadingWarning}) =>
            NTWidgetContainerModel.fromJson(
          ntConnection: grid.ntConnection,
          jsonData: jsonData,
          preferences: preferences,
          onJsonLoadingWarning: onJsonLoadingWarning,
        ),
        onDragCancel: grid._layoutContainerOnDragCancel,
      );
    } else {
      return NTWidgetContainerModel.fromJson(
        ntConnection: grid.ntConnection,
        preferences: grid.preferences,
        enabled: grid.ntConnection.isNT4Connected,
        jsonData: json,
      );
    }
  }
}
