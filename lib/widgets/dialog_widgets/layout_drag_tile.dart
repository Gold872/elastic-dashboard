import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LayoutDragTile extends StatelessWidget {
  final String title;

  DraggableLayoutContainer Function()? layoutBuilder;

  DraggableLayoutContainer? draggingWidget;

  final Function(Offset globalPosition, DraggableLayoutContainer widget)?
      onDragUpdate;
  final Function(DraggableLayoutContainer widget)? onDragEnd;

  LayoutDragTile({
    super.key,
    required this.title,
    this.layoutBuilder,
    this.onDragUpdate,
    this.onDragEnd,
  });

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

          draggingWidget = layoutBuilder?.call();
        },
        onPanUpdate: (details) {
          if (draggingWidget == null) {
            return;
          }

          onDragUpdate?.call(
              details.globalPosition -
                  Offset(draggingWidget!.displayRect.width,
                          draggingWidget!.displayRect.height) /
                      2,
              draggingWidget!);
        },
        onPanEnd: (details) {
          if (draggingWidget == null) {
            return;
          }

          onDragEnd?.call(draggingWidget!);

          draggingWidget = null;
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16.0),
          child: ListTile(
            style: ListTileStyle.drawer,
            dense: true,
            contentPadding: const EdgeInsets.only(right: 20.0),
            leading: const SizedBox(width: 16.0),
            title: Text(title),
          ),
        ),
      ),
    );
  }
}
