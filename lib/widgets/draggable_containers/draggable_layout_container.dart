import 'dart:ui';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt4_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class DraggableLayoutContainer extends DraggableWidgetContainer {
  String get type;

  DraggableNT4WidgetContainer Function(Map<String, dynamic> jsonData)?
      nt4ContainerBuilder;
  final Function(DraggableWidgetContainer widget, Offset globalPosition)?
      onDragOutUpdate;
  final Function(DraggableWidgetContainer widget)? onDragOutEnd;

  DraggableLayoutContainer({
    super.key,
    required super.title,
    required super.validMoveLocation,
    this.onDragOutUpdate,
    this.onDragOutEnd,
    super.enabled = false,
    super.initialPosition,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();

  DraggableLayoutContainer.fromJson({
    super.key,
    required super.validMoveLocation,
    required super.jsonData,
    required this.nt4ContainerBuilder,
    this.onDragOutUpdate,
    this.onDragOutEnd,
    super.enabled = false,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
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
      {Offset? localPosition});

  void addWidget(DraggableNT4WidgetContainer widget, {Offset? localPosition});
}
