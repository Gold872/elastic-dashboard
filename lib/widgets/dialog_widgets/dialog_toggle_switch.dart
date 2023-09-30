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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Text(widget.label ?? '', textAlign: TextAlign.center),
          ),
          Switch(
            onChanged: (value) {
              widget.onToggle.call(value);

              setState(() => this.value = value);
            },
            value: value,
          ),
        ],
      ),
    );
  }
}
