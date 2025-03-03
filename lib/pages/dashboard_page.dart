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
import 'package:http/http.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:popover/popover.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'package:elastic_dashboard/services/app_distributor.dart';
import 'package:elastic_dashboard/services/elastic_layout_downloader.dart';
import 'package:elastic_dashboard/services/elasticlib_listener.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/shuffleboard_nt_listener.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
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

enum LayoutDownloadMode {
  overwrite(
    name: 'Overwrite',
    description:
        'Keeps existing tabs that are not defined in the remote layout. Any tabs that are defined in the remote layout will be overwritten locally.',
  ),
  merge(
    name: 'Merge',
    description:
        'Merge the downloaded layout with the existing one. If a new widget cannot be properly placed, it will not be added.',
  ),
  reload(
    name: 'Full Reload',
    description: 'Deletes the existing layout and loads the new one.',
  );

  final String name;
  final String description;

  const LayoutDownloadMode({required this.name, required this.description});

  static String get descriptions {
    String result = '';
    for (final value in values) {
      result += '${value.name}: ';
      result += value.description;

      if (value != values.last) {
        result += '\n\n';
      }
    }
    return result;
  }
}

class DashboardPage extends StatefulWidget {
  final String version;
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final UpdateChecker? updateChecker;
  final ElasticLayoutDownloader? layoutDownloader;
  final Function(Color color)? onColorChanged;
  final Function(FlexSchemeVariant variant)? onThemeVariantChanged;

