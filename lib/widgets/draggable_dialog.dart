import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';

/// A draggable dialog widget that allows the dialog to be moved and resized.
///
/// This widget is useful for creating dialogs that can be repositioned and resized by the user.
class DraggableDialog extends StatefulWidget {
  /// The content of the dialog.
  final Widget dialog;

  /// The initial position and size of the dialog.
  final Rect initialPosition;

  /// Creates a draggable dialog.
  ///
  /// [dialog] is the content of the dialog.
  /// [initialPosition] specifies the initial position and size of the dialog. Defaults to a rectangle from (50, 50) with a width of 400 and a height of 500.
  const DraggableDialog({
    super.key,
    required this.dialog,
    this.initialPosition = const Rect.fromLTWH(50.0, 50.0, 400, 500),
  });

  @override
  State<DraggableDialog> createState() => _DraggableDialogState();
}

class _DraggableDialogState extends State<DraggableDialog> {
  late Rect position = widget.initialPosition;

  @override
  Widget build(BuildContext context) {
    return TransformableBox(
      constraints: const BoxConstraints(
          minWidth: 300,
          minHeight: 400,
          maxWidth: double.infinity,
          maxHeight: double.infinity),
      clampingRect: const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
      allowFlippingWhileResizing: false,
      visibleHandles: const {},
      resizeModeResolver: () => ResizeMode.freeform,
      rect: position,
      onChanged: (result, event) {
        setState(() => position = result.rect);
      },
      contentBuilder: (context, rect, flip) {
        return widget.dialog;
      },
    );
  }
}
