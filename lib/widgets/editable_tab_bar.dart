import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:contextmenu/contextmenu.dart';
import 'package:provider/provider.dart';
import 'package:transitioned_indexed_stack/transitioned_indexed_stack.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';

class TabData {
  String name;

  TabData({required this.name});
}

class EditableTabBar extends StatelessWidget {
  final List<DashboardGrid> tabViews;
  final List<TabData> tabData;

  final Function(TabData tab) onTabCreate;
  final Function(int index) onTabDestroy;
  final Function() onTabMoveLeft;
  final Function() onTabMoveRight;
  final Function(int index, TabData newData) onTabRename;
  final Function(int index) onTabChanged;

  final int currentIndex;

  const EditableTabBar({
    super.key,
    required this.currentIndex,
    required this.tabData,
    required this.tabViews,
    required this.onTabCreate,
    required this.onTabDestroy,
    required this.onTabMoveLeft,
    required this.onTabMoveRight,
    required this.onTabRename,
    required this.onTabChanged,
  });

  void renameTab(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Tab'),
          content: Container(
            constraints: const BoxConstraints(
              maxWidth: 200,
            ),
            child: DialogTextInput(
              onSubmit: (value) {
                tabData[index].name = value;
                onTabRename.call(index, tabData[index]);
              },
              initialText: tabData[index].name,
              label: 'Name',
              formatter: LengthLimitingTextInputFormatter(50),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void createTab() {
    String tabName = 'Tab ${tabData.length + 1}';
    TabData data = TabData(name: tabName);

    onTabCreate.call(data);
  }

  void closeTab(int index) {
    if (tabData.length == 1) {
      return;
    }

    onTabDestroy.call(index);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ButtonStyle endButtonStyle = const ButtonStyle(
      shape: MaterialStatePropertyAll(RoundedRectangleBorder()),
      maximumSize: MaterialStatePropertyAll(Size.square(34.0)),
      minimumSize: MaterialStatePropertyAll(Size.zero),
      padding: MaterialStatePropertyAll(EdgeInsets.all(4.0)),
      iconSize: MaterialStatePropertyAll(24.0),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Tab bar
        ExcludeFocus(
          child: Container(
            width: double.infinity,
            height: 36,
            color: theme.colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: tabData.length,
                    itemBuilder: (context, index) {
                      return ContextMenuArea(
                        builder: (context) => [
                          ListTile(
                            enabled: false,
                            dense: true,
                            visualDensity: const VisualDensity(
                                horizontal: 0.0, vertical: -4.0),
                            title: Center(child: Text(tabData[index].name)),
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(
                                horizontal: 0.0, vertical: -4.0),
                            leading: const Icon(
                                Icons.drive_file_rename_outline_outlined),
                            title: const Text('Rename'),
                            onTap: () {
                              Navigator.of(context).pop();
                              renameTab(context, index);
                            },
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(
                                horizontal: 0.0, vertical: -4.0),
                            leading: const Icon(Icons.close),
                            title: const Text('Close'),
                            onTap: () {
                              Navigator.of(context).pop();
                              closeTab(index);
                            },
                          ),
                        ],
                        child: GestureDetector(
                          onTap: () {
                            onTabChanged.call(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutExpo,
                            margin: const EdgeInsets.only(
                                left: 5.0, right: 5.0, top: 5.0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 5.0),
                            decoration: BoxDecoration(
                              color: (currentIndex == index)
                                  ? theme.colorScheme.onPrimaryContainer
                                  : Colors.transparent,
                              borderRadius: (currentIndex == index)
                                  ? const BorderRadius.only(
                                      topLeft: Radius.circular(10.0),
                                      topRight: Radius.circular(10.0),
                                    )
                                  : BorderRadius.zero,
                            ),
                            child: Center(
                              child: Row(
                                children: [
                                  Text(
                                    tabData[index].name,
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: (currentIndex == index)
                                          ? theme.colorScheme.primaryContainer
                                          : theme
                                              .colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    onPressed: () {
                                      closeTab(index);
                                    },
                                    padding: const EdgeInsets.all(0.0),
                                    alignment: Alignment.center,
                                    constraints: const BoxConstraints(
                                      minWidth: 15.0,
                                      minHeight: 15.0,
                                    ),
                                    iconSize: 14,
                                    color: (currentIndex == index)
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.onPrimaryContainer,
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    IconButton(
                      style: endButtonStyle,
                      onPressed: () {
                        onTabMoveLeft.call();
                      },
                      alignment: Alignment.center,
                      icon: const Icon(Icons.west),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed: () {
                        createTab();
                      },
                      alignment: Alignment.center,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed: () {
                        onTabMoveRight.call();
                      },
                      alignment: Alignment.center,
                      icon: const Icon(Icons.east),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Dashboard grid area
        Flexible(
          child: Stack(
            children: [
              Visibility(
                visible: Settings.showGrid,
                child: GridPaper(
                  color: const Color.fromARGB(50, 195, 232, 243),
                  interval: Settings.gridSize.toDouble(),
                  divisions: 1,
                  subdivisions: 1,
                  child: Container(),
                ),
              ),
              FadeIndexedStack(
                beginOpacity: 0.0,
                endOpacity: 1.0,
                index: currentIndex,
                children: [
                  for (DashboardGrid grid in tabViews)
                    ChangeNotifierProvider(
                      create: (context) => DashboardGridModel(),
                      child: grid,
                    ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
}