  const DashboardPage({
    super.key,
    required this.ntConnection,
    required this.preferences,
    required this.version,
    this.updateChecker,
    this.layoutDownloader,
    this.onColorChanged,
    this.onThemeVariantChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WindowListener {
  SharedPreferences get preferences => widget.preferences;
  late final ElasticLibListener _robotNotificationListener;
  late final UpdateChecker _updateChecker;
  late final ElasticLayoutDownloader _layoutDownloader;

  bool _seenShuffleboardWarning = false;

  final List<TabData> _tabData = [];

  final Function _mapEquals = const DeepCollectionEquality().equals;

  late int _gridSize =
      preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

  UpdateCheckerResponse lastUpdateResponse =
      UpdateCheckerResponse(updateAvailable: false, error: false);

  int _currentTabIndex = 0;

  bool _addWidgetDialogVisible = false;

  @override
  void initState() {
    super.initState();

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
        _showShuffleboardWarningMessage();
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

        _switchToTab(tabIndex);
      },
      onTabCreated: (tab) {
        _showShuffleboardWarningMessage();
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
        _showShuffleboardWarningMessage();
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        // Needs to be converted into the tab json format
        Map<String, dynamic> tabJson = {};

        String tabName = widgetData['tab'];
        tabJson.addAll({'containers': <Map<String, dynamic>>[]});
        tabJson.addAll({'layouts': <Map<String, dynamic>>[]});

        if (!(widgetData.containsKey('layout') && widgetData['layout'])) {
          tabJson['containers']!.add(widgetData);
        } else {
          tabJson['layouts']!.add(widgetData);
        }

        if (!_tabData.any((tab) => tab.name == tabName)) {
          _tabData.add(
            TabData(
              name: tabName,
              tabGrid: TabGridModel.fromJson(
                ntConnection: widget.ntConnection,
                preferences: widget.preferences,
                jsonData: tabJson,
                onJsonLoadingWarning: _showJsonLoadingWarning,
                onAddWidgetPressed: _displayAddWidgetDialog,
              ),
            ),
          );
        } else {
          _tabData
              .firstWhere((tab) => tab.name == tabName)
              .tabGrid
              .mergeFromJson(
                jsonData: tabJson,
                onJsonLoadingWarning: _showJsonLoadingWarning,
              );
        }

        setState(() {});
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      apiListener.initializeSubscriptions();
      apiListener.initializeListeners();
    });

    _robotNotificationListener = ElasticLibListener(
        ntConnection: widget.ntConnection,
        onTabSelected: (tabIdentifier) {
          if (tabIdentifier is int) {
            if (tabIdentifier >= _tabData.length) {
              return;
            }
            _switchToTab(tabIdentifier);
          } else if (tabIdentifier is String) {
            int tabIndex =
                _tabData.indexWhere((tab) => tab.name == tabIdentifier);
            if (tabIndex == -1) {
              return;
            }
            _switchToTab(tabIndex);
          }
        },
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
              ),
            );
            if (mounted) widget.show(context);
          });
        });
    _robotNotificationListener.listen();

    _layoutDownloader =
        widget.layoutDownloader ?? ElasticLayoutDownloader(Client());

    _updateChecker =
        widget.updateChecker ?? UpdateChecker(currentVersion: widget.version);

    if (!isWPILib) {
      Future(() => _checkForUpdates(
            notifyIfLatest: false,
            notifyIfError: false,
          ));
    }
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
    exit(0);
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

    bool successful =
        await preferences.setString(PrefKeys.layout, jsonEncode(jsonData));
    await _saveWindowPosition();

    if (successful) {
      logger.info('Layout saved successfully');
      _showInfoNotification(
        title: 'Saved',
        message: 'Layout saved successfully',
        width: 300,
      );
    } else {
      logger.error('Could not save layout');
      _showInfoNotification(
        title: 'Error While Saving Layout',
        message: 'Failed to save layout, please try again',
        width: 300,
      );
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

  void _checkForUpdates({
    bool notifyIfLatest = true,
    bool notifyIfError = true,
  }) async {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    ButtonThemeData buttonTheme = ButtonTheme.of(context);

    UpdateCheckerResponse updateResponse =
        await _updateChecker.isUpdateAvailable();

    if (mounted) {
      setState(() => lastUpdateResponse = updateResponse);
    }

    if (updateResponse.error && notifyIfError) {
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xffFE355C),
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
        background: colorScheme.surface,
        width: 350,
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
        action: TextButton(
          onPressed: () async {
            Uri url = Uri.parse(Settings.releasesLink);

            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Text(
            'Update',
            style: textTheme.bodyMedium!.copyWith(
              color: buttonTheme.colorScheme?.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      if (mounted) {
        notification.show(context);
      }
    } else if (updateResponse.onLatestVersion && notifyIfLatest) {
      _showInfoNotification(
        title: 'No Updates Available',
        message: 'You are running on the latest version of Elastic',
        width: 350,
        height: 75,
      );
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

    final Uint8List fileData = utf8.encode(jsonString);

    final XFile jsonFile = XFile.fromData(
      fileData,
      mimeType: 'application/json',
      name: 'elastic-layout.json',
    );

    logger.info('Saving layout data to ${saveLocation.path}');
    await jsonFile.saveTo(saveLocation.path);
    _showInfoNotification(
      title: 'Exported Layout',
      message: 'Successfully exported layout to\n${saveLocation.path}',
      width: 500,
    );
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

  bool _validateJsonData(Map<String, dynamic>? jsonData) {
    if (jsonData == null) {
      _showJsonLoadingError('Invalid JSON format, aborting.');
      return false;
    }

    if (!jsonData.containsKey('tabs')) {
      _showJsonLoadingError('JSON does not contain necessary data, aborting.');
      return false;
    }

    for (Map<String, dynamic> data in jsonData['tabs']) {
      if (tryCast(data['name']) == null) {
        _showJsonLoadingError('Tab name not specified');
        return false;
      }

      if (tryCast<Map>(data['grid_layout']) == null) {
        _showJsonLoadingError(
            'Grid layout not specified for tab \'${data['name']}\'');
        return false;
      }
    }

    return true;
  }

  void _clearLayout() {
    for (TabData tab in _tabData) {
      tab.tabGrid.onDestroy();
    }
    _tabData.clear();
  }

  bool _loadLayoutFromJsonData(String jsonString) {
    logger.info('Loading layout from json');
    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!_validateJsonData(jsonData)) {
      _createDefaultTabs();
      return false;
    }

    if (jsonData!.containsKey('grid_size')) {
      _gridSize = tryCast(jsonData['grid_size']) ?? _gridSize;
      preferences.setInt(PrefKeys.gridSize, _gridSize);
    }

    _clearLayout();

    for (Map<String, dynamic> data in jsonData['tabs']) {
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
      _switchToTab(_tabData.length - 1);
    }

    return true;
  }

  bool _mergeLayoutFromJsonData(String jsonString) {
    logger.info('Merging layout from json');

    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!_validateJsonData(jsonData)) {
      return false;
    }

    for (Map<String, dynamic> tabJson in jsonData!['tabs']) {
      String tabName = tabJson['name'];
      if (!_tabData.any((tab) => tab.name == tabName)) {
        _tabData.add(
          TabData(
            name: tabName,
            tabGrid: TabGridModel.fromJson(
              ntConnection: widget.ntConnection,
              preferences: widget.preferences,
              jsonData: tabJson['grid_layout'],
              onAddWidgetPressed: _displayAddWidgetDialog,
              onJsonLoadingWarning: _showJsonLoadingWarning,
            ),
          ),
        );
      } else {
        TabGridModel existingTab =
            _tabData.firstWhere((tab) => tab.name == tabName).tabGrid;
        existingTab.mergeFromJson(
          jsonData: tabJson['grid_layout'],
          onJsonLoadingWarning: _showJsonLoadingWarning,
        );
      }
    }

    _showInfoNotification(
      title: 'Successfully Downloaded Layout',
      message: 'Remote layout has been successfully downloaded and merged!',
      width: 350,
    );

    setState(() {});

    return true;
  }

  void _overwriteLayoutFromJsonData(String jsonString) {
    logger.info('Overwriting layout from json');

    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!_validateJsonData(jsonData)) {
      return;
    }

    int overwritten = 0;
    for (Map<String, dynamic> tabJson in jsonData!['tabs']) {
      String tabName = tabJson['name'];
      if (!_tabData.any((tab) => tab.name == tabName)) {
        _tabData.add(
          TabData(
            name: tabName,
            tabGrid: TabGridModel.fromJson(
              ntConnection: widget.ntConnection,
              preferences: widget.preferences,
              jsonData: tabJson['grid_layout'],
              onAddWidgetPressed: _displayAddWidgetDialog,
              onJsonLoadingWarning: _showJsonLoadingWarning,
            ),
          ),
        );
      } else {
        overwritten++;
        TabGridModel existingTab =
            _tabData.firstWhere((tab) => tab.name == tabName).tabGrid;
        existingTab.onDestroy();
        existingTab.loadFromJson(
          jsonData: tabJson['grid_layout'],
          onJsonLoadingWarning: _showJsonLoadingWarning,
        );
      }
    }

    _showInfoNotification(
      title: 'Successfully Downloaded Layout',
      message:
          'Remote layout has been successfully downloaded, $overwritten tabs were overwritten.',
      width: 350,
    );
  }

  Future<({String layout, LayoutDownloadMode mode})?>
      _showRemoteLayoutSelection(List<String> fileNames) async {
    if (!mounted) {
      return null;
    }
    ValueNotifier<String?> layoutSelection = ValueNotifier(null);
    ValueNotifier<LayoutDownloadMode> modeSelection =
        ValueNotifier(LayoutDownloadMode.overwrite);

    bool showModes = false;
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Layout'),
        content: SizedBox(
          width: 350,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Layout File'),
                  ValueListenableBuilder(
                    valueListenable: layoutSelection,
                    builder: (_, value, child) => DialogDropdownChooser<String>(
                      choices: fileNames,
                      initialValue: value,
                      onSelectionChanged: (selection) =>
                          layoutSelection.value = selection,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Download Mode'),
                  Row(
                    children: [
                      Flexible(
                        child: ValueListenableBuilder(
                          valueListenable: modeSelection,
                          builder: (_, value, child) =>
                              DialogDropdownChooser<LayoutDownloadMode>(
                            choices: LayoutDownloadMode.values,
                            initialValue: value,
                            nameMap: (value) => value.name,
                            onSelectionChanged: (selection) {
                              if (selection != null) {
                                modeSelection.value = selection;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      TextButton.icon(
                        label: const Text('Help'),
                        icon: const Icon(Icons.help_outline),
                        onPressed: () {
                          setState(() => showModes = !showModes);
                        },
                      ),
                    ],
                  ),
                  if (showModes) ...[
                    const SizedBox(height: 5),
                    Text(LayoutDownloadMode.descriptions),
                  ],
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder(
            valueListenable: layoutSelection,
            builder: (_, value, child) => TextButton(
              onPressed: (value != null)
                  ? () => Navigator.of(context)
                      .pop((layout: value, mode: modeSelection.value))
                  : null,
              child: const Text('Download'),
            ),
          ),
        ],
      ),
    );
  }

  void _loadLayoutFromRobot() async {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }

    LayoutDownloadResponse<List<String>> layoutsResponse =
        await _layoutDownloader.getAvailableLayouts(
      ntConnection: widget.ntConnection,
      preferences: preferences,
    );

    if (!layoutsResponse.successful) {
      _showErrorNotification(
        title: 'Failed to Retrieve Layout List',
        message: layoutsResponse.data.firstOrNull ??
            'Unable to retrieve list of available layouts',
        width: 400,
      );
      return;
    }

    if (layoutsResponse.data.isEmpty) {
      _showErrorNotification(
        title: 'Failed to Retrieve Layout List',
        message:
            'No layouts were found, ensure a valid layout json file is placed in the root directory of your deploy directory.',
        width: 400,
      );
      return;
    }

    final selectedLayout = await _showRemoteLayoutSelection(
      layoutsResponse.data.sorted((a, b) => a.compareTo(b)),
    );

    if (selectedLayout == null) {
      return;
    }

    LayoutDownloadResponse response = await _layoutDownloader.downloadLayout(
      ntConnection: widget.ntConnection,
      preferences: preferences,
      layoutName: selectedLayout.layout,
    );

    if (!response.successful) {
      _showErrorNotification(
        title: 'Failed to Download Layout',
        message: response.data,
        width: 400,
      );
      return;
    }

    switch (selectedLayout.mode) {
      case LayoutDownloadMode.merge:
        _mergeLayoutFromJsonData(response.data);
      case LayoutDownloadMode.overwrite:
        setState(() => _overwriteLayoutFromJsonData(response.data));
      case LayoutDownloadMode.reload:
        setState(() {
          bool success = _loadLayoutFromJsonData(response.data);
          if (success) {
            _showInfoNotification(
              title: 'Successfully Downloaded Layout',
              message: 'Remote layout has been successfully downloaded!',
              width: 350,
            );
          }
        });
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

  void _showShuffleboardWarningMessage() {
    if (_seenShuffleboardWarning) {
      return;
    }
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;
    ButtonThemeData buttonTheme = ButtonTheme.of(context);

    ElegantNotification notification = ElegantNotification(
      autoDismiss: false,
      background: colorScheme.surface,
      showProgressIndicator: false,
      width: 450,
      height: 250,
      position: Alignment.bottomRight,
      icon: const Icon(Icons.warning, color: Colors.yellow),
      action: TextButton(
        onPressed: () async {
          Uri url = Uri.parse(
              'https://frc-elastic.gitbook.io/docs/additional-features-and-references/remote-layout-downloading#shuffleboard-api-migration-guide');

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        child: Text(
          'Documentation',
          style: textTheme.bodyMedium!.copyWith(
            color: buttonTheme.colorScheme?.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        'Shuffleboard API Deprecation',
        style: textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      description: const Text(
        'Support for the Shuffleboard API is deprecated in favor of remote layout downloading and will be removed after the 2025 season.\n\nAn alternative layout system is provided in the form of remote layout downloading. See the documentation for more details about migration.',
        overflow: TextOverflow.ellipsis,
        maxLines: 7,
      ),
    );

    if (mounted) {
      notification.show(context);
    }
    _seenShuffleboardWarning = true;
  }

  void _showJsonLoadingError(String errorMessage) {
    logger.error(errorMessage);
    Future(() {
      int lines = '\n'.allMatches(errorMessage).length + 1;

      _showErrorNotification(
        title: 'Error while loading JSON data',
        message: errorMessage,
        width: 350,
        height: 100 + (lines - 1) * 10,
      );
    });
  }

  void _showJsonLoadingWarning(String warningMessage) {
    logger.warning(warningMessage);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      int lines = '\n'.allMatches(warningMessage).length + 1;

      _showWarningNotification(
        title: 'Warning while loading JSON data',
        message: warningMessage,
        width: 350,
        height: 100 + (lines - 1) * 10,
      );
    });
  }

  void _showInfoNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) =>
      _showNotification(
        title: title,
        message: message,
        color: const Color(0xff01CB67),
        icon: const Icon(Icons.error, color: Color(0xff01CB67)),
        toastDuration: toastDuration,
        width: width,
        height: height,
      );

  void _showWarningNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) =>
      _showNotification(
        title: title,
        message: message,
        color: Colors.yellow,
        icon: const Icon(Icons.warning, color: Colors.yellow),
        toastDuration: toastDuration,
        width: width,
        height: height,
      );

  void _showErrorNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) =>
      _showNotification(
        title: title,
        message: message,
        color: const Color(0xffFE355C),
        icon: const Icon(Icons.error, color: Color(0xffFE355C)),
        toastDuration: toastDuration,
        width: width,
        height: height,
      );

  void _showNotification({
    required String title,
    required String message,
    required Color color,
    required Widget icon,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextTheme textTheme = Theme.of(context).textTheme;

    ElegantNotification notification = ElegantNotification(
      background: colorScheme.surface,
      progressIndicatorBackground: colorScheme.surface,
      progressIndicatorColor: color,
      width: width,
      height: height,
      position: Alignment.bottomRight,
      toastDuration: toastDuration,
      icon: icon,
      title: Text(
        title,
        style: textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      description: Flexible(child: Text(message)),
    );

    if (mounted) {
      notification.show(context);
    }
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
    // Download from robot (Ctrl + D)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyD,
        modifiers: [KeyModifier.control],
      ),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }

        _loadLayoutFromRobot();
      },
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
            _switchToTab(i - 1);
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

        _switchToTab(newTabIndex);
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
            _tabData[oldTabIndex].tabGrid.dispose();
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
            'Elastic was created by Nadav from FRC Team 353, the POBots, in the Summer of 2023.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'The goal of Elastic is to have the essential features needed for a driver dashboard, but with an elegant and modern display and a focus on customizability and performance.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic is an ongoing project; if you have any ideas, feedback, or bug reports, feel free to share them on the Github page!\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was built with inspiration from Shuffleboard and AdvantageScope, along with significant help from FRC and WPILib developers.\n',
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
        onLogLevelChanged: (level) async {
          if (level == null) {
            logger.info('Removing log level preference');
            await preferences.remove(PrefKeys.logLevel);
            Logger.level = Defaults.logLevel;
            return;
          }
          logger.info('Changing log level to ${level.levelName}');
          Logger.level = level;
          await preferences.setString(PrefKeys.logLevel, level.levelName);
        },
        onGridDPIChanged: (value) async {
          if (value == null) {
            return;
          }
          num? dpiOverride = double.tryParse(value) ?? int.tryParse(value);
          if (dpiOverride != null && dpiOverride <= 0) {
            return;
          }
          if (dpiOverride != null) {
            logger.info('Setting DPI override to ${dpiOverride.toDouble()}');
            await preferences.setDouble(
                PrefKeys.gridDpiOverride, dpiOverride.toDouble());
          } else {
            logger.info('Removing DPI override preference');
            await preferences.remove(PrefKeys.gridDpiOverride);
          }
          setState(() {});
        },
        onAutoSubmitButtonChanged: (value) async {
          await preferences.setBool(PrefKeys.autoTextSubmitButton, value);
          setState(() {});
        },
        onOpenAssetsFolderPressed: () async {
          Uri uri = Uri.file(
              '${path.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/');
          if (await canLaunchUrl(uri)) {
            logger.info('Opening URL (assets folder): ${uri.toString()}');
            launchUrl(uri);
          }
        },
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
    Size screenSize = primaryDisplay.visibleSize ?? primaryDisplay.size;

    await windowManager.unmaximize();

    Size newScreenSize = Size(screenSize.width, screenSize.height - 200);

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
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
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

  void _switchToTab(int tabIndex) =>
      setState(() => _currentTabIndex = tabIndex);

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

    _switchToTab(moveIndex);
  }

  void _moveToPreviousTab() {
    int moveIndex = _currentTabIndex - 1;

    if (moveIndex < 0) {
      moveIndex = _tabData.length - 1;
    }

    _switchToTab(moveIndex);
  }

  @override
  Widget build(BuildContext context) {
    final double windowWidth = MediaQuery.of(context).size.width;

    TextStyle? menuTextStyle = Theme.of(context).textTheme.bodySmall;
    TextStyle? footerStyle = Theme.of(context).textTheme.bodyMedium;
    ButtonStyle menuButtonStyle = ButtonStyle(
      alignment: Alignment.center,
      textStyle: WidgetStatePropertyAll(menuTextStyle),
      backgroundColor:
          const WidgetStatePropertyAll(Color.fromARGB(255, 25, 25, 25)),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      iconSize: const WidgetStatePropertyAll(20.0),
    );

    final bool layoutLocked =
        preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked;

    final double minWindowWidth = layoutLocked ? 500 : 460;
    final bool consolidateMenu = windowWidth < minWindowWidth;

    List<Widget> menuChildren = [
      // File
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // Open Layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked ? _importLayout : null,
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
            onPressed: _saveLayout,
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
            onPressed: _exportLayout,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              shift: true,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_as_outlined),
                SizedBox(width: 8),
                Text('Save As'),
              ],
            ),
          ),
          // Download layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked ? _loadLayoutFromRobot : null,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyD,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download),
                SizedBox(width: 8),
                Text('Download From Robot'),
              ],
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
            onPressed: !layoutLocked
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
              if (layoutLocked) {
                _unlockLayout();
              } else {
                _lockLayout();
              }

              setState(() {});
            },
            leadingIcon: layoutLocked
                ? const Icon(Icons.lock_open)
                : const Icon(Icons.lock_outline),
            child: Text('${layoutLocked ? 'Unlock' : 'Lock'} Layout'),
          )
        ],
        child: const Text(
          'Edit',
        ),
      ),
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
    ];

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
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 5),
        if (!consolidateMenu)
          ...menuChildren
        else
          SubmenuButton(
            style: menuButtonStyle.copyWith(
              iconSize: const WidgetStatePropertyAll(24),
            ),
            menuChildren: menuChildren,
            child: const Icon(Icons.menu),
          ),
        const VerticalDivider(width: 4),
        // Settings
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.settings),
          onPressed: () {
            _displaySettingsDialog(context);
          },
          child: const Text('Settings'),
        ),
        const VerticalDivider(width: 4),
        // Add Widget
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.add),
          onPressed: !layoutLocked ? () => _displayAddWidgetDialog() : null,
          child: const Text('Add Widget'),
        ),
        if (layoutLocked) ...[
          const VerticalDivider(width: 4),
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

    Widget? updateButton;
    if (lastUpdateResponse.updateAvailable) {
      updateButton = IconButton(
        style: const ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
          maximumSize: WidgetStatePropertyAll(Size.square(34.0)),
          minimumSize: WidgetStatePropertyAll(Size.zero),
          padding: WidgetStatePropertyAll(EdgeInsets.all(4.0)),
          iconSize: WidgetStatePropertyAll(24.0),
        ),
        tooltip: 'Download version ${lastUpdateResponse.latestVersion}',
        onPressed: () async {
          Uri url = Uri.parse(Settings.releasesLink);

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        icon: const Icon(Icons.update, color: Colors.orange),
      );
    }

    final double nonConolidatedLeadingWidth = (layoutLocked) ? 409 : 369;
    final double consolidatedLeadingWidth = (layoutLocked) ? 330 : 290;

    return Scaffold(
      appBar: CustomAppBar(
        titleText: appTitle,
        onWindowClose: onWindowClose,
        leading: menuBar,
        leadingWidth: consolidateMenu
            ? consolidatedLeadingWidth
            : nonConolidatedLeadingWidth,
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
                    gridDpiOverride:
                        preferences.getDouble(PrefKeys.gridDpiOverride),
                    updateButton: updateButton,
                    currentIndex: _currentTabIndex,
                    onTabMoveLeft: _moveTabLeft,
                    onTabMoveRight: _moveTabRight,
                    onTabRename: (index, newData) =>
                        setState(() => _tabData[index] = newData),
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

                      TabData tabToRemove = _tabData[index];

                      _showTabCloseConfirmation(context, tabToRemove.name, () {
                        int indexToSwitch = _currentTabIndex;

                        if (indexToSwitch == _tabData.length - 1) {
                          indexToSwitch--;
                        }

                        tabToRemove.tabGrid.onDestroy();
                        tabToRemove.tabGrid.dispose();

                        setState(() => _tabData.remove(tabToRemove));
                        _switchToTab(indexToSwitch);
                      });
                    },
                    onTabChanged: _switchToTab,
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
                  if (_addWidgetDialogVisible)
                    _AddWidgetDialog(
                      ntConnection: widget.ntConnection,
                      preferences: widget.preferences,
                      grid: _tabData[_currentTabIndex].tabGrid,
                      gridIndex: _currentTabIndex,
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
                      onClose: () =>
                          setState(() => _addWidgetDialogVisible = false),
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
                child: ValueListenableBuilder(
                    valueListenable: widget.ntConnection.ntConnected,
                    builder: (context, connected, child) {
                      String connectedText = (connected)
                          ? 'Network Tables: Connected (${preferences.getString(PrefKeys.ipAddress) ?? Defaults.ipAddress})'
                          : 'Network Tables: Disconnected';

                      double connectedWidth = (TextPainter(
                              text: TextSpan(
                                text: connectedText,
                                style: footerStyle,
                              ),
                              maxLines: 1,
                              textDirection: TextDirection.ltr)
                            ..layout(minWidth: 0, maxWidth: double.infinity))
                          .size
                          .width;

                      double availableSpace = windowWidth - 20 - connectedWidth;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (availableSpace >= windowWidth / 2 + 30)
                            Text(
                              'Team ${preferences.getInt(PrefKeys.teamNumber)?.toString() ?? 'Unknown'}',
                              textAlign: TextAlign.center,
                            ),
                          if (availableSpace >= 115)
                            Align(
                              alignment: Alignment.centerRight,
                              child: StreamBuilder(
                                stream: widget.ntConnection.latencyStream(),
                                builder: (context, snapshot) {
                                  double latency = snapshot.data ?? 0.0;

                                  return Text(
                                    'Latency: ${latency.toStringAsFixed(2).padLeft(5)} ms',
                                    textAlign: TextAlign.right,
                                  );
                                },
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              connectedText,
                              style: footerStyle?.copyWith(
                                color: (connected) ? Colors.green : Colors.red,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      );
                    }),
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
  final TabGridModel grid;
  final int gridIndex;

  final void Function(Offset globalPosition, WidgetContainerModel widget)
      onNTDragUpdate;
  final void Function(WidgetContainerModel widget) onNTDragEnd;

  final void Function(Offset globalPosition, LayoutContainerModel widget)
      onLayoutDragUpdate;
  final void Function(LayoutContainerModel widget) onLayoutDragEnd;

  final void Function() onClose;

  const _AddWidgetDialog({
    required this.ntConnection,
    required this.preferences,
    required this.grid,
    required this.gridIndex,
    required this.onNTDragUpdate,
    required this.onNTDragEnd,
    required this.onLayoutDragUpdate,
    required this.onLayoutDragEnd,
    required this.onClose,
  });

  @override
  State<_AddWidgetDialog> createState() => _AddWidgetDialogState();
}

class _AddWidgetDialogState extends State<_AddWidgetDialog> {
  bool _hideMetadata = true;
  String _searchQuery = '';

  void onRemove(TabGridModel grid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      grid.removeDragInWidget();
    });
  }

  @override
  void didUpdateWidget(_AddWidgetDialog oldWidget) {
    if (widget.gridIndex != oldWidget.gridIndex ||
        widget.grid != oldWidget.grid) {
      onRemove(oldWidget.grid);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableDialog(
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
                        listLayoutBuilder: ({
                          required title,
                          required children,
                        }) {
                          return widget.grid.createListLayout(
                            title: title,
                            children: children,
                          );
                        },
                        hideMetadata: _hideMetadata,
                        gridIndex: widget.gridIndex,
                        onDragUpdate: widget.onNTDragUpdate,
                        onDragEnd: widget.onNTDragEnd,
                        onRemoveWidget: () => onRemove(widget.grid),
                      ),
                      ListView(
                        children: [
                          LayoutDragTile(
                            gridIndex: widget.gridIndex,
                            title: 'List Layout',
                            icon: Icons.table_rows,
                            layoutBuilder: () => widget.grid.createListLayout(),
                            onDragUpdate: widget.onLayoutDragUpdate,
                            onDragEnd: widget.onLayoutDragEnd,
                            onRemoveWidget: () => onRemove(widget.grid),
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
                          updateOnChanged: true,
                          label: 'Search',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onClose,
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
