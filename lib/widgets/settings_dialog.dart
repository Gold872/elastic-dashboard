import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatefulWidget {
  final SharedPreferences preferences;

  final Function(String? data) onIPAddressChanged;
  final Function(String? data) onTeamNumberChanged;
  final Function(bool value) onUseTeamNumberToggle;
  final Function(Color color)? onColorChanged;

  const SettingsDialog({
    super.key,
    required this.preferences,
    required this.onTeamNumberChanged,
    required this.onUseTeamNumberToggle,
    required this.onIPAddressChanged,
    required this.onColorChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    Color currentColor = Color(
        widget.preferences.getInt('team_color') ?? Colors.blueAccent.value);

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: DialogTextInput(
                    initialText: widget.preferences
                        .getInt(PrefKeys.teamNumber)
                        .toString(),
                    label: 'Team Number',
                    onSubmit: (data) {
                      setState(() {
                        widget.onTeamNumberChanged.call(data);
                      });
                    },
                    formatter:
                        FilteringTextInputFormatter.allow(RegExp(r"[0-9]")),
                  ),
                ),
                Flexible(
                  child: DialogColorPicker(
                    onColorPicked: (color) =>
                        widget.onColorChanged?.call(color),
                    label: 'Team Color',
                    initialColor: currentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 75),
                        child: const Text('Use Team # for IP',
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 5),
                      DialogToggleSwitch(
                          onToggle: (value) {
                            setState(() {
                              widget.onUseTeamNumberToggle.call(value);
                            });
                          },
                          initialValue: widget.preferences
                                  .getBool(PrefKeys.useTeamNumberForIP) ??
                              false),
                    ],
                  ),
                ),
                Flexible(
                  child: DialogTextInput(
                    enabled: !(widget.preferences
                            .getBool(PrefKeys.useTeamNumberForIP) ??
                        false),
                    initialText:
                        widget.preferences.getString(PrefKeys.ipAddress),
                    label: 'IP Address',
                    onSubmit: (String? data) {
                      setState(() {
                        widget.onIPAddressChanged.call(data);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
