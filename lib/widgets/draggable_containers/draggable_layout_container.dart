import 'dart:ui';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt4_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class DraggableLayoutContainer extends DraggableWidgetContainer {
  String get type;

  DraggableNT4WidgetContainer Function(Map<String, dynamic> jsonData)?
      nt4ContainerBuilder;

  DraggableLayoutContainer({
    super.key,
    required super.dashboardGrid,
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
    required super.dashboardGrid,
    required super.jsonData,
    required this.nt4ContainerBuilder,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super.fromJson();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': type,
    };
  }

  bool willAcceptWidget(DraggableWidgetContainer widget,
      {Offset? globalPosition});

  void addWidget(DraggableNT4WidgetContainer widget);
}
