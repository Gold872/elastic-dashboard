import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatefulWidget {
  final SharedPreferences preferences;

  final Function(String? data)? onIPAddressChanged;
  final Function(String? data)? onTeamNumberChanged;
  final Function(IPAddressMode mode)? onIPAddressModeChanged;
  final Function(Color color)? onColorChanged;
  final Function(bool value)? onGridToggle;
  final Function(String? gridSize)? onGridSizeChanged;
  final Function(String? radius)? onCornerRadiusChanged;
  final Function(bool value)? onResizeToDSChanged;

  const SettingsDialog({
    super.key,
    required this.preferences,
    this.onTeamNumberChanged,
    this.onIPAddressModeChanged,
    this.onIPAddressChanged,
    this.onColorChanged,
    this.onGridToggle,
    this.onGridSizeChanged,
    this.onCornerRadiusChanged,
    this.onResizeToDSChanged,
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
                        widget.onTeamNumberChanged?.call(data);
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
            const Divider(),
            const Align(
              alignment: Alignment.topLeft,
              child: Text('IP Address Settings'),
            ),
            const SizedBox(height: 5),
            const Text('IP Address Mode'),
            DialogDropdownChooser<IPAddressMode>(
              onSelectionChanged: (mode) {
                if (mode == null) {
                  return;
                }

                widget.onIPAddressModeChanged?.call(mode);

                setState(() {});
              },
              choices: IPAddressMode.values,
              initialValue: Globals.ipAddressMode,
            ),
            const SizedBox(height: 5),
            StreamBuilder(
                stream: nt4Connection.dsConnectionStatus(),
                initialData: nt4Connection.isDSConnected,
                builder: (context, snapshot) {
                  bool dsConnected = tryCast(snapshot.data) ?? false;

                  return DialogTextInput(
                    enabled: Globals.ipAddressMode == IPAddressMode.custom ||
                        (Globals.ipAddressMode == IPAddressMode.driverStation &&
                            !dsConnected),
                    initialText:
                        widget.preferences.getString(PrefKeys.ipAddress),
                    label: 'IP Address',
                    onSubmit: (String? data) {
                      setState(() {
                        widget.onIPAddressChanged?.call(data);
                      });
                    },
                  );
                }),
            const Divider(),
            const Align(
              alignment: Alignment.topLeft,
              child: Text('Grid Settings'),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: DialogToggleSwitch(
                    initialValue:
                        widget.preferences.getBool(PrefKeys.showGrid) ??
                            Globals.showGrid,
                    label: 'Show Grid',
                    onToggle: (value) {
                      setState(() {
                        widget.onGridToggle?.call(value);
                      });
                    },
                  ),
                ),
                Flexible(
                  child: DialogTextInput(
                    initialText: widget.preferences
                            .getInt(PrefKeys.gridSize)
                            ?.toString() ??
                        Globals.gridSize.toString(),
                    label: 'Grid Size',
                    onSubmit: (value) {
                      setState(() {
                        widget.onGridSizeChanged?.call(value);
                      });
                    },
                    formatter:
                        FilteringTextInputFormatter.allow(RegExp(r"[0-9]")),
                  ),
                )
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  flex: 2,
                  child: DialogTextInput(
                    initialText: widget.preferences
                            .getDouble(PrefKeys.cornerRadius)
                            ?.toString() ??
                        Globals.cornerRadius.toString(),
                    label: 'Corner Radius',
                    onSubmit: (value) {
                      setState(() {
                        widget.onCornerRadiusChanged?.call(value);
                      });
                    },
                    formatter:
                        FilteringTextInputFormatter.allow(RegExp(r"[0-9.]")),
                  ),
                ),
                Flexible(
                  flex: 3,
                  child: DialogToggleSwitch(
                    initialValue:
                        widget.preferences.getBool(PrefKeys.autoResizeToDS) ??
                            Globals.autoResizeToDS,
                    label: 'Resize to Driver Station Height',
                    onToggle: (value) {
                      setState(() {
                        widget.onResizeToDSChanged?.call(value);
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
