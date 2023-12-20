import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class LayoutContainerModel extends WidgetContainerModel {
  String get type;

  LayoutContainerModel({
    required super.initialPosition,
    required super.title,
  });

  LayoutContainerModel.fromJson({
    required super.jsonData,
    super.enabled,
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

  bool willAcceptWidget(WidgetContainerModel widget, {Offset? globalPosition});

  void addWidget(NTWidgetContainerModel model);
}

abstract class DraggableLayoutContainer extends DraggableWidgetContainer {
  const DraggableLayoutContainer({
    super.key,
    required super.tabGrid,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();
}
