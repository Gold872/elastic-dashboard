import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';
import 'package:transitioned_indexed_stack/transitioned_indexed_stack.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

/// Represents data for a tab.
class TabData {
  /// The name of the tab.
  String name;

  /// Creates a [TabData] with the given name.
  TabData({required this.name});
}

/// A widget that provides an editable tab bar with associated tab views.
///
/// Allows for creating, renaming, moving, and closing tabs.
class EditableTabBar extends StatelessWidget {
  /// The list of tab views to display.
  final List<TabGrid> tabViews;

  /// The list of data associated with each tab.
  final List<TabData> tabData;

  /// Callback function when a new tab is created.
  final Function(TabData tab) onTabCreate;

  /// Callback function when a tab is destroyed.
  final Function(int index) onTabDestroy;

  /// Callback function to move a tab to the left.
  final Function() onTabMoveLeft;

  /// Callback function to move a tab to the right.
  final Function() onTabMoveRight;

  /// Callback function when a tab is renamed.
  final Function(int index, TabData newData) onTabRename;

  /// Callback function when the current tab is changed.
  final Function(int index) onTabChanged;
  final Function(int index, TabData newData) onTabDuplicateTab;


  /// The index of the currently selected tab.
  final int currentIndex;

  /// Creates an [EditableTabBar] with the specified parameters.
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
    required this.onTabDuplicateTab,
  });

  /// Displays a dialog to rename the tab at the given [index].
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

  void duplicateTab(BuildContext context, int index) {
    String tabName = 'Tab ${tabData.length + 1}';
    TabData data = TabData(name: tabName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('name for duplicateTab Tab'),
          content: Container(
            constraints: const BoxConstraints(
              maxWidth: 200,
            ),
            child: DialogTextInput(
              onSubmit: (value) {
                data.name = value;
              },
              initialText: data.name,
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
    ).whenComplete(()=> (

      onTabDuplicateTab.call(index, data),

    ));


  }

  /// Creates a new tab with a default name.
  void createTab() {
    String tabName = 'Tab ${tabData.length + 1}';
    TabData data = TabData(name: tabName);

    onTabCreate.call(data);
  }

  /// Closes the tab at the given [index].
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
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      maximumSize: WidgetStatePropertyAll(Size.square(34.0)),
      minimumSize: WidgetStatePropertyAll(Size.zero),
      padding: WidgetStatePropertyAll(EdgeInsets.all(4.0)),
      iconSize: WidgetStatePropertyAll(24.0),
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
                      return GestureDetector(
                        onTap: () {
                          onTabChanged.call(index);
                        },
                        onSecondaryTapUp: (details) {
                          if (Settings.layoutLocked) {
                            return;
                          }
                          ContextMenu contextMenu = ContextMenu(
                            position: details.globalPosition,
                            borderRadius: BorderRadius.circular(5.0),
                            padding: const EdgeInsets.all(4.0),
                            entries: [
                              MenuHeader(
                                text: tabData[index].name,
                                disableUppercase: true,
                              ),
                              const MenuDivider(),
                              MenuItem(
                                label: 'Rename',
                                icon: Icons.drive_file_rename_outline_outlined,
                                onSelected: () => renameTab(context, index),
                              ),
                              MenuItem(
                                label: 'Duplicate',
                                icon: Icons.control_point_duplicate_sharp,
                                onSelected: () => duplicateTab(context, index),
                              ),
                              MenuItem(
                                label: 'Close',
                                icon: Icons.close,
                                onSelected: () => closeTab(index),
                              ),
                            ],
                          );

                          showContextMenu(
                            context,
                            contextMenu: contextMenu,
                            transitionDuration:
                                const Duration(milliseconds: 100),
                            reverseTransitionDuration: Duration.zero,
                            maintainState: true,
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          );
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
                                : theme.colorScheme.onPrimaryContainer
                                    .withAlpha(20),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10.0),
                              topRight: Radius.circular(10.0),
                            ),
                          ),
                          child: Center(
                            child: Row(
                              children: [
                                Text(
                                  tabData[index].name,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: (currentIndex == index)
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Visibility(
                                  visible: !Settings.layoutLocked,
                                  child: const SizedBox(width: 10),
                                ),
                                Visibility(
                                  visible: !Settings.layoutLocked,
                                  child: IconButton(
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
                                ),
                              ],
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
                      onPressed: (!Settings.layoutLocked)
                          ? () => onTabMoveLeft.call()
                          : null,
                      alignment: Alignment.center,
                      icon: const Icon(Icons.west),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed:
                          (!Settings.layoutLocked) ? () => createTab() : null,
                      alignment: Alignment.center,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed: (!Settings.layoutLocked)
                          ? () => onTabMoveRight.call()
                          : null,
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
        // Tab grid area
        Flexible(
          child: Stack(
            children: [
              Visibility(
                visible: Settings.snapToGrid,
                child: GridPaper(
                  color: const Color.fromARGB(50, 195, 232, 243),
                  interval: Settings.gridSize.toDouble(),
                  divisions: 1,
                  subdivisions: 1,
                  child: Container(),
                ),
              ),
              FadeIndexedStack(
                curve: Curves.decelerate,
                index: currentIndex,
                children: [
                  for (TabGrid grid in tabViews)
                    ChangeNotifierProvider(
                      create: (context) => TabGridModel(),
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
