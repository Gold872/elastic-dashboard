import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/list_layout_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree_row.dart';

typedef ListLayoutBuilder = ListLayoutModel Function({
  required String title,
  required List<NTWidgetContainerModel> children,
});

class NetworkTableTree extends StatefulWidget {
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final ListLayoutBuilder? listLayoutBuilder;

  final Function(Offset globalPosition, WidgetContainerModel widget)?
      onDragUpdate;
  final Function(WidgetContainerModel widget)? onDragEnd;
  final String searchQuery;
  final bool hideMetadata;

  const NetworkTableTree({
    super.key,
    required this.ntConnection,
    required this.preferences,
    this.listLayoutBuilder,
    required this.hideMetadata,
    this.onDragUpdate,
    this.onDragEnd,
    this.searchQuery = '',
  });

  @override
  State<NetworkTableTree> createState() => _NetworkTableTreeState();
}

class _NetworkTableTreeState extends State<NetworkTableTree> {
  late final NetworkTableTreeRow root = NetworkTableTreeRow(
      ntConnection: widget.ntConnection,
      preferences: widget.preferences,
      topic: '/',
      rowName: '');
  late final TreeController<NetworkTableTreeRow> treeController;

  late final Function(Offset globalPosition, WidgetContainerModel widget)?
      onDragUpdate = widget.onDragUpdate;
  late final Function(WidgetContainerModel widget)? onDragEnd =
      widget.onDragEnd;

  late final Function(NT4Topic topic) onNewTopicAnnounced;

  @override
  void initState() {
    super.initState();

    treeController = TreeController<NetworkTableTreeRow>(
      roots: root.children,
      childrenProvider: (node) {
        List<NetworkTableTreeRow> nodes = node.children;

        // Apply the filter to the children
        List<NetworkTableTreeRow> filteredChildren = _filterChildren(nodes);

        // If there are any filtered children, include the parent node
        if (filteredChildren.isNotEmpty || _matchesFilter(node)) {
          if (widget.hideMetadata) {
            return filteredChildren
                .whereNot((element) => element.rowName.startsWith('.'))
                .toList();
          } else {
            return filteredChildren;
          }
        } else {
          return [];
        }
      },
    );

    widget.ntConnection.addTopicAnnounceListener(onNewTopicAnnounced = (topic) {
      setState(() {
        treeController.roots = _filterChildren(root.children);
        treeController.rebuild();
      });
    });
  }

  List<NetworkTableTreeRow> _filterChildren(
      List<NetworkTableTreeRow> children) {
    // Apply the filter to each child
    return children.where((child) {
      if (_matchesFilter(child)) {
        return true;
      }
      // Recursively check if any descendant matches the filter
      return _filterChildren(child.children).isNotEmpty;
    }).toList();
  }

  bool _matchesFilter(NetworkTableTreeRow node) {
    // Don't filter if there isn't a search
    if (widget.searchQuery.isEmpty) {
      return true;
    }
    // Check if the node matches the filter
    return node.topic.toLowerCase().contains(widget.searchQuery.toLowerCase());
  }

  @override
  void dispose() {
    widget.ntConnection.removeTopicAnnounceListener(onNewTopicAnnounced);

    super.dispose();
  }

  @override
  void didUpdateWidget(NetworkTableTree oldWidget) {
    if (widget.hideMetadata != oldWidget.hideMetadata ||
        widget.searchQuery != oldWidget.searchQuery) {
      treeController.roots = _filterChildren(root.children);
      treeController.rebuild();
    }
    super.didUpdateWidget(oldWidget);
  }

  void createRows(NT4Topic nt4Topic) {
    String topic = nt4Topic.name;
    if (!topic.startsWith('/')) {
      topic = '/$topic';
    }

    List<String> rows = topic.substring(1).split('/');
    NetworkTableTreeRow? current;
    String currentTopic = '';

    for (String row in rows) {
      currentTopic += '/$row';

      bool lastElement = currentTopic == topic;

      if (current != null) {
        if (current.hasRow(row)) {
          current = current.getRow(row);
        } else {
          current = current.createNewRow(
              topic: currentTopic,
              name: row,
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      } else {
        if (root.hasRow(row)) {
          current = root.getRow(row);
        } else {
          current = root.createNewRow(
              topic: currentTopic,
              name: row,
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<NT4Topic> topics = [];

    for (NT4Topic topic in widget.ntConnection.announcedTopics().values) {
      if (topic.name == 'Time') {
        continue;
      }

      topics.add(topic);
    }

    for (NT4Topic topic in topics) {
      createRows(topic);
    }

    root.sort();

    treeController.roots = _filterChildren(root.children);

    return TreeView<NetworkTableTreeRow>(
      treeController: treeController,
      nodeBuilder:
          (BuildContext context, TreeEntry<NetworkTableTreeRow> entry) {
        return TreeTile(
          key: UniqueKey(),
          preferences: widget.preferences,
          entry: entry,
          listLayoutBuilder: widget.listLayoutBuilder,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          onTap: () {
            if (widget.hideMetadata && entry.node.containsOnlyMetadata()) {
              return;
            }
            setState(() => treeController.toggleExpansion(entry.node));
          },
        );
      },
    );
  }
}

class TreeTile extends StatelessWidget {
  final SharedPreferences preferences;
  final TreeEntry<NetworkTableTreeRow> entry;
  final VoidCallback onTap;

  final ListLayoutBuilder? listLayoutBuilder;

  final Function(Offset globalPosition, WidgetContainerModel widget)?
      onDragUpdate;
  final Function(WidgetContainerModel widget)? onDragEnd;

  WidgetContainerModel? draggingWidget;

  TreeTile({
    super.key,
    required this.preferences,
    required this.entry,
    required this.onTap,
    this.listLayoutBuilder,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle trailingStyle =
        Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey);
    // I have absolutely no idea why Material is needed, but otherwise the tiles start bleeding all over the place, it makes zero sense
    return Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: GestureDetector(
              supportedDevices: PointerDeviceKind.values
                  .whereNot((element) => element == PointerDeviceKind.trackpad)
                  .toSet(),
              onPanStart: (details) async {
                if (draggingWidget != null) {
                  return;
                }

                draggingWidget = await entry.node.toWidgetContainerModel(
                    listLayoutBuilder: listLayoutBuilder);
              },
              onPanUpdate: (details) {
                if (draggingWidget == null) {
                  return;
                }

                draggingWidget!.cursorGlobalLocation = details.globalPosition;

                Offset position = details.globalPosition -
                    Offset(
                          draggingWidget!.displayRect.width,
                          draggingWidget!.displayRect.height,
                        ) /
                        2;

                onDragUpdate?.call(position, draggingWidget!);
              },
              onPanEnd: (details) {
                if (draggingWidget == null) {
                  return;
                }

                onDragEnd?.call(draggingWidget!);

                draggingWidget = null;
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: entry.level * 16.0),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(right: 20.0),
                      leading: (entry.hasChildren ||
                              entry.node.containsOnlyMetadata())
                          ? FolderButton(
                              openedIcon: const Icon(Icons.arrow_drop_down),
                              closedIcon: const Icon(Icons.arrow_right),
                              iconSize: 24,
                              isOpen: entry.hasChildren && entry.isExpanded,
                              onPressed: entry.hasChildren ? onTap : null,
                            )
                          : const SizedBox(width: 8.0),
                      title: Text(entry.node.rowName),
                      trailing: (entry.node.ntTopic != null)
                          ? Text(entry.node.ntTopic!.type, style: trailingStyle)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 0),
        ],
      ),
    );
  }
}
