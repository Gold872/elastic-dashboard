import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/models/layout_container_model.dart';

class LayoutDragTile extends StatefulWidget {
  final String title;
  final IconData icon;

  final LayoutContainerModel Function() layoutBuilder;

  final void Function(Offset globalPosition, LayoutContainerModel widget)
      onDragUpdate;
  final void Function(LayoutContainerModel widget) onDragEnd;
  final void Function() onRemoveWidget;

  const LayoutDragTile({
    super.key,
    required this.title,
    required this.icon,
    required this.layoutBuilder,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRemoveWidget,
  });

  @override
  State<LayoutDragTile> createState() => _LayoutDragTileState();
}

class _LayoutDragTileState extends State<LayoutDragTile> {
  LayoutContainerModel? draggingWidget;

  @override
  void dispose() {
    if (draggingWidget != null) {
      draggingWidget?.unSubscribe();
      draggingWidget?.disposeModel(deleting: true);
      draggingWidget?.forceDispose();

      widget.onRemoveWidget();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: GestureDetector(
        onPanStart: (details) {
          if (draggingWidget != null) {
            return;
          }

          // Prevents 2 finger drags from dragging a widget
          if (details.kind != null &&
              details.kind! == PointerDeviceKind.trackpad) {
            draggingWidget = null;
            return;
          }

          setState(() => draggingWidget = widget.layoutBuilder.call());
        },
        onPanUpdate: (details) {
          if (draggingWidget == null) {
            return;
          }

          widget.onDragUpdate.call(details.globalPosition, draggingWidget!);
        },
        onPanEnd: (details) {
          if (draggingWidget == null) {
            return;
          }

          widget.onDragEnd.call(draggingWidget!);

          setState(() => draggingWidget = null);
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16.0),
          child: ListTile(
            style: ListTileStyle.drawer,
            contentPadding: const EdgeInsets.only(right: 20.0),
            leading: Icon(widget.icon),
            title: Text(widget.title),
          ),
        ),
      ),
    );
  }
}
