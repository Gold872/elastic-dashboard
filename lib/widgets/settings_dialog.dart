import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';

class SettingsDialog extends StatefulWidget {
  final NTConnection ntConnection;

  static final List<String> themeVariants = FlexSchemeVariant.values
      .whereNot((variant) => variant == Defaults.themeVariant)
      .map((variant) => variant.variantName)
      .toList()
    ..add(Defaults.defaultVariantName)
    ..sort();

  final SharedPreferences preferences;

  final Function(String? data)? onIPAddressChanged;
  final Function(String? data)? onTeamNumberChanged;
  final Function(IPAddressMode mode)? onIPAddressModeChanged;
  final Function(Color color)? onColorChanged;
  final Function(bool value)? onGridToggle;
  final Function(String? gridSize)? onGridSizeChanged;
  final Function(String? radius)? onCornerRadiusChanged;
  final Function(bool value)? onResizeToDSChanged;
  final Function(bool value)? onRememberWindowPositionChanged;
  final Function(bool value)? onLayoutLock;
  final Function(String? value)? onDefaultPeriodChanged;
  final Function(String? value)? onDefaultGraphPeriodChanged;
  final Function(FlexSchemeVariant variant)? onThemeVariantChanged;
  final Function(String? value)? onGridDPIChanged;
  final Function()? onOpenAssetsFolderPressed;

