import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class DraggableLayoutContainer extends DraggableWidgetContainer {
  String get type;

  DraggableNTWidgetContainer Function(Map<String, dynamic> jsonData)?
      ntContainerBuilder;

  DraggableLayoutContainer({
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
  }) : super();

  DraggableLayoutContainer.fromJson({
    super.key,
    required super.tabGrid,
    required super.jsonData,
    required this.ntContainerBuilder,
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
  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': type,
      'properties': getProperties(),
    };
  }

  Map<String, dynamic> getProperties() {
    return {};
  }

  bool willAcceptWidget(DraggableWidgetContainer widget,
      {Offset? globalPosition});

  void addWidget(DraggableNTWidgetContainer widget);

  void refreshChildren();
}
