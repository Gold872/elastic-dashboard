import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:file_selector/file_selector.dart';
import 'package:popover/popover.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/shuffleboard_nt_listener.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
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
  final SharedPreferences preferences;
  final String version;
  final Function(Color color)? onColorChanged;

  const DashboardPage({
    super.key,
    required this.preferences,
    required this.version,
    this.onColorChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WindowListener {
  late final SharedPreferences _preferences;
  late final UpdateChecker _updateChecker;

  final List<TabGrid> _grids = [];

  final List<TabData> _tabData = [];

  final Function _mapEquals = const DeepCollectionEquality().equals;

  int _gridSize = Settings.gridSize;

  int _currentTabIndex = 0;

  bool _addWidgetDialogVisible = false;

  @override
  void initState() {
    super.initState();

    _preferences = widget.preferences;
    _updateChecker = UpdateChecker(currentVersion: widget.version);

    windowManager.addListener(this);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      Future(() async => await windowManager.setPreventClose(true));
    }

    _loadLayout();

    _setupShortcuts();

    ntConnection.dsClientConnect(
      onIPAnnounced: (ip) async {
        if (Settings.ipAddressMode != IPAddressMode.driverStation) {
          return;
        }

        if (_preferences.getString(PrefKeys.ipAddress) != ip) {
          await _preferences.setString(PrefKeys.ipAddress, ip);
        } else {
          return;
        }

        ntConnection.changeIPAddress(ip);
      },
      onDriverStationDockChanged: (docked) {
        if (Settings.autoResizeToDS && docked) {
          _onDriverStationDocked();
        } else {
          _onDriverStationUndocked();
        }
      },
    );

    ntConnection.addConnectedListener(() {
      setState(() {
        for (TabGrid grid in _grids) {
          grid.onNTConnect();
        }
      });
    });

    ntConnection.addDisconnectedListener(() {
      setState(() {
        for (TabGrid grid in _grids) {
          grid.onNTDisconnect();
        }
      });
    });

    ShuffleboardNTListener apiListener = ShuffleboardNTListener(
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
        if (Settings.layoutLocked) {
          return;
        }

        Iterable<String> tabNamesList = _tabData.map((data) => data.name);

        if (tabNamesList.contains(tab)) {
          return;
        }

        _tabData.add(TabData(name: tab));
        _grids.add(
          TabGrid(
            key: GlobalKey(),
            onAddWidgetPressed: _displayAddWidgetDialog,
          ),
        );
      },
      onWidgetAdded: (widgetData) {
        if (Settings.layoutLocked) {
          return;
        }
        // Needs to be done in case if widget data gets erased by the listener
        Map<String, dynamic> widgetDataCopy = {};

        widgetData.forEach(
            (key, value) => widgetDataCopy.putIfAbsent(key, () => value));

        List<String> tabNamesList = _tabData.map((data) => data.name).toList();

        String tabName = widgetDataCopy['tab'];

        if (!tabNamesList.contains(tabName)) {
          _tabData.add(TabData(name: tabName));
          _grids.add(TabGrid(
            key: GlobalKey(),
            onAddWidgetPressed: _displayAddWidgetDialog,
          ));

          tabNamesList.add(tabName);
        }

        int tabIndex = tabNamesList.indexOf(tabName);

        if (tabIndex == -1) {
          return;
        }

        _grids[tabIndex].addWidgetFromTabJson(widgetDataCopy);

        setState(() {});
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      apiListener.initializeSubscriptions();
      apiListener.initializeListeners();
      ntConnection.nt4Client.recallAnnounceListeners();
    });

    Future(() => _checkForUpdates(notifyIfLatest: false, notifyIfError: false));
  }

  @override
  void onWindowClose() async {
    Map<String, dynamic> savedJson =
        jsonDecode(_preferences.getString(PrefKeys.layout) ?? '{}');
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
      TabGrid grid = _grids[i];

      gridData.add({
        'name': data.name,
        'grid_layout': grid.toJson(),
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
        await _preferences.setString(PrefKeys.layout, jsonEncode(jsonData));
    await _saveWindowPosition();

    if (successful) {
      logger.info('Layout saved successfully!');
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.background,
        progressIndicatorBackground: colorScheme.background,
        progressIndicatorColor: const Color(0xff01CB67),
        enableShadow: false,
        width: 150,
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
        background: colorScheme.background,
        progressIndicatorBackground: colorScheme.background,
        progressIndicatorColor: const Color(0xffFE355C),
        enableShadow: false,
        width: 150,
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

    await _preferences.setString(PrefKeys.windowPosition, positionString);
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
        background: colorScheme.background,
        progressIndicatorBackground: colorScheme.background,
        progressIndicatorColor: const Color(0xffFE355C),
        enableShadow: false,
        width: 350,
        height: 100,
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
        background: colorScheme.background,
        enableShadow: false,
        width: 150,
        height: 100,
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
        onActionPressed: () async {
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
        background: colorScheme.background,
        progressIndicatorBackground: colorScheme.background,
        progressIndicatorColor: const Color(0xff01CB67),
        enableShadow: false,
        width: 150,
        height: 100,
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
    String jsonString = jsonEncode(jsonData);

    final Uint8List fileData = Uint8List.fromList(jsonString.codeUnits);

    final XFile jsonFile = XFile.fromData(fileData,
        mimeType: 'application/json', name: 'elastic-layout.json');

    logger.info('Saving layout data to ${saveLocation.path}');
    await jsonFile.saveTo(saveLocation.path);
  }

  void _importLayout() async {
    if (Settings.layoutLocked) {
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

    try {
      jsonDecode(jsonString);
    } catch (e) {
      _showJsonLoadingError(e.toString());
      return;
    }

    await _preferences.setString(PrefKeys.layout, jsonString);

    setState(() => _loadLayoutFromJsonData(jsonString));
  }

  void _loadLayout() {
    String? jsonString = _preferences.getString(PrefKeys.layout);

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
      Settings.gridSize = _gridSize;
      _preferences.setInt(PrefKeys.gridSize, _gridSize);
    }

    _tabData.clear();
    _grids.clear();

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

      _tabData.add(TabData(name: data['name']));

      _grids.add(
        TabGrid.fromJson(
          key: GlobalKey(),
          jsonData: data['grid_layout'],
          onAddWidgetPressed: _displayAddWidgetDialog,
          onJsonLoadingWarning: _showJsonLoadingWarning,
        ),
      );
    }

    _createDefaultTabs();

    if (_currentTabIndex >= _grids.length) {
      _currentTabIndex = _grids.length - 1;
    }
  }

  void _createDefaultTabs() {
    if (_tabData.isEmpty || _grids.isEmpty) {
      logger.info('Creating default Teleoperated and Autonomous tabs');
      setState(() {
        _tabData.addAll([
          TabData(name: 'Teleoperated'),
          TabData(name: 'Autonomous'),
        ]);

        _grids.addAll([
          TabGrid(
            key: GlobalKey(),
            onAddWidgetPressed: _displayAddWidgetDialog,
          ),
          TabGrid(
            key: GlobalKey(),
            onAddWidgetPressed: _displayAddWidgetDialog,
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
        background: colorScheme.background,
        progressIndicatorBackground: colorScheme.background,
        progressIndicatorColor: const Color(0xffFE355C),
        enableShadow: false,
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
        background: colorScheme.background,
        progressIndicatorBackground: colorScheme.background,
        progressIndicatorColor: Colors.yellow,
        enableShadow: false,
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
        if (Settings.layoutLocked) {
          return;
        }
        String newTabName = 'Tab ${_tabData.length + 1}';
        int newTabIndex = _tabData.length;

        _tabData.add(TabData(name: newTabName));
        _grids.add(
          TabGrid(
            key: GlobalKey(),
            onAddWidgetPressed: _displayAddWidgetDialog,
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
        if (Settings.layoutLocked) {
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

          _grids[oldTabIndex].onDestroy();

          setState(() {
            _tabData.removeAt(oldTabIndex);
            _grids.removeAt(oldTabIndex);
          });
        });
      },
    );
  }

  void _lockLayout() async {
    for (TabGrid grid in _grids) {
      grid.lockLayout();
    }
    Settings.layoutLocked = true;
    await _preferences.setBool(PrefKeys.layoutLocked, true);
  }

  void _unlockLayout() async {
    for (TabGrid grid in _grids) {
      grid.unlockLayout();
    }
    Settings.layoutLocked = false;
    await _preferences.setBool(PrefKeys.layoutLocked, false);
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
      applicationName: 'Elastic',
      applicationVersion: widget.version,
      applicationIcon: Image.asset(
        'assets/logos/logo.png',
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
        preferences: widget.preferences,
        onTeamNumberChanged: (String? data) async {
          if (data == null) {
            return;
          }

          int? newTeamNumber = int.tryParse(data);

          if (newTeamNumber == null ||
              (newTeamNumber == Settings.teamNumber &&
                  Settings.teamNumber != 9999)) {
            return;
          }

          await _preferences.setInt(PrefKeys.teamNumber, newTeamNumber);
          Settings.teamNumber = newTeamNumber;

          switch (Settings.ipAddressMode) {
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
          if (mode == Settings.ipAddressMode) {
            return;
          }
          await _preferences.setInt(PrefKeys.ipAddressMode, mode.index);

          Settings.ipAddressMode = mode;

          switch (mode) {
            case IPAddressMode.driverStation:
              String? lastAnnouncedIP = ntConnection.dsClient.lastAnnouncedIP;

              if (lastAnnouncedIP == null) {
                break;
              }

              _updateIPAddress(lastAnnouncedIP);
              break;
            case IPAddressMode.roboRIOmDNS:
              _updateIPAddress(
                  IPAddressUtil.teamNumberToRIOmDNS(Settings.teamNumber));
              break;
            case IPAddressMode.teamNumber:
              _updateIPAddress(
                  IPAddressUtil.teamNumberToIP(Settings.teamNumber));
              break;
            case IPAddressMode.localhost:
              _updateIPAddress('localhost');
              break;
            default:
              setState(() {});
              break;
          }
        },
        onIPAddressChanged: (String? data) async {
          if (data == null || data == Settings.ipAddress) {
            return;
          }

          _updateIPAddress(data);
        },
        onGridToggle: (value) async {
          setState(() {
            Settings.showGrid = value;
          });

          await _preferences.setBool(PrefKeys.showGrid, value);
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
            Settings.gridSize = newGridSize;
            _gridSize = newGridSize;
          });

          await _preferences.setInt(PrefKeys.gridSize, newGridSize);

          for (TabGrid grid in _grids) {
            grid.resizeGrid(_gridSize, _gridSize);
          }
        },
        onCornerRadiusChanged: (radius) async {
          if (radius == null) {
            return;
          }

          double? newRadius = double.tryParse(radius);

          if (newRadius == null || newRadius == Settings.cornerRadius) {
            return;
          }

          setState(() {
            Settings.cornerRadius = newRadius;

            for (TabGrid grid in _grids) {
              grid.refreshAllContainers();
            }
          });

          await _preferences.setDouble(PrefKeys.cornerRadius, newRadius);
        },
        onResizeToDSChanged: (value) async {
          setState(() {
            Settings.autoResizeToDS = value;

            if (value && ntConnection.dsClient.driverStationDocked) {
              _onDriverStationDocked();
            } else {
              _onDriverStationUndocked();
            }
          });

          await _preferences.setBool(PrefKeys.autoResizeToDS, value);
        },
        onRememberWindowPositionChanged: (value) async {
          await _preferences.setBool(PrefKeys.rememberWindowPosition, value);
        },
        onLayoutLock: (value) {
          setState(() {
            if (value) {
              _lockLayout();
            } else {
              _unlockLayout();
            }
          });
        },
        onDefaultPeriodChanged: (value) async {
          if (value == null) {
            return;
          }
          double? newPeriod = double.tryParse(value);

          if (newPeriod == null || newPeriod == Settings.defaultPeriod) {
            return;
          }

          await _preferences.setDouble(PrefKeys.defaultPeriod, newPeriod);

          setState(() => Settings.defaultPeriod = newPeriod);
        },
        onDefaultGraphPeriodChanged: (value) async {
          if (value == null) {
            return;
          }
          double? newPeriod = double.tryParse(value);

          if (newPeriod == null || newPeriod == Settings.defaultGraphPeriod) {
            return;
          }

          await _preferences.setDouble(PrefKeys.defaultGraphPeriod, newPeriod);

          setState(() => Settings.defaultGraphPeriod = newPeriod);
        },
        onColorChanged: widget.onColorChanged,
      ),
    );
  }

  void _updateIPAddress(String newIPAddress) async {
    if (newIPAddress == Settings.ipAddress) {
      return;
    }
    await _preferences.setString(PrefKeys.ipAddress, newIPAddress);
    Settings.ipAddress = newIPAddress;

    setState(() {
      ntConnection.changeIPAddress(newIPAddress);
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
    if (Settings.layoutLocked) {
      return;
    }
    if (_currentTabIndex <= 0) {
      logger.debug(
          'Ignoring move tab left, tab index is already $_currentTabIndex');
      return;
    }

    logger.info('Moving current tab at index $_currentTabIndex to the left');

    setState(() {
      // Swap the tab data
      TabData tempData = _tabData[_currentTabIndex - 1];
      _tabData[_currentTabIndex - 1] = _tabData[_currentTabIndex];
      _tabData[_currentTabIndex] = tempData;

      // Swap the tab grids
      TabGrid tempGrid = _grids[_currentTabIndex - 1];
      _grids[_currentTabIndex - 1] = _grids[_currentTabIndex];
      _grids[_currentTabIndex] = tempGrid;

      _currentTabIndex -= 1;
    });
  }

  void _moveTabRight() {
    if (Settings.layoutLocked) {
      return;
    }
    if (_currentTabIndex >= _tabData.length - 1) {
      logger.debug(
          'Ignoring move tab left, tab index is already $_currentTabIndex');
      return;
    }

    logger.info('Moving current tab at index $_currentTabIndex to the right');

    setState(() {
      // Swap the tab data
      TabData tempData = _tabData[_currentTabIndex + 1];
      _tabData[_currentTabIndex + 1] = _tabData[_currentTabIndex];
      _tabData[_currentTabIndex] = tempData;

      // Swap the tab grids
      TabGrid tempGrid = _grids[_currentTabIndex + 1];
      _grids[_currentTabIndex + 1] = _grids[_currentTabIndex];
      _grids[_currentTabIndex] = tempGrid;

      _currentTabIndex += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? menuTextStyle = Theme.of(context).textTheme.bodySmall;
    TextStyle? footerStyle = Theme.of(context).textTheme.bodyMedium;
    ButtonStyle menuButtonStyle = ButtonStyle(
      alignment: Alignment.center,
      textStyle: MaterialStateProperty.all(menuTextStyle),
      backgroundColor:
          const MaterialStatePropertyAll(Color.fromARGB(255, 25, 25, 25)),
      iconSize: const MaterialStatePropertyAll(20.0),
    );

    MenuBar menuBar = MenuBar(
      style: const MenuStyle(
        backgroundColor:
            MaterialStatePropertyAll(Color.fromARGB(255, 25, 25, 25)),
        elevation: MaterialStatePropertyAll(0),
      ),
      children: [
        Center(
          child: Image.asset(
            'assets/logos/logo.png',
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
              onPressed:
                  (!Settings.layoutLocked) ? () => _importLayout() : null,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyO, control: true),
              child: const Text(
                'Open Layout',
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
              child: const Text(
                'Save',
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
              child: const Text(
                'Save As',
              ),
            ),
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
                onPressed: (!Settings.layoutLocked)
                    ? () {
                        setState(() {
                          _grids[_currentTabIndex].clearWidgets(context);
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
                  setState(() {
                    if (Settings.layoutLocked) {
                      _unlockLayout();
                    } else {
                      _lockLayout();
                    }
                  });
                },
                leadingIcon: (Settings.layoutLocked)
                    ? const Icon(Icons.lock_open)
                    : const Icon(Icons.lock_outline),
                child: Text(
                    '${(Settings.layoutLocked) ? 'Unlock' : 'Lock'} Layout'),
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
              child: const Text(
                'About',
              ),
            ),
            // Check for Updates
            MenuItemButton(
              style: menuButtonStyle,
              onPressed: () {
                _checkForUpdates();
              },
              child: const Text(
                'Check for Updates',
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
          onPressed:
              (!Settings.layoutLocked) ? () => _displayAddWidgetDialog() : null,
          child: const Text('Add Widget'),
        ),
        if (Settings.layoutLocked) ...[
          const VerticalDivider(),
          // Unlock Layout
          Tooltip(
            message: 'Unlock Layout',
            child: MenuItemButton(
              style: menuButtonStyle.copyWith(
                minimumSize:
                    const MaterialStatePropertyAll(Size(36.0, double.infinity)),
                maximumSize:
                    const MaterialStatePropertyAll(Size(36.0, double.infinity)),
              ),
              onPressed: () {
                setState(() {
                  _unlockLayout();
                });
              },
              child: const Icon(Icons.lock_outline),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: CustomAppBar(
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
                    onTabCreate: (tab) {
                      setState(() {
                        _tabData.add(tab);
                        _grids.add(TabGrid(
                          key: GlobalKey(),
                          onAddWidgetPressed: _displayAddWidgetDialog,
                        ));
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

                        _grids[index].onDestroy();

                        setState(() {
                          _tabData.removeAt(index);
                          _grids.removeAt(index);
                        });
                      });
                    },
                    onTabChanged: (index) {
                      setState(() => _currentTabIndex = index);
                    },
                    tabData: _tabData,
                    tabViews: _grids,
                  ),
                  _AddWidgetDialog(
                    grid: () => _grids[_currentTabIndex],
                    visible: _addWidgetDialogVisible,
                    onNTDragUpdate: (globalPosition, widget) {
                      _grids[_currentTabIndex]
                          .addDragInWidget(widget, globalPosition);
                    },
                    onNTDragEnd: (widget) {
                      _grids[_currentTabIndex].placeDragInWidget(widget);
                    },
                    onLayoutDragUpdate: (globalPosition, widget) {
                      _grids[_currentTabIndex]
                          .addDragInWidget(widget, globalPosition);
                    },
                    onLayoutDragEnd: (widget) {
                      _grids[_currentTabIndex].placeDragInWidget(widget);
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
                          stream: ntConnection.connectionStatus(),
                          builder: (context, snapshot) {
                            bool connected = snapshot.data ?? false;

                            String connectedText = (connected)
                                ? 'Network Tables: Connected (${_preferences.getString(PrefKeys.ipAddress)})'
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
                        'Team ${_preferences.getInt(PrefKeys.teamNumber)?.toString() ?? 'Unknown'}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder(
                          stream: ntConnection.latencyStream(),
                          builder: (context, snapshot) {
                            int latency = snapshot.data ?? 0;

                            return Text(
                              'Latency: ${latency.toString().padLeft(5)} ms',
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
  final TabGrid Function() _grid;
  final bool _visible;

  final Function(Offset globalPosition, WidgetContainerModel widget)
      _onNTDragUpdate;
  final Function(WidgetContainerModel widget) _onNTDragEnd;

  final Function(Offset globalPosition, LayoutContainerModel widget)
      _onLayoutDragUpdate;
  final Function(LayoutContainerModel widget) _onLayoutDragEnd;

  final Function()? _onClose;

  const _AddWidgetDialog({
    required TabGrid Function() grid,
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
                                  Theme.of(context).colorScheme.background,
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
                      const Spacer(),
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
