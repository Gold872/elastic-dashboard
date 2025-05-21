import 'dart:ui';

import 'package:flutter/material.dart';

/// A gesture detector for dragging that will disable any pan gestures from parent widgets
class DragListener extends StatelessWidget {
  final Widget child;

  /// The kind of devices that are allowed to be recognized.
  ///
  /// If set to null, events from all device types will be recognized. Defaults to null.
  final Set<PointerDeviceKind>? supportedDevices;

  /// Callback for when the widget begins dragging
  final GestureDragStartCallback? onDragStart;

  /// Callback for when the drag is updated
  final GestureDragUpdateCallback? onDragUpdate;

  /// Callback for when the drag ends
  final GestureDragEndCallback? onDragEnd;

  const DragListener({
    super.key,
    required this.child,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.supportedDevices,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      supportedDevices: supportedDevices,
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: GestureDetector(
        supportedDevices: supportedDevices,
        onHorizontalDragStart: onDragStart,
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: onDragEnd,
        onPanStart: onDragStart,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        child: child,
      ),
    );
  }
}
