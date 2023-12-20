import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

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