  const SettingsDialog({
    super.key,
    required this.ntConnection,
    required this.preferences,
    this.onTeamNumberChanged,
    this.onIPAddressModeChanged,
    this.onIPAddressChanged,
    this.onColorChanged,
    this.onGridToggle,
    this.onGridSizeChanged,
    this.onCornerRadiusChanged,
    this.onResizeToDSChanged,
    this.onRememberWindowPositionChanged,
    this.onLayoutLock,
    this.onDefaultPeriodChanged,
    this.onDefaultGraphPeriodChanged,
    this.onThemeVariantChanged,
    this.onGridDPIChanged,
    this.onOpenAssetsFolderPressed,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      content: DefaultTabController(
        length: 3,
        child: SizedBox(
          width: 450,
          height: 400,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(
                      Icons.wifi_outlined,
                    ),
                    child: Text('Network'),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.color_lens_outlined,
                    ),
                    child: Text('Appearance'),
                  ),
                  Tab(
                    icon: Icon(
                      Icons.code,
                    ),
                    child: Text('Developer'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    // Network Tab
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          ..._ipAddressSettings(),
                          const Divider(),
                          ..._networkTablesSettings(),
                        ],
                      ),
                    ),
                    // Style Preferences Tab
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 350),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              ..._themeSettings(),
                              const Divider(),
                              ..._gridSettings(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Advanced Settings Tab
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        children: [
                          ..._advancedSettings(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  List<Widget> _advancedSettings() {
    return [
      Row(
        children: [
          const Icon(Icons.warning, color: Colors.yellow),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'WARNING: These are advanced settings that could cause issues if changed incorrectly. It is advised to not change anything here unless if you know what you are doing.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.warning,
            color: Colors.yellow,
          ),
        ],
      ),
      const Divider(),
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              initialText: widget.preferences
                      .getDouble(PrefKeys.gridDpiOverride)
                      ?.toString() ??
                  '',
              label: 'Grid DPI (Experimental)',
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              allowEmptySubmission: true,
              onSubmit: (value) {
                widget.onGridDPIChanged?.call(value);
              },
            ),
          ),
          TextButton.icon(
            onPressed: () {
              widget.onOpenAssetsFolderPressed?.call();
            },
            icon: const Icon(Icons.folder_outlined),
            label: const Text('Open Assets Folder'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _themeSettings() {
    Color currentColor = Color(widget.preferences.getInt(PrefKeys.teamColor) ??
        Colors.blueAccent.value);

    // Safety feature to prevent theme variants dropdown from not rendering if the current selection doesn't exist
    List<String>? themeVariantsOverride;
    if (!SettingsDialog.themeVariants
            .contains(widget.preferences.getString(PrefKeys.themeVariant)) &&
        widget.preferences.getString(PrefKeys.themeVariant) != null) {
      // Weird way of copying the list
      themeVariantsOverride = SettingsDialog.themeVariants.toList()
        ..add(widget.preferences.getString(PrefKeys.themeVariant)!)
        ..sort();
      themeVariantsOverride = Set.of(themeVariantsOverride).toList();
    }

    return [
      const Align(
        alignment: Alignment.topLeft,
        child: Text('Theme Settings'),
      ),
      IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              flex: 2,
              child: UnconstrainedBox(
                constrainedAxis: Axis.horizontal,
                child: DialogColorPicker(
                  onColorPicked: (color) => widget.onColorChanged?.call(color),
                  label: 'Team Color',
                  initialColor: currentColor,
                  defaultColor: Colors.blueAccent,
                  rowSize: MainAxisSize.max,
                ),
              ),
            ),
            const VerticalDivider(),
            Flexible(
              flex: 4,
              child: Column(
                children: [
                  const Text('Theme Variant'),
                  DialogDropdownChooser<String>(
                      onSelectionChanged: (variantName) {
                        if (variantName == null) return;
                        FlexSchemeVariant variant = FlexSchemeVariant.values
                                .firstWhereOrNull(
                                    (e) => e.variantName == variantName) ??
                            FlexSchemeVariant.material3Legacy;

                        widget.onThemeVariantChanged?.call(variant);
                        setState(() {});
                      },
                      choices:
                          themeVariantsOverride ?? SettingsDialog.themeVariants,
                      initialValue:
                          widget.preferences.getString(PrefKeys.themeVariant) ??
                              Defaults.defaultVariantName),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _ipAddressSettings() {
    return [
      const Align(
        alignment: Alignment.topLeft,
        child: Text('Connection Settings'),
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          Flexible(
            flex: 2,
            child: DialogTextInput(
              initialText:
                  widget.preferences.getInt(PrefKeys.teamNumber)?.toString() ??
                      Defaults.teamNumber.toString(),
              label: 'Team Number',
              onSubmit: (data) async {
                await widget.onTeamNumberChanged?.call(data);
                setState(() {});
              },
              formatter: FilteringTextInputFormatter.digitsOnly,
            ),
          ),
          Flexible(
            flex: 3,
            child: ValueListenableBuilder(
              valueListenable: widget.ntConnection.dsConnected,
              builder: (context, connected, child) {
                return DialogTextInput(
                  enabled: widget.preferences.getInt(PrefKeys.ipAddressMode) ==
                          IPAddressMode.custom.index ||
                      (widget.preferences.getInt(PrefKeys.ipAddressMode) ==
                              IPAddressMode.driverStation.index &&
                          !connected),
                  initialText:
                      widget.preferences.getString(PrefKeys.ipAddress) ??
                          Defaults.ipAddress,
                  label: 'IP Address',
                  onSubmit: (String? data) async {
                    await widget.onIPAddressChanged?.call(data);
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          const Text('IP Address Mode'),
          const SizedBox(width: 5),
          Flexible(
            child: DialogDropdownChooser<IPAddressMode>(
              onSelectionChanged: (mode) {
                if (mode == null) {
                  return;
                }

                widget.onIPAddressModeChanged?.call(mode);

                setState(() {});
              },
              choices: IPAddressMode.values,
              initialValue: IPAddressMode.fromIndex(
                  widget.preferences.getInt(PrefKeys.ipAddressMode)),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _gridSettings() {
    return [
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
              initialValue: widget.preferences.getBool(PrefKeys.showGrid) ??
                  Defaults.showGrid,
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
              initialText:
                  widget.preferences.getInt(PrefKeys.gridSize)?.toString() ??
                      Defaults.gridSize.toString(),
              label: 'Grid Size',
              onSubmit: (value) async {
                await widget.onGridSizeChanged?.call(value);
                setState(() {});
              },
              formatter: FilteringTextInputFormatter.digitsOnly,
            ),
          )
        ],
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            flex: 2,
            child: DialogTextInput(
              initialText:
                  (widget.preferences.getDouble(PrefKeys.cornerRadius) ??
                          Defaults.cornerRadius.toString())
                      .toString(),
              label: 'Corner Radius',
              onSubmit: (value) {
                setState(() {
                  widget.onCornerRadiusChanged?.call(value);
                });
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
            ),
          ),
          Flexible(
            flex: 3,
            child: DialogToggleSwitch(
              initialValue:
                  widget.preferences.getBool(PrefKeys.autoResizeToDS) ??
                      Defaults.autoResizeToDS,
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
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            flex: 5,
            child: DialogToggleSwitch(
              initialValue:
                  widget.preferences.getBool(PrefKeys.rememberWindowPosition) ??
                      false,
              label: 'Remember Window Position',
              onToggle: (value) {
                setState(() {
                  widget.onRememberWindowPositionChanged?.call(value);
                });
              },
            ),
          ),
          Flexible(
            flex: 4,
            child: DialogToggleSwitch(
              initialValue: widget.preferences.getBool(PrefKeys.layoutLocked) ??
                  Defaults.layoutLocked,
              label: 'Lock Layout',
              onToggle: (value) {
                setState(() {
                  widget.onLayoutLock?.call(value);
                });
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _networkTablesSettings() {
    return [
      const Align(
        alignment: Alignment.topLeft,
        child: Text('Network Tables Settings'),
      ),
      const SizedBox(height: 5),
      Flexible(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              child: DialogTextInput(
                initialText:
                    (widget.preferences.getDouble(PrefKeys.defaultPeriod) ??
                            Defaults.defaultPeriod)
                        .toString(),
                label: 'Default Period',
                onSubmit: (value) async {
                  await widget.onDefaultPeriodChanged?.call(value);
                  setState(() {});
                },
                formatter: TextFormatterBuilder.decimalTextFormatter(),
              ),
            ),
            Flexible(
              child: DialogTextInput(
                initialText: (widget.preferences
                            .getDouble(PrefKeys.defaultGraphPeriod) ??
                        Defaults.defaultGraphPeriod)
                    .toString(),
                label: 'Default Graph Period',
                onSubmit: (value) async {
                  widget.onDefaultGraphPeriodChanged?.call(value);
                  setState(() {});
                },
                formatter: TextFormatterBuilder.decimalTextFormatter(),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
