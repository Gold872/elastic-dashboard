import 'package:flutter/material.dart';

class DialogToggleSwitch extends StatefulWidget {
  final Function(bool value) onToggle;
  final bool initialValue;
  final String? label;
  final double maxWidth;

  const DialogToggleSwitch({
    super.key,
    this.initialValue = false,
    this.maxWidth = 75,
    this.label,
    required this.onToggle,
  });

  @override
  State<DialogToggleSwitch> createState() => _DialogToggleSwitchState();
}

class _DialogToggleSwitchState extends State<DialogToggleSwitch> {
  late bool value;

  @override
  void initState() {
    super.initState();

    value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Text(widget.label ?? '', textAlign: TextAlign.center),
        ),
        const SizedBox(width: 5),
        Switch(
          onChanged: (value) {
            widget.onToggle.call(value);

            setState(() => this.value = value);
          },
          value: value,
        ),
      ],
    );
  }
}
