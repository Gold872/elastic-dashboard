import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'models/list_layout_model.dart';

class DraggableListLayout extends DraggableLayoutContainer {
  const DraggableListLayout({
    super.key,
    required super.tabGrid,
    super.onUpdate,
    super.onDragBegin,
    super.onDragEnd,
    super.onDragCancel,
    super.onResizeBegin,
    super.onResizeEnd,
  }) : super();

  @override
  Widget build(BuildContext context) {
    ListLayoutModel model = context.watch<ListLayoutModel>();

    return Stack(
      children: [
        Positioned(
          left: model.displayRect.left,
          top: model.displayRect.top,
          child: model.getWidgetContainer(context),
        ),
        ...super.getStackChildren(model),
      ],
    );
  }
}
