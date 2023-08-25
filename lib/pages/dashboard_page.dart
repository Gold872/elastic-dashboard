import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/network_table_tree.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class DashboardPage extends StatefulWidget {
  final Stream<dynamic> connectionStream;
  final SharedPreferences preferences;
  final Function(Color color)? onColorChanged;

  const DashboardPage({
    super.key,
    required this.connectionStream,
    required this.preferences,
    this.onColorChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final SharedPreferences _preferences;

  final List<DashboardGrid> grids = [];

  final List<TabData> tabData = [];

  int currentTabIndex = 0;

  bool addWidgetDialogVisible = false;

  @override
  void initState() {
    super.initState();

    _preferences = widget.preferences;

    loadLayout();

    if (tabData.isEmpty) {
      tabData.addAll([
        TabData(name: 'Teleoperated'),
        TabData(name: 'Autonomous'),
      ]);

      grids.addAll([
        DashboardGrid(key: GlobalKey(), jsonData: const {}),
        DashboardGrid(key: GlobalKey(), jsonData: const {}),
      ]);
    }

    nt4Connection.addConnectedListener(() {
      setState(() {
        for (DashboardGrid grid in grids) {
          grid.onNTConnect();
        }
      });
    });

    nt4Connection.addDisconnectedListener(() {
      setState(() {
        for (DashboardGrid grid in grids) {
          grid.onNTDisconnect();
        }
      });
    });
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> gridData = [];

    for (int i = 0; i < tabData.length; i++) {
      TabData data = tabData[i];
      DashboardGrid grid = grids[i];

      gridData.add({
        'name': data.name,
        'grid_layout': grid.toJson(),
      });
    }

    return {
      'tabs': gridData,
    };
  }

  Future<void> saveLayout() async {
    Map<String, dynamic> jsonData = toJson();

    SnackBar savedMessage = SnackBar(
      content: const Text('Layout Saved Successfully!'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      width: 500,
      showCloseIcon: true,
    );

    ScaffoldMessengerState messengerState = ScaffoldMessenger.of(context);

    await _preferences.setString(PrefKeys.layout, jsonEncode(jsonData));

    messengerState.showSnackBar(savedMessage);
  }

  void exportLayout() async {
    String initialDirectory = (await getApplicationDocumentsDirectory()).path;

    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Json File',
      extensions: ['json'],
    );

    final FileSaveLocation? saveLocation = await getSaveLocation(
      initialDirectory: initialDirectory,
      suggestedName: 'elastic-layout.json',
      acceptedTypeGroups: [typeGroup],
    );

    if (saveLocation == null) {
      return;
    }

    Map<String, dynamic> jsonData = toJson();
    String jsonString = jsonEncode(jsonData);

    final Uint8List fileData = Uint8List.fromList(jsonString.codeUnits);
    const String mimeType = 'application/json';

    final XFile jsonFile = XFile.fromData(fileData,
        mimeType: mimeType, name: 'elastic-layout.json');

    jsonFile.saveTo(saveLocation.path);
  }

  void importLayout() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Json File',
      extensions: ['json'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) {
      return;
    }

    String jsonString = await file.readAsString();

    await _preferences.setString(PrefKeys.layout, jsonString);

    setState(() => loadLayoutFromJsonData(jsonString));
  }

  void loadLayout() async {
    String? jsonString = _preferences.getString(PrefKeys.layout);

    if (jsonString == null) {
      return;
    }

    setState(() {
      loadLayoutFromJsonData(jsonString);
    });
  }

  void loadLayoutFromJsonData(String jsonString) {
    tabData.clear();
    grids.clear();

    Map<String, dynamic> jsonData = jsonDecode(jsonString);
    for (Map<String, dynamic> data in jsonData['tabs']) {
      tabData.add(TabData(name: data['name']));

      grids.add(DashboardGrid.fromJson(
          key: GlobalKey(),
          jsonData: data['grid_layout'],
          onAddWidgetPressed: displayAddWidgetDialog));
    }
  }

  void displayAddWidgetDialog() {
    setState(() => addWidgetDialogVisible = true);
  }

  void displayAboutDialog(BuildContext context) {
    IconThemeData iconTheme = IconTheme.of(context);
    showAboutDialog(
      context: context,
      applicationName: 'Elastic',
      applicationVersion: Globals.version,
      applicationIcon: Image.asset(
        'assets/logos/logo.png',
        width: iconTheme.size,
        height: iconTheme.size,
      ),
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: const Text(
            'Elastic was created by Team 353, the POBots in the summer of 2023. The motivation was to provide teams an alternative to WPILib\'s Shuffleboard dashboard.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: const Text(
            'The goal of Elastic is to have the essential features of Shuffleboard, but with a more elegant and modern display, and offer more customizability and performance.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: const Text(
            'Elastic is an ongoing project, if you have any ideas, feedback, or found any bugs, feel free to share them on the Github page!\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          child: const Text(
            'Elastic was built with some inspiration from Michael Jansen\'s projects and his Dart NT4 library, along with significant help from Jason and Peter from WPILib.',
          ),
        ),
      ],
    );
  }

  void displaySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
          preferences: widget.preferences,
          onTeamNumberChanged: (String? data) async {
            if (data == null) {
              return;
            }

            int? newTeamNumber = int.tryParse(data);

            if (newTeamNumber == null) {
              return;
            }

            await _preferences.setInt(PrefKeys.teamNumber, newTeamNumber);

            if (nt4Connection.isDSConnected) {
              setState(() {});
              return;
            }

            bool determineAddressFromTeamNumber =
                _preferences.getBool(PrefKeys.useTeamNumberForIP) ?? true;

            if (determineAddressFromTeamNumber) {
              _updateIPAddress(newIPAddress: data);
            }
          },
          onUseTeamNumberToggle: (value) async {
            await _preferences.setBool(PrefKeys.useTeamNumberForIP, value);

            if (nt4Connection.isDSConnected) {
              return;
            }

            if (value) {
              _updateIPAddress();
            }
          },
          onIPAddressChanged: (String? data) async {
            if (data == null) {
              return;
            }

            if (nt4Connection.isDSConnected) {
              return;
            }

            _updateIPAddress(newIPAddress: data);
          },
          onGridToggle: (value) async {
            setState(() {
              Globals.showGrid = value;
            });

            await _preferences.setBool(PrefKeys.showGrid, value);
          },
          onGridSizeChanged: (gridSize) async {
            if (gridSize == null) {
              return;
            }

            int? newGridSize = int.tryParse(gridSize);

            if (newGridSize == null) {
              return;
            }

            setState(() => Globals.gridSize = newGridSize);

            await _preferences.setInt(PrefKeys.gridSize, newGridSize);
          },
          onColorChanged: widget.onColorChanged),
    );
  }

  void _updateIPAddress({String? newIPAddress}) async {
    String ipAddress =
        _preferences.getString(PrefKeys.ipAddress) ?? '127.0.0.1';

    if (newIPAddress != null) {
      bool isTeamNumber = IPAddressUtil.isTeamNumber(newIPAddress);

      if (isTeamNumber) {
        ipAddress = IPAddressUtil.teamNumberToIP(int.parse(newIPAddress));
      } else {
        ipAddress = newIPAddress;
      }
    } else {
      int? teamNumber = _preferences.getInt(PrefKeys.teamNumber);

      if (teamNumber != null) {
        ipAddress = IPAddressUtil.teamNumberToIP(teamNumber);
      }
    }

    await _preferences.setString(PrefKeys.ipAddress, ipAddress);

    nt4Connection.changeIPAddress(ipAddress);

    setState(() {});
  }

  void showCloseConfirmation(BuildContext context) {
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
              await saveLayout();

              await windowManager.close();
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () async {
              await windowManager.close();
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

  @override
  Widget build(BuildContext context) {
    TextStyle? menuStyle = Theme.of(context).textTheme.bodySmall;
    TextStyle? footerStyle = Theme.of(context).textTheme.bodyMedium;
    ButtonStyle buttonStyle =
        ButtonStyle(textStyle: MaterialStateProperty.all(menuStyle));

    MenuBar menuBar = MenuBar(
      children: [
        // File
        SubmenuButton(
          style: buttonStyle,
          menuChildren: [
            // Open Layout
            MenuItemButton(
              style: buttonStyle,
              onPressed: () {
                importLayout();
              },
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyO, control: true),
              child: const Text(
                'Open Layout',
              ),
            ),
            // Save
            MenuItemButton(
              style: buttonStyle,
              onPressed: () {
                saveLayout();
              },
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyS, control: true),
              child: const Text(
                'Save',
              ),
            ),
            // Export layout
            MenuItemButton(
              style: buttonStyle,
              onPressed: () {
                exportLayout();
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
            style: buttonStyle,
            menuChildren: [
              // Clear layout
              MenuItemButton(
                style: buttonStyle,
                onPressed: () {
                  setState(() {
                    grids[currentTabIndex].clearWidgets();
                  });
                },
                child: const Text('Clear Layout'),
              ),
              // Add widget
              MenuItemButton(
                style: buttonStyle,
                onPressed: () {
                  setState(() {
                    displayAddWidgetDialog();
                  });
                },
                child: const Text('Add Widget'),
              ),
            ],
            child: const Text(
              'Edit',
            )),
        // Help
        SubmenuButton(
          style: buttonStyle,
          menuChildren: [
            MenuItemButton(
              style: buttonStyle,
              onPressed: () {
                displayAboutDialog(context);
              },
              child: const Text(
                'About',
              ),
            ),
          ],
          child: const Text(
            'Help',
          ),
        ),
        // Settings
        MenuItemButton(
          onPressed: () {
            displaySettingsDialog(context);
          },
          child: const Icon(Icons.settings),
        ),
      ],
    );

    return Scaffold(
      appBar: CustomAppBar(
        onWindowClose: () async {
          Map<String, dynamic> savedJson =
              jsonDecode(_preferences.getString(PrefKeys.layout) ?? '{}');
          Map<String, dynamic> currentJson = toJson();

          bool showConfirmation =
              !const DeepCollectionEquality().equals(savedJson, currentJson);

          if (showConfirmation) {
            showCloseConfirmation(context);
          } else {
            await windowManager.close();
          }
        },
        menuBar: menuBar,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: displayAddWidgetDialog,
        label: const Text('Add Widget'),
        icon: const Icon(Icons.add),
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyO, control: true):
              importLayout,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              saveLayout,
          const SingleActivator(LogicalKeyboardKey.keyS,
              shift: true, control: true): exportLayout,
          for (int i = 1; i <= 9; i++)
            SingleActivator(LogicalKeyboardKey(48 + i), control: true): () {
              if (i - 1 < tabData.length) {
                setState(() => currentTabIndex = i - 1);
              }
            },
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main dashboard page
              Expanded(
                child: Stack(
                  children: [
                    // Image.asset(
                    //   "assets/first-background.png",
                    //   width: MediaQuery.of(context).size.width,
                    //   height: MediaQuery.of(context).size.height,
                    //   fit: BoxFit.cover,
                    // ),
                    EditableTabBar(
                      currentIndex: currentTabIndex,
                      onTabRename: (index, newData) {
                        setState(() {
                          tabData[index] = newData;
                        });
                      },
                      onTabCreate: (tab, grid) {
                        setState(() {
                          tabData.add(tab);
                          grids.add(grid);
                        });
                      },
                      onTabDestroy: (tab, grid) {
                        if (currentTabIndex == tabData.length) {
                          currentTabIndex--;
                        }
                        setState(() {
                          tabData.remove(tab);
                          grids.remove(grid);
                        });
                      },
                      onTabChanged: (index) {
                        setState(() => currentTabIndex = index);
                      },
                      tabData: tabData,
                      tabViews: grids,
                    ),
                    AddWidgetDialog(
                      visible: addWidgetDialogVisible,
                      onDragUpdate: (globalPosition, widget) {
                        grids[currentTabIndex]
                            .addDragInWidget(widget, globalPosition);
                      },
                      onDragEnd: (widget) {
                        grids[currentTabIndex].placeDragInWidget(widget);
                      },
                      onClose: () {
                        setState(() => addWidgetDialogVisible = false);
                      },
                    ),
                  ],
                ),
              ),
              // Bottom bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: SizedBox(
                  height: 32,
                  child: StreamBuilder(
                    stream: widget.connectionStream,
                    builder: (context, snapshot) {
                      bool connected = snapshot.data ?? false;

                      Widget connectedText = (connected)
                          ? Text(
                              'Network Tables: Connected (${_preferences.getString(PrefKeys.ipAddress)})',
                              style: footerStyle!.copyWith(
                                color: Colors.green,
                              ))
                          : Text('Network Tables: Disconnected',
                              style: footerStyle!.copyWith(
                                color: Colors.red,
                              ));

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          connectedText,
                          Text(
                            'Team ${_preferences.getInt(PrefKeys.teamNumber)?.toString() ?? 'Unknown'}',
                          ),
                          Opacity(opacity: 0.0, child: connectedText),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddWidgetDialog extends StatelessWidget {
  final bool visible;
  final Function(Offset globalPosition, WidgetContainer widget)? onDragUpdate;
  final Function(WidgetContainer widget)? onDragEnd;

  final Function()? onClose;

  const AddWidgetDialog({
    super.key,
    required this.visible,
    this.onDragUpdate,
    this.onDragEnd,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
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
            child: Column(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(height: 10),
                Text('Add Widget',
                    style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                Expanded(
                  child: NetworkTableTree(
                    onDragUpdate: onDragUpdate,
                    onDragEnd: onDragEnd,
                  ),
                ),
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        onClose?.call();
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
    );
  }
}
