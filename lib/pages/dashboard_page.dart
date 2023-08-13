import 'dart:convert';

import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/network_table_tree.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  final SharedPreferences preferences;

  const DashboardPage({super.key, required this.preferences});

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

    NT4Connection.addConnectedListener(() {
      setState(() {
        for (DashboardGrid grid in grids) {
          grid.onNTConnect();
        }
      });
    });

    NT4Connection.addDisconnectedListener(() {
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

  void saveLayout() async {
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

    await _preferences.setString('layout', jsonEncode(jsonData));

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

    await _preferences.setString('layout', jsonString);

    setState(() => loadLayoutFromJsonData(jsonString));
  }

  void loadLayout() async {
    String? jsonString = _preferences.getString('layout');

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
              // Show Grid
              MenuItemButton(
                style: buttonStyle,
                onPressed: () {
                  setState(() {
                    Globals.showGrid = !Globals.showGrid;

                    _preferences.setBool('show_grid', Globals.showGrid);
                  });
                },
                child: const Text('Toggle Grid'),
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
      ],
    );

    return Scaffold(
      appBar: CustomAppBar(menuBar: menuBar),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder(
                        stream: NT4Connection.connectionStatus(),
                        builder: (context, snapshot) {
                          bool connected = snapshot.data ?? false;

                          if (connected) {
                            return Text('Network Tables: Connected',
                                style: footerStyle!.copyWith(
                                  color: Colors.green,
                                ));
                          } else {
                            return Text('Network Tables: Disconnected',
                                style: footerStyle!.copyWith(
                                  color: Colors.red,
                                ));
                          }
                        },
                      ),
                    ],
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
