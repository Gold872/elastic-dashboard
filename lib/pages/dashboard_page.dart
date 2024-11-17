import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:popover/popover.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'package:elastic_dashboard/services/app_distributor.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/robot_notifications_listener.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/shuffleboard_nt_listener.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/layout_drag_tile.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';
import '../widgets/draggable_containers/models/layout_container_model.dart';

class DashboardPage extends StatefulWidget {
  final String version;
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final Function(Color color)? onColorChanged;
  final Function(FlexSchemeVariant variant)? onThemeVariantChanged;

  const DashboardPage({
    super.key,
    required this.ntConnection,
    required this.preferences,
    required this.version,
    this.onColorChanged,
    this.onThemeVariantChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WindowListener {
  late final SharedPreferences preferences = widget.preferences;
  late final UpdateChecker _updateChecker;
  late final RobotNotificationsListener _robotNotificationListener;

  final List<TabData> _tabData = [];

  final Function _mapEquals = const DeepCollectionEquality().equals;

  late int _gridSize =
      preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

  int _currentTabIndex = 0;

  bool _addWidgetDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _updateChecker = UpdateChecker(currentVersion: widget.version);

    windowManager.addListener(this);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      Future(() async => await windowManager.setPreventClose(true));
    }

    _loadLayout();

    _setupShortcuts();

    widget.ntConnection.dsClientConnect(
      onIPAnnounced: (ip) async {
        if (preferences.getInt(PrefKeys.ipAddressMode) !=
            IPAddressMode.driverStation.index) {
          return;
        }

        if (preferences.getString(PrefKeys.ipAddress) != ip) {
          await preferences.setString(PrefKeys.ipAddress, ip);
        } else {
          return;
        }

        widget.ntConnection.changeIPAddress(ip);
      },
      onDriverStationDockChanged: (docked) {
        if ((preferences.getBool(PrefKeys.autoResizeToDS) ??
                Defaults.autoResizeToDS) &&
            docked) {
          _onDriverStationDocked();
        } else {
          _onDriverStationUndocked();
        }
      },
    );

    widget.ntConnection.addConnectedListener(() {
      setState(() {
        for (TabGridModel grid in _tabData.map((e) => e.tabGrid)) {
          grid.onNTConnect();
        }
      });
    });

    widget.ntConnection.addDisconnectedListener(() {
      setState(() {
        for (TabGridModel grid in _tabData.map((e) => e.tabGrid)) {
          grid.onNTDisconnect();
        }
      });
    });

    ShuffleboardNTListener apiListener = ShuffleboardNTListener(
      ntConnection: widget.ntConnection,
      preferences: widget.preferences,
      onTabChanged: (tab) {
        int? parsedTabIndex = int.tryParse(tab);

        bool isIndex = parsedTabIndex != null;

        List<String> tabNamesList = _tabData.map((data) => data.name).toList();

        // Prevent the program from switching to a non-existent tab
        if (!isIndex && !tabNamesList.contains(tab)) {
          return;
        } else if (isIndex && parsedTabIndex >= _tabData.length) {
          return;
        }

        int tabIndex = (isIndex) ? parsedTabIndex : tabNamesList.indexOf(tab);

        if (tabIndex == _currentTabIndex) {
          return;
        }

        setState(() {
          _currentTabIndex = tabIndex;
        });
      },
      onTabCreated: (tab) {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }

        Iterable<String> tabNamesList = _tabData.map((data) => data.name);

        if (tabNamesList.contains(tab)) {
          return;
        }

        _tabData.add(TabData(
          name: tab,
          tabGrid: TabGridModel(
            ntConnection: widget.ntConnection,
            preferences: widget.preferences,
            onAddWidgetPressed: _displayAddWidgetDialog,
          ),
        ));
      },
      onWidgetAdded: (widgetData) {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        // Needs to be done in case if widget data gets erased by the listener
        Map<String, dynamic> widgetDataCopy = {};

        widgetData.forEach(
            (key, value) => widgetDataCopy.putIfAbsent(key, () => value));

        List<String> tabNamesList = _tabData.map((data) => data.name).toList();

        String tabName = widgetDataCopy['tab'];

        if (!tabNamesList.contains(tabName)) {
          _tabData.add(
            TabData(
              name: tabName,
              tabGrid: TabGridModel(
                ntConnection: widget.ntConnection,
                preferences: widget.preferences,
                onAddWidgetPressed: _displayAddWidgetDialog,
              ),
            ),
          );

          tabNamesList.add(tabName);
        }

        int tabIndex = tabNamesList.indexOf(tabName);

        if (tabIndex == -1) {
          return;
        }

        _tabData[tabIndex].tabGrid.addWidgetFromTabJson(widgetDataCopy);

        setState(() {});
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      apiListener.initializeSubscriptions();
      apiListener.initializeListeners();
    });

    if (!isWPILib) {
      Future(
          () => _checkForUpdates(notifyIfLatest: false, notifyIfError: false));
    }

    _robotNotificationListener = RobotNotificationsListener(
        ntConnection: widget.ntConnection,
        onNotification: (title, description, icon, time, width, height) {
          setState(() {
            ColorScheme colorScheme = Theme.of(context).colorScheme;
            TextTheme textTheme = Theme.of(context).textTheme;
            var widget = ElegantNotification(
              autoDismiss: time.inMilliseconds > 0,
              showProgressIndicator: time.inMilliseconds > 0,
              background: colorScheme.surface,
              width: width,
              height: height,
              position: Alignment.bottomRight,
              title: Text(
                title,
                style: textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              toastDuration: time,
              icon: icon,
              description: Text(description),
              stackedOptions: StackedOptions(
                key: 'robot_notification',
                type: StackedType.above,
                itemOffset: const Offset(0, 5),
              ),
            );
            if (mounted) widget.show(context);
          });
        });
    _robotNotificationListener.listen();
  }

  @override
  void onWindowClose() async {
    Map<String, dynamic> savedJson =
        jsonDecode(preferences.getString(PrefKeys.layout) ?? '{}');
    Map<String, dynamic> currentJson = _toJson();

    bool showConfirmation = !_mapEquals(savedJson, currentJson);

    if (showConfirmation) {
      _showWindowCloseConfirmation(context);
      await windowManager.focus();
    } else {
      await _closeWindow();
    }
  }

  Future<void> _closeWindow() async {
    await _saveWindowPosition();
    await windowManager.destroy();
  }

  @override
  void dispose() async {
    windowManager.removeListener(this);
    super.dispose();
  }

  Map<String, dynamic> _toJson() {
    List<Map<String, dynamic>> gridData = [];

    for (int i = 0; i < _tabData.length; i++) {
      TabData data = _tabData[i];

      gridData.add({
        'name': data.name,
        'grid_layout': data.tabGrid.toJson(),
      });
    }

    return {
      'version': 1.0,
      'grid_size': _gridSize,
      'tabs': gridData,
    };
  }

  Future<void> _saveLayout() async {
    Map<String, dynamic> jsonData = _toJson();

    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;

    bool successful =
        await preferences.setString(PrefKeys.layout, jsonEncode(jsonData));
    await _saveWindowPosition();

    if (successful) {
      logger.info('Layout saved successfully!');
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xff01CB67),
        width: 300,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.check_circle, color: Color(0xff01CB67)),
        title: Text('Saved',
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
            )),
        description: const Text('Layout saved successfully!'),
      );
      if (mounted) {
        notification.show(context);
      }
    } else {
      logger.error('Could not save layout');
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xffFE355C),
        width: 300,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.error, color: Color(0xffFE355C)),
        title: Text('Error',
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
            )),
        description: const Text('Failed to save layout, please try again!'),
      );
      if (mounted) {
        notification.show(context);
      }
    }
  }

  Future<void> _saveWindowPosition() async {
    Rect bounds = await windowManager.getBounds();

    List<double> positionArray = [
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    ];

    String positionString = jsonEncode(positionArray);

    await preferences.setString(PrefKeys.windowPosition, positionString);
  }

  void _checkForUpdates(
      {bool notifyIfLatest = true, bool notifyIfError = true}) async {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    ButtonThemeData buttonTheme = ButtonTheme.of(context);

    UpdateCheckerResponse updateResponse =
        await _updateChecker.isUpdateAvailable();

    if (updateResponse.error && notifyIfError) {
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xffFE355C),
        width: 350,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.error, color: Color(0xffFE355C)),
        title: Text('Failed to check for updates',
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
            )),
        description: Text(
          updateResponse.errorMessage!,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
      );

      if (mounted) {
        notification.show(context);
      }
      return;
    }

    if (updateResponse.updateAvailable) {
      ElegantNotification notification = ElegantNotification(
        autoDismiss: false,
        showProgressIndicator: false,
        background: colorScheme.surface,
        width: 350,
        position: Alignment.bottomRight,
        title: Text(
          'Version ${updateResponse.latestVersion!} Available',
          style: textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: const Icon(Icons.info, color: Color(0xff0066FF)),
        description: const Text('A new update is available!'),
        action: Text(
          'Update',
          style: textTheme.bodyMedium!.copyWith(
            color: buttonTheme.colorScheme?.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onNotificationPressed: () async {
          Uri url = Uri.parse(Settings.releasesLink);

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
      );

      if (mounted) {
        notification.show(context);
      }
    } else if (updateResponse.onLatestVersion && notifyIfLatest) {
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xff01CB67),
        width: 350,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.check_circle, color: Color(0xff01CB67)),
        title: Text('No Updates Available',
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
            )),
        description:
            const Text('You are running on the latest version of Elastic'),
      );

      if (mounted) {
        notification.show(context);
      }
    }
  }

  void _exportLayout() async {
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON (JavaScript Object Notation)',
      extensions: ['.json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    const XTypeGroup anyTypeGroup = XTypeGroup(
      label: 'All Files',
    );

    logger.info('Exporting layout');
    final FileSaveLocation? saveLocation = await getSaveLocation(
      suggestedName: 'elastic-layout.json',
      acceptedTypeGroups: [jsonTypeGroup, anyTypeGroup],
    );

    hotKeyManager.resetKeysPressed();

    if (saveLocation == null) {
      logger.info('Ignoring layout export, no location was selected');
      return;
    }

    Map<String, dynamic> jsonData = _toJson();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String jsonString = encoder.convert(jsonData);

    final Uint8List fileData = Uint8List.fromList(jsonString.codeUnits);

    final XFile jsonFile = XFile.fromData(fileData,
        mimeType: 'application/json', name: 'elastic-layout.json');

    logger.info('Saving layout data to ${saveLocation.path}');
    await jsonFile.saveTo(saveLocation.path);
  }

  void _importLayout() async {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON (JavaScript Object Notation)',
      extensions: ['.json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    const XTypeGroup anyTypeGroup = XTypeGroup(
      label: 'All Files',
    );

    logger.info('Importing layout');
    final XFile? file = await openFile(acceptedTypeGroups: [
      jsonTypeGroup,
      anyTypeGroup,
    ]);

    hotKeyManager.resetKeysPressed();

    if (file == null) {
      logger.info('Canceling layout import, no file was selected');
      return;
    }

    String jsonString;

    try {
      jsonString = await file.readAsString();
    } on FileSystemException catch (e) {
      _showJsonLoadingError(e.message);
      return;
    }

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(jsonString);
    } catch (e) {
      _showJsonLoadingError(e.toString());
      return;
    }

    await preferences.setString(PrefKeys.layout, jsonEncode(jsonData));

    setState(() => _loadLayoutFromJsonData(jsonString));
  }

  void _loadLayout() {
    String? jsonString = preferences.getString(PrefKeys.layout);

    if (jsonString == null) {
      _createDefaultTabs();
      return;
    }

    setState(() {
      _loadLayoutFromJsonData(jsonString);
    });
  }

  void _loadLayoutFromJsonData(String jsonString) {
    logger.info('Loading layout from json');
    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (jsonData == null) {
      _showJsonLoadingError('Invalid JSON format, aborting.');
      _createDefaultTabs();
      return;
    }

    if (!jsonData.containsKey('tabs')) {
      _showJsonLoadingError('JSON does not contain necessary data, aborting.');
      _createDefaultTabs();
      return;
    }

    if (jsonData.containsKey('grid_size')) {
      _gridSize = tryCast(jsonData['grid_size']) ?? _gridSize;
      preferences.setInt(PrefKeys.gridSize, _gridSize);
    }

    _tabData.clear();

    for (Map<String, dynamic> data in jsonData['tabs']) {
      if (tryCast(data['name']) == null) {
        _showJsonLoadingWarning('Tab name not specified, ignoring tab data.');
        continue;
      }

      if (tryCast<Map>(data['grid_layout']) == null) {
        _showJsonLoadingWarning(
            'Grid layout not specified for tab \'${data['name']}\', ignoring tab data.');
        continue;
      }

      _tabData.add(
        TabData(
          name: data['name'],
          tabGrid: TabGridModel.fromJson(
            ntConnection: widget.ntConnection,
            preferences: widget.preferences,
            jsonData: data['grid_layout'],
            onAddWidgetPressed: _displayAddWidgetDialog,
            onJsonLoadingWarning: _showJsonLoadingWarning,
          ),
        ),
      );
    }

    _createDefaultTabs();

    if (_currentTabIndex >= _tabData.length) {
      _currentTabIndex = _tabData.length - 1;
    }
  }

  void _createDefaultTabs() {
    if (_tabData.isEmpty) {
      logger.info('Creating default Teleoperated and Autonomous tabs');
      setState(() {
        _tabData.addAll([
          TabData(
            name: 'Teleoperated',
            tabGrid: TabGridModel(
              ntConnection: widget.ntConnection,
              preferences: widget.preferences,
              onAddWidgetPressed: _displayAddWidgetDialog,
            ),
          ),
          TabData(
            name: 'Autonomous',
            tabGrid: TabGridModel(
              ntConnection: widget.ntConnection,
              preferences: widget.preferences,
              onAddWidgetPressed: _displayAddWidgetDialog,
            ),
          ),
        ]);
      });
    }
  }

  void _showJsonLoadingError(String errorMessage) {
    logger.error(errorMessage);
    Future(() {
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      TextTheme textTheme = Theme.of(context).textTheme;

      int lines = '\n'.allMatches(errorMessage).length + 1;

      ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xffFE355C),
        width: 350,
        height: 100 + (lines - 1) * 10,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.error, color: Color(0xffFE355C)),
        title: Text('Error while loading JSON data',
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
            )),
        description: Flexible(child: Text(errorMessage)),
      ).show(context);
    });
  }

  void _showJsonLoadingWarning(String warningMessage) {
    logger.warning(warningMessage);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      TextTheme textTheme = Theme.of(context).textTheme;

      int lines = '\n'.allMatches(warningMessage).length + 1;

      ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: Colors.yellow,
        width: 350,
        height: 100 + (lines - 1) * 10,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.warning, color: Colors.yellow),
        title: Text('Warning while loading JSON data',
            style: textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.bold,
            )),
        description: Flexible(child: Text(warningMessage)),
      ).show(context);
    });
  }

  void _setupShortcuts() {
    logger.info('Setting up shortcuts');
    // Import Layout (Ctrl + O)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyO,
        modifiers: [KeyModifier.control],
      ),
      callback: _importLayout,
    );
    // Save (Ctrl + S)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyS,
        modifiers: [KeyModifier.control],
      ),
      callback: _saveLayout,
    );
    // Export (Ctrl + Shift + S)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyS,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: _exportLayout,
    );
    // Switch to Tab (Ctrl + Tab #)
    for (int i = 1; i <= 9; i++) {
      hotKeyManager.register(
        HotKey(
          LogicalKeyboardKey(48 + i),
          modifiers: [KeyModifier.control],
        ),
        callback: () {
          if (_currentTabIndex == i - 1) {
            logger.debug(
                'Ignoring switch to tab ${i - 1}, current tab is already $_currentTabIndex');
            return;
          }
          if (i - 1 < _tabData.length) {
            logger
                .info('Switching tab to index ${i - 1} via keyboard shortcut');
            setState(() => _currentTabIndex = i - 1);
          }
        },
      );
    }
    // Move to next tab (Ctrl + Tab)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.tab,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _moveToNextTab();
        }
      },
    );
    // Move to prevoius tab (Ctrl + Shift + Tab)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.tab,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _moveToPreviousTab();
        }
      },
    );
    // Move Tab Left (Ctrl + <-)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.arrowLeft,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _moveTabLeft();
        }
      },
    );
    // Move Tab Right (Ctrl + ->)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.arrowRight,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _moveTabRight();
        }
      },
    );
    // New Tab (Ctrl + T)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyT,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        String newTabName = 'Tab ${_tabData.length + 1}';
        int newTabIndex = _tabData.length;

        _tabData.add(
          TabData(
            name: newTabName,
            tabGrid: TabGridModel(
              ntConnection: widget.ntConnection,
              preferences: widget.preferences,
              onAddWidgetPressed: _displayAddWidgetDialog,
            ),
          ),
        );

        setState(() => _currentTabIndex = newTabIndex);
      },
    );
    // Close Tab (Ctrl + W)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyW,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        if (_tabData.length <= 1) {
          return;
        }

        TabData currentTab = _tabData[_currentTabIndex];

        _showTabCloseConfirmation(context, currentTab.name, () {
          int oldTabIndex = _currentTabIndex;

          if (_currentTabIndex == _tabData.length - 1) {
            _currentTabIndex--;
          }

          _tabData[oldTabIndex].tabGrid.onDestroy();

          setState(() {
            _tabData.removeAt(oldTabIndex);
          });
        });
      },
    );
    // Open settings dialog (Ctrl + ,)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.comma,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if ((ModalRoute.of(context)?.isCurrent ?? false) && mounted) {
          _displaySettingsDialog(context);
        }
      },
    );
    // Connect to robot (Ctrl + K)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyK,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (preferences.getInt(PrefKeys.ipAddressMode) ==
            IPAddressMode.driverStation.index) {
          return;
        }
        _updateIPAddress(IPAddressUtil.teamNumberToIP(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber));
        _changeIPAddressMode(IPAddressMode.driverStation);
      },
    );
    // Connect to sim (Ctrl + Shift + K)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyK,
        modifiers: [
          KeyModifier.control,
          KeyModifier.shift,
        ],
      ),
      callback: () {
        if (preferences.getInt(PrefKeys.ipAddressMode) ==
            IPAddressMode.localhost.index) {
          return;
        }
        _changeIPAddressMode(IPAddressMode.localhost);
      },
    );
  }

  void _lockLayout() async {
    for (TabGridModel grid in _tabData.map((e) => e.tabGrid)) {
      grid.lockLayout();
    }
    await preferences.setBool(PrefKeys.layoutLocked, true);
  }

  void _unlockLayout() async {
    for (TabGridModel grid in _tabData.map((e) => e.tabGrid)) {
      grid.unlockLayout();
    }
    await preferences.setBool(PrefKeys.layoutLocked, false);
  }

  void _displayAddWidgetDialog() {
    logger.info('Displaying add widget dialog');
    setState(() => _addWidgetDialogVisible = true);
  }

  void _displayAboutDialog(BuildContext context) {
    logger.info('Displaying about dialog');
    IconThemeData iconTheme = IconTheme.of(context);

    showAboutDialog(
      context: context,
      applicationName: appTitle,
      applicationVersion: widget.version,
      applicationIcon: Image.asset(
        logoPath,
        width: iconTheme.size,
        height: iconTheme.size,
      ),
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was created by Team 353, the POBots in the summer of 2023. The motivation was to provide teams an alternative to WPILib\'s Shuffleboard dashboard.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'The goal of Elastic is to have the essential features of Shuffleboard, but with a more elegant and modern display, and offer more customizability and performance.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic is an ongoing project, if you have any ideas, feedback, or found any bugs, feel free to share them on the Github page!\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was built with some inspiration from Michael Jansen\'s projects and his Dart NT4 library, along with significant help from Jason and Peter from WPILib.\n',
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () async {
                Uri url = Uri.parse(Settings.repositoryLink);

                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('View Repository'),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  void _displaySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        ntConnection: widget.ntConnection,
        preferences: widget.preferences,
        onTeamNumberChanged: (String? data) async {
          if (data == null) {
            return;
          }

          int? newTeamNumber = int.tryParse(data);

          if (newTeamNumber == null ||
              (newTeamNumber == preferences.getInt(PrefKeys.teamNumber))) {
            return;
          }

          await preferences.setInt(PrefKeys.teamNumber, newTeamNumber);

          switch (IPAddressMode.fromIndex(
              preferences.getInt(PrefKeys.ipAddressMode))) {
            case IPAddressMode.roboRIOmDNS:
              _updateIPAddress(
                  IPAddressUtil.teamNumberToRIOmDNS(newTeamNumber));
              break;
            case IPAddressMode.teamNumber:
              _updateIPAddress(IPAddressUtil.teamNumberToIP(newTeamNumber));
              break;
            default:
              setState(() {});
              break;
          }
        },
        onIPAddressModeChanged: (mode) async {
          if (mode.index == preferences.getInt(PrefKeys.ipAddressMode)) {
            return;
          }

          _changeIPAddressMode(mode);
        },
        onIPAddressChanged: (String? data) async {
          if (data == null ||
              data == preferences.getString(PrefKeys.ipAddress)) {
            return;
          }

          _updateIPAddress(data);
        },
        onGridToggle: (value) async {
          await preferences.setBool(PrefKeys.showGrid, value);

          setState(() {});
        },
        onGridSizeChanged: (gridSize) async {
          if (gridSize == null) {
            return;
          }

          int? newGridSize = int.tryParse(gridSize);

          if (newGridSize == null ||
              newGridSize == 0 ||
              newGridSize == _gridSize) {
            return;
          }

          bool? cancel = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.yellow),
                        SizedBox(width: 5),
                        Text('Grid Resizing Warning'),
                      ],
                    ),
                    content: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Resizing the grid may cause widgets to become misaligned due to sizing constraints. Manual work may be required after resizing.'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Okay'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Cancel'),
                      ),
                    ],
                  );
                },
              ) ??
              true;

          if (cancel) {
            return;
          }

          setState(() {
            _gridSize = newGridSize;
          });

          await preferences.setInt(PrefKeys.gridSize, newGridSize);

          for (TabGridModel grid in _tabData.map((e) => e.tabGrid)) {
            grid.resizeGrid(_gridSize, _gridSize);
          }
        },
        onCornerRadiusChanged: (radius) async {
          if (radius == null) {
            return;
          }

          double? newRadius = double.tryParse(radius);

          if (newRadius == null ||
              newRadius == preferences.getDouble(PrefKeys.cornerRadius)) {
            return;
          }

          await preferences.setDouble(PrefKeys.cornerRadius, newRadius);

          setState(() {
            for (TabGridModel grid in _tabData.map((e) => e.tabGrid)) {
              grid.refreshAllContainers();
            }
          });
        },
        onResizeToDSChanged: (value) async {
          setState(() {
            if (value && widget.ntConnection.dsClient.driverStationDocked) {
              _onDriverStationDocked();
            } else {
              _onDriverStationUndocked();
            }
          });

          await preferences.setBool(PrefKeys.autoResizeToDS, value);
        },
        onRememberWindowPositionChanged: (value) async {
          await preferences.setBool(PrefKeys.rememberWindowPosition, value);
        },
        onLayoutLock: (value) {
          if (value) {
            _lockLayout();
          } else {
            _unlockLayout();
          }
          setState(() {});
        },
        onDefaultPeriodChanged: (value) async {
          if (value == null) {
            return;
          }
          double? newPeriod = double.tryParse(value);

          if (newPeriod == null ||
              newPeriod == preferences.getDouble(PrefKeys.defaultPeriod)) {
            return;
          }

          await preferences.setDouble(PrefKeys.defaultPeriod, newPeriod);

          setState(() {});
        },
        onDefaultGraphPeriodChanged: (value) async {
          if (value == null) {
            return;
          }
          double? newPeriod = double.tryParse(value);

          if (newPeriod == null ||
              newPeriod == preferences.getDouble(PrefKeys.defaultGraphPeriod)) {
            return;
          }

          await preferences.setDouble(PrefKeys.defaultGraphPeriod, newPeriod);

          setState(() {});
        },
        onColorChanged: widget.onColorChanged,
        onThemeVariantChanged: widget.onThemeVariantChanged,
      ),
    );
  }

  void _changeIPAddressMode(IPAddressMode mode) async {
    await preferences.setInt(PrefKeys.ipAddressMode, mode.index);
    switch (mode) {
      case IPAddressMode.driverStation:
        String? lastAnnouncedIP = widget.ntConnection.dsClient.lastAnnouncedIP;

        if (lastAnnouncedIP == null) {
          break;
        }

        _updateIPAddress(lastAnnouncedIP);
        break;
      case IPAddressMode.roboRIOmDNS:
        _updateIPAddress(IPAddressUtil.teamNumberToRIOmDNS(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber));
        break;
      case IPAddressMode.teamNumber:
        _updateIPAddress(IPAddressUtil.teamNumberToIP(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber));
        break;
      case IPAddressMode.localhost:
        _updateIPAddress('localhost');
        break;
      default:
        setState(() {});
        break;
    }
  }

  void _updateIPAddress(String newIPAddress) async {
    if (newIPAddress == preferences.getString(PrefKeys.ipAddress)) {
      return;
    }
    await preferences.setString(PrefKeys.ipAddress, newIPAddress);

    setState(() {
      widget.ntConnection.changeIPAddress(newIPAddress);
    });
  }

  void _onDriverStationDocked() async {
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    double pixelRatio = primaryDisplay.scaleFactor?.toDouble() ?? 1.0;
    Size screenSize =
        (primaryDisplay.visibleSize ?? primaryDisplay.size) * pixelRatio;

    await windowManager.unmaximize();

    Size newScreenSize =
        Size(screenSize.width, (screenSize.height) - (200 * pixelRatio)) /
            pixelRatio;

    await windowManager.setSize(newScreenSize);

    await windowManager.setAlignment(Alignment.topCenter);

    Settings.isWindowMaximizable = false;
    Settings.isWindowDraggable = false;
    await windowManager.setResizable(false);

    await windowManager.setAsFrameless();
  }

  void _onDriverStationUndocked() async {
    Settings.isWindowMaximizable = true;
    Settings.isWindowDraggable = true;
    await windowManager.setResizable(true);

    // Re-adds the window frame, window manager's API for this is weird
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
        windowButtonVisibility: false);
  }

  void _showWindowCloseConfirmation(BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes, are you sure you want to continue? All unsaved changes will be lost!'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveLayout();

              Future.delayed(
                const Duration(milliseconds: 250),
                () async => await _closeWindow(),
              );
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () async {
              await _closeWindow();
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showTabCloseConfirmation(
      BuildContext context, String tabName, Function() onClose) {
    logger.info('Showing tab close confirmation for tab: $tabName');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          actions: [
            TextButton(
                onPressed: () {
                  logger.debug('Closing tab: $tabName');
                  Navigator.of(context).pop();
                  onClose.call();
                },
                child: const Text('OK')),
            TextButton(
                onPressed: () {
                  logger.debug(
                      'Ignoring tab close for tab: $tabName, user canceled the request.');
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel')),
          ],
          content: Text('Do you want to close the tab "$tabName"?'),
          title: const Text('Confirm Tab Close'),
        );
      },
    );
  }

  void _moveTabLeft() {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    if (_currentTabIndex <= 0) {
      logger.debug(
          'Ignoring move tab left, tab index is already $_currentTabIndex');
      return;
    }

    logger.info('Moving current tab at index $_currentTabIndex to the left');

    setState(() {
      // Swap the tabs
      TabData tempData = _tabData[_currentTabIndex - 1];
      _tabData[_currentTabIndex - 1] = _tabData[_currentTabIndex];
      _tabData[_currentTabIndex] = tempData;

      _currentTabIndex -= 1;
    });
  }

  void _moveTabRight() {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    if (_currentTabIndex >= _tabData.length - 1) {
      logger.debug(
          'Ignoring move tab left, tab index is already $_currentTabIndex');
      return;
    }

    logger.info('Moving current tab at index $_currentTabIndex to the right');

    setState(() {
      // Swap the tabs
      TabData tempData = _tabData[_currentTabIndex + 1];
      _tabData[_currentTabIndex + 1] = _tabData[_currentTabIndex];
      _tabData[_currentTabIndex] = tempData;

      _currentTabIndex += 1;
    });
  }

  void _moveToNextTab() {
    int moveIndex = _currentTabIndex + 1;

    if (moveIndex >= _tabData.length) {
      moveIndex = 0;
    }

    setState(() {
      _currentTabIndex = moveIndex;
    });
  }

  void _moveToPreviousTab() {
    int moveIndex = _currentTabIndex - 1;

    if (moveIndex < 0) {
      moveIndex = _tabData.length - 1;
    }

    setState(() {
      _currentTabIndex = moveIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? menuTextStyle = Theme.of(context).textTheme.bodySmall;
    TextStyle? footerStyle = Theme.of(context).textTheme.bodyMedium;
    ButtonStyle menuButtonStyle = ButtonStyle(
      alignment: Alignment.center,
      textStyle: WidgetStateProperty.all(menuTextStyle),
      backgroundColor:
          const WidgetStatePropertyAll(Color.fromARGB(255, 25, 25, 25)),
      iconSize: const WidgetStatePropertyAll(20.0),
    );

    MenuBar menuBar = MenuBar(
      style: const MenuStyle(
        backgroundColor:
            WidgetStatePropertyAll(Color.fromARGB(255, 25, 25, 25)),
        elevation: WidgetStatePropertyAll(0),
      ),
      children: [
        Center(
          child: Image.asset(
            logoPath,
            width: 24.0,
            height: 24.0,
          ),
        ),
        const SizedBox(width: 10),
        // File
        SubmenuButton(
          style: menuButtonStyle,
          menuChildren: [
            // Open Layout
            MenuItemButton(
              style: menuButtonStyle,
              onPressed: !(preferences.getBool(PrefKeys.layoutLocked) ??
                      Defaults.layoutLocked)
                  ? () => _importLayout()
                  : null,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyO, control: true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_outlined),
                  SizedBox(width: 8),
                  Text('Open Layout'),
                ],
              ),
            ),
            // Save
            MenuItemButton(
              style: menuButtonStyle,
              onPressed: () {
                _saveLayout();
              },
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyS, control: true),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save_outlined),
                  SizedBox(width: 8),
                  Text('Save'),
                ],
              ),
            ),

            // Export layout
            MenuItemButton(
                style: menuButtonStyle,
                onPressed: () {
                  _exportLayout();
                },
                shortcut: const SingleActivator(LogicalKeyboardKey.keyS,
                    shift: true, control: true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_as_outlined),
                    SizedBox(width: 8),
                    Text('Save As'),
                  ],
                )),
          ],
          child: const Text(
            'File',
          ),
        ),
        // Edit
        SubmenuButton(
            style: menuButtonStyle,
            menuChildren: [
              // Clear layout
              MenuItemButton(
                style: menuButtonStyle,
                onPressed: !(preferences.getBool(PrefKeys.layoutLocked) ??
                        Defaults.layoutLocked)
                    ? () {
                        setState(() {
                          _tabData[_currentTabIndex]
                              .tabGrid
                              .confirmClearWidgets(context);
                        });
                      }
                    : null,
                leadingIcon: const Icon(Icons.clear),
                child: const Text('Clear Layout'),
              ),
              // Lock/Unlock Layout
              MenuItemButton(
                style: menuButtonStyle,
                onPressed: () {
                  if (preferences.getBool(PrefKeys.layoutLocked) ??
                      Defaults.layoutLocked) {
                    _unlockLayout();
                  } else {
                    _lockLayout();
                  }

                  setState(() {});
                },
                leadingIcon: (preferences.getBool(PrefKeys.layoutLocked) ??
                        Defaults.layoutLocked)
                    ? const Icon(Icons.lock_open)
                    : const Icon(Icons.lock_outline),
                child: Text(
                    '${(preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) ? 'Unlock' : 'Lock'} Layout'),
              )
            ],
            child: const Text(
              'Edit',
            )),
        // Help
        SubmenuButton(
          style: menuButtonStyle,
          menuChildren: [
            // About
            MenuItemButton(
              style: menuButtonStyle,
              onPressed: () {
                _displayAboutDialog(context);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('About'),
                ],
              ),
            ),
            // Check for Updates (not for WPILib distribution)
            if (!isWPILib)
              MenuItemButton(
                style: menuButtonStyle,
                onPressed: () {
                  _checkForUpdates();
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.update_outlined),
                    SizedBox(width: 8),
                    Text('Check for Updates'),
                  ],
                ),
              ),
          ],
          child: const Text(
            'Help',
          ),
        ),
        const VerticalDivider(),
        // Settings
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.settings),
          onPressed: () {
            _displaySettingsDialog(context);
          },
          child: const Text('Settings'),
        ),
        const VerticalDivider(),
        // Add Widget
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.add),
          onPressed: !(preferences.getBool(PrefKeys.layoutLocked) ??
                  Defaults.layoutLocked)
              ? () => _displayAddWidgetDialog()
              : null,
          child: const Text('Add Widget'),
        ),
        if ((preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked)) ...[
          const VerticalDivider(),
          // Unlock Layout
          Tooltip(
            message: 'Unlock Layout',
            child: MenuItemButton(
              style: menuButtonStyle.copyWith(
                minimumSize:
                    const WidgetStatePropertyAll(Size(36.0, double.infinity)),
                maximumSize:
                    const WidgetStatePropertyAll(Size(36.0, double.infinity)),
              ),
              onPressed: () {
                _unlockLayout();
                setState(() {});
              },
              child: const Icon(Icons.lock_outline),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: CustomAppBar(
        titleText: appTitle,
        onWindowClose: onWindowClose,
        menuBar: menuBar,
      ),
      body: Focus(
        autofocus: true,
        canRequestFocus: true,
        descendantsAreTraversable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main dashboard page
            Expanded(
              child: Stack(
                children: [
                  EditableTabBar(
                    preferences: preferences,
                    currentIndex: _currentTabIndex,
                    onTabMoveLeft: () {
                      _moveTabLeft();
                    },
                    onTabMoveRight: () {
                      _moveTabRight();
                    },
                    onTabRename: (index, newData) {
                      setState(() {
                        _tabData[index] = newData;
                      });
                    },
                    onTabCreate: () {
                      String tabName = 'Tab ${_tabData.length + 1}';
                      setState(() {
                        _tabData.add(
                          TabData(
                              name: tabName,
                              tabGrid: TabGridModel(
                                ntConnection: widget.ntConnection,
                                preferences: widget.preferences,
                                onAddWidgetPressed: _displayAddWidgetDialog,
                              )),
                        );
                      });
                    },
                    onTabDestroy: (index) {
                      if (_tabData.length <= 1) {
                        return;
                      }

                      TabData currentTab = _tabData[index];

                      _showTabCloseConfirmation(context, currentTab.name, () {
                        if (_currentTabIndex == _tabData.length - 1) {
                          _currentTabIndex--;
                        }

                        _tabData[index].tabGrid.onDestroy();

                        setState(() {
                          _tabData.removeAt(index);
                        });
                      });
                    },
                    onTabChanged: (index) {
                      setState(() => _currentTabIndex = index);
                    },
                    onTabDuplicate: (index) {
                      setState(() {
                        Map<String, dynamic> tabJson =
                            _tabData[index].tabGrid.toJson();
                        TabGridModel newGrid = TabGridModel.fromJson(
                          ntConnection: widget.ntConnection,
                          preferences: preferences,
                          jsonData: tabJson,
                          onAddWidgetPressed: _displayAddWidgetDialog,
                          onJsonLoadingWarning: _showJsonLoadingWarning,
                        );
                        _tabData.insert(
                            index + 1,
                            TabData(
                                name: '${_tabData[index].name} (Copy)',
                                tabGrid: newGrid));
                      });
                    },
                    tabData: _tabData,
                  ),
                  _AddWidgetDialog(
                    ntConnection: widget.ntConnection,
                    preferences: widget.preferences,
                    grid: () => _tabData[_currentTabIndex].tabGrid,
                    visible: _addWidgetDialogVisible,
                    onNTDragUpdate: (globalPosition, widget) {
                      _tabData[_currentTabIndex]
                          .tabGrid
                          .addDragInWidget(widget, globalPosition);
                    },
                    onNTDragEnd: (widget) {
                      _tabData[_currentTabIndex]
                          .tabGrid
                          .placeDragInWidget(widget);
                    },
                    onLayoutDragUpdate: (globalPosition, widget) {
                      _tabData[_currentTabIndex]
                          .tabGrid
                          .addDragInWidget(widget, globalPosition);
                    },
                    onLayoutDragEnd: (widget) {
                      _tabData[_currentTabIndex]
                          .tabGrid
                          .placeDragInWidget(widget);
                    },
                    onClose: () {
                      setState(() => _addWidgetDialogVisible = false);
                    },
                  ),
                ],
              ),
            ),
            // Bottom bar
            Container(
              color: const Color.fromARGB(255, 20, 20, 20),
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: StreamBuilder(
                          stream: widget.ntConnection.connectionStatus(),
                          builder: (context, snapshot) {
                            bool connected = snapshot.data ?? false;

                            String connectedText = (connected)
                                ? 'Network Tables: Connected (${preferences.getString(PrefKeys.ipAddress)})'
                                : 'Network Tables: Disconnected';

                            return Text(
                              connectedText,
                              style: footerStyle?.copyWith(
                                color: (connected) ? Colors.green : Colors.red,
                              ),
                              textAlign: TextAlign.left,
                            );
                          }),
                    ),
                    Expanded(
                      child: Text(
                        'Team ${preferences.getInt(PrefKeys.teamNumber)?.toString() ?? 'Unknown'}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder(
                          stream: widget.ntConnection.latencyStream(),
                          builder: (context, snapshot) {
                            double latency = snapshot.data ?? 0.0;

                            return Text(
                              'Latency: ${latency.toStringAsFixed(2).padLeft(5)} ms',
                              textAlign: TextAlign.right,
                            );
                          }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWidgetDialog extends StatefulWidget {
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final TabGridModel Function() _grid;
  final bool _visible;

  final Function(Offset globalPosition, WidgetContainerModel widget)
      _onNTDragUpdate;
  final Function(WidgetContainerModel widget) _onNTDragEnd;

  final Function(Offset globalPosition, LayoutContainerModel widget)
      _onLayoutDragUpdate;
  final Function(LayoutContainerModel widget) _onLayoutDragEnd;

  final Function()? _onClose;

  const _AddWidgetDialog({
    required this.ntConnection,
    required this.preferences,
    required TabGridModel Function() grid,
    required bool visible,
    required dynamic Function(Offset, WidgetContainerModel) onNTDragUpdate,
    required dynamic Function(WidgetContainerModel) onNTDragEnd,
    required dynamic Function(Offset, LayoutContainerModel) onLayoutDragUpdate,
    required dynamic Function(LayoutContainerModel) onLayoutDragEnd,
    dynamic Function()? onClose,
  })  : _onClose = onClose,
        _onLayoutDragEnd = onLayoutDragEnd,
        _onNTDragEnd = onNTDragEnd,
        _onNTDragUpdate = onNTDragUpdate,
        _onLayoutDragUpdate = onLayoutDragUpdate,
        _visible = visible,
        _grid = grid;

  @override
  State<_AddWidgetDialog> createState() => _AddWidgetDialogState();
}

class _AddWidgetDialogState extends State<_AddWidgetDialog> {
  bool _hideMetadata = true;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget._visible,
      child: DraggableDialog(
        dialog: Container(
          decoration: const BoxDecoration(boxShadow: [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: -12.5,
              offset: Offset(5.0, 5.0),
              color: Colors.black87,
            )
          ]),
          child: Card(
            margin: const EdgeInsets.all(10.0),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text('Add Widget',
                      style: Theme.of(context).textTheme.titleMedium),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Network Tables'),
                      Tab(text: 'Layouts'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: TabBarView(
                      children: [
                        NetworkTableTree(
                          ntConnection: widget.ntConnection,
                          preferences: widget.preferences,
                          searchQuery: _searchQuery,
                          listLayoutBuilder: (
                              {required title, required children}) {
                            return widget._grid().createListLayout(
                                  title: title,
                                  children: children,
                                );
                          },
                          hideMetadata: _hideMetadata,
                          onDragUpdate: widget._onNTDragUpdate,
                          onDragEnd: widget._onNTDragEnd,
                        ),
                        ListView(
                          children: [
                            LayoutDragTile(
                              title: 'List Layout',
                              icon: Icons.table_rows,
                              layoutBuilder: () =>
                                  widget._grid().createListLayout(),
                              onDragUpdate: widget._onLayoutDragUpdate,
                              onDragEnd: widget._onLayoutDragEnd,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Builder(builder: (context) {
                        return IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            showPopover(
                              context: context,
                              direction: PopoverDirection.top,
                              transitionDuration:
                                  const Duration(milliseconds: 100),
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              barrierColor: Colors.transparent,
                              width: 200.0,
                              bodyBuilder: (context) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: DialogToggleSwitch(
                                    label: 'Hide Metadata',
                                    initialValue: _hideMetadata,
                                    onToggle: (value) {
                                      setState(() => _hideMetadata = value);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }),
                      Expanded(
                        child: SizedBox(
                          height: 40.0,
                          child: DialogTextInput(
                            onSubmit: (value) =>
                                setState(() => _searchQuery = value),
                            initialText: _searchQuery,
                            allowEmptySubmission: true,
                            label: 'Search',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          widget._onClose?.call();
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
