import 'dart:ui';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt4_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class DraggableLayoutContainer extends DraggableWidgetContainer {
  String get type;

  DraggableLayoutContainer({
    super.key,
    required super.title,
    required super.validMoveLocation,
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

  bool willAcceptWidget(DraggableWidgetContainer widget);

  void addWidget(DraggableNT4WidgetContainer widget, {Offset? localPosition});
}
