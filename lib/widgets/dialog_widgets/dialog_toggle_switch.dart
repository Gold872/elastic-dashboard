import 'package:flutter/material.dart';

class DialogToggleSwitch extends StatefulWidget {
  final Function(bool value) onToggle;
  final bool initialValue;

  const DialogToggleSwitch(
      {super.key, this.initialValue = false, required this.onToggle});

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
    return Switch(
      onChanged: (value) {
        widget.onToggle.call(value);

        setState(() => this.value = value);
      },
      value: value,
    );
  }
}
