import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class WidgetContainerModel extends ChangeNotifier {
  final Key key = UniqueKey();
  final SharedPreferences preferences;

  String? title;

  late bool draggable =
      !(preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked);
  bool _disposed = false;
  bool _forceDispose = false;

  late Rect draggingRect = Rect.fromLTWH(
      0,
      0,
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble());

  Offset cursorGlobalLocation = const Offset(double.nan, double.nan);

  late Rect displayRect = Rect.fromLTWH(
      0,
      0,
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble());

  late Rect previewRect = Rect.fromLTWH(
      0,
      0,
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble());

  bool enabled = false;
  bool dragging = false;
  bool resizing = false;
  bool draggingIntoLayout = false;
  bool previewVisible = false;
  bool validLocation = true;

  late double minWidth =
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();
  late double minHeight =
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();

  late Rect dragStartLocation;

  WidgetContainerModel({
    required this.preferences,
    required Rect initialPosition,
    required this.title,
    this.enabled = false,
    this.minWidth = 128.0,
    this.minHeight = 128.0,
  }) {
    displayRect = initialPosition;
    init();
  }

  WidgetContainerModel.fromJson({
    required Map<String, dynamic> jsonData,
    required this.preferences,
    this.enabled = false,
    this.minWidth = 128.0,
    this.minHeight = 128.0,
    Function(String errorMessage)? onJsonLoadingWarning,
  }) {
    fromJson(jsonData);
    init();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (!hasListeners || _forceDispose) {
      super.dispose();
      _disposed = true;
    }
  }

  void forceDispose() {
    _forceDispose = true;
    dispose();
  }

  void init() {
    draggingRect = displayRect;
    dragStartLocation = displayRect;
  }

  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'x': displayRect.left,
      'y': displayRect.top,
      'width': displayRect.width,
      'height': displayRect.height,
    };
  }

  @mustCallSuper
  void fromJson(Map<String, dynamic> jsonData,
      {Function(String warningMessage)? onJsonLoadingWarning}) {
    title = tryCast(jsonData['title']) ?? '';

    double x = tryCast(jsonData['x']) ?? 0.0;

    double y = tryCast(jsonData['y']) ?? 0.0;

    double width = tryCast(jsonData['width']) ??
        (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();

    double height = tryCast(jsonData['height']) ??
        (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();

    displayRect = Rect.fromLTWH(x, y, width, height);
  }

  List<ContextMenuEntry> getContextMenuItems() {
    return [];
  }

  void disposeModel({bool deleting = false}) {}

  void unSubscribe() {}

  @mustCallSuper
  void updateGridSize(int oldGridSize, int newGridSize) {
    double newX =
        DraggableWidgetContainer.snapToGrid(displayRect.left, newGridSize);
    double newY =
        DraggableWidgetContainer.snapToGrid(displayRect.top, newGridSize);

    double newWidth =
        DraggableWidgetContainer.snapToGrid(displayRect.width, newGridSize)
            .clamp(minWidth, double.infinity);
    double newHeight =
        DraggableWidgetContainer.snapToGrid(displayRect.height, newGridSize)
            .clamp(minHeight, double.infinity);

    displayRect = Rect.fromLTWH(newX, newY, newWidth, newHeight);
    draggingRect = displayRect;

    notifyListeners();
  }

  void setTitle(String title) {
    this.title = title;

    notifyListeners();
  }

  void setDraggable(bool draggable) {
    this.draggable = draggable;
    notifyListeners();
  }

  void setDragging(bool dragging) {
    this.dragging = dragging;
    notifyListeners();
  }

  void setResizing(bool resizing) {
    this.resizing = resizing;
    notifyListeners();
  }

  void setPreviewVisible(bool previewVisible) {
    this.previewVisible = previewVisible;
    notifyListeners();
  }

  void setValidLocation(bool validLocation) {
    this.validLocation = validLocation;
    notifyListeners();
  }

  void setDraggingIntoLayout(bool draggingIntoLayout) {
    this.draggingIntoLayout = draggingIntoLayout;
    notifyListeners();
  }

  void setEnabled(bool enabled) {
    this.enabled = enabled;
    notifyListeners();
  }

  void setDisplayRect(Rect displayRect) {
    this.displayRect = displayRect;
    notifyListeners();
  }

  void setDraggingRect(Rect draggingRect) {
    this.draggingRect = draggingRect;
    notifyListeners();
  }

  void setPreviewRect(Rect previewRect) {
    this.previewRect = previewRect;
    notifyListeners();
  }

  void setDragStartLocation(Rect dragStartLocation) {
    this.dragStartLocation = dragStartLocation;
    notifyListeners();
  }

  void setCursorGlobalLocation(Offset globalLocation) {
    cursorGlobalLocation = globalLocation;
    notifyListeners();
  }

  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Properties'),
          content: SizedBox(
            width: 353,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: getContainerEditProperties(),
              ),
            ),
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

  List<Widget> getContainerEditProperties() {
    return [
      // Settings for the widget container
      const Text('Container Settings'),
      const SizedBox(height: 5),
      DialogTextInput(
        onSubmit: (value) {
          setTitle(value);
        },
        label: 'Title',
        initialText: title,
      ),
    ];
  }

  WidgetContainer getDraggingWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: draggingRect.width,
      height: draggingRect.height,
      cornerRadius:
          preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
      opacity: 0.80,
      child: Container(),
    );
  }

  WidgetContainer getWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: displayRect.width,
      height: displayRect.height,
      cornerRadius:
          preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
      child: Container(),
    );
  }

  Widget getDefaultPreview() {
    return Positioned(
      left: previewRect.left,
      top: previewRect.top,
      width: previewRect.width,
      height: previewRect.height,
      child: Visibility(
        visible: previewVisible,
        child: Container(
          decoration: BoxDecoration(
            color: (validLocation)
                ? Colors.white.withOpacity(0.25)
                : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
                preferences.getDouble(PrefKeys.cornerRadius) ??
                    Defaults.cornerRadius),
            border: Border.all(
                color: (validLocation)
                    ? Colors.lightGreenAccent.shade400
                    : Colors.red,
                width: 5.0),
          ),
        ),
      ),
    );
  }
}
