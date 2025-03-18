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

  final int gridIndex;

  final void Function(Offset globalPosition, WidgetContainerModel widget)?
      onDragUpdate;
  final void Function(WidgetContainerModel widget)? onDragEnd;
  final void Function()? onRemoveWidget;
  final String searchQuery;
  final bool hideMetadata;

  const NetworkTableTree({
    super.key,
    required this.ntConnection,
    required this.preferences,
    this.listLayoutBuilder,
    required this.hideMetadata,
    this.gridIndex = 0,
    this.onDragUpdate,
    this.onDragEnd,
    this.onRemoveWidget,
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
    rowName: '',
  );
  late final TreeController<NetworkTableTreeRow> treeController;

  void onTopicAnnounced(NT4Topic topic) {
    treeController.roots = _filterChildren(root.children);
    if (mounted) {
      setState(() {});
    }
  }

  void onTopicUnannounced(NT4Topic topic) {
    root.clearRows();
    if (mounted) {
      setState(() {});
    }
  }

  void onConnected() {
    root.clearRows();
    if (mounted) {
      setState(() {});
    }
  }

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

    widget.ntConnection.addTopicAnnounceListener(onTopicAnnounced);
    widget.ntConnection.addTopicUnannounceListener(onTopicUnannounced);
    widget.ntConnection.addConnectedListener(onConnected);
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
    widget.ntConnection.removeTopicAnnounceListener(onTopicAnnounced);
    widget.ntConnection.removeTopicUnannounceListener(onTopicUnannounced);
    widget.ntConnection.removeConnectedListener(onConnected);

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
    bool hasLeading = topic.startsWith('/');
    if (!hasLeading) {
      topic = '/$topic';
    }

    List<String> rows = topic.substring(1).split('/');
    NetworkTableTreeRow? current;
    String currentTopic = '';

    for (String row in rows) {
      currentTopic += '/$row';

      String effectiveTopic =
          hasLeading ? currentTopic : currentTopic.substring(1);

      bool lastElement = currentTopic == topic;

      if (current != null) {
        if (current.hasRow(row)) {
          current = current.getRow(row);
        } else {
          current = current.createNewRow(
              topic: effectiveTopic,
              name: row,
              ntTopic: (lastElement) ? nt4Topic : null);
        }
      } else {
        if (root.hasRow(row)) {
          current = root.getRow(row);
        } else {
          current = root.createNewRow(
              topic: effectiveTopic,
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
          gridIndex: widget.gridIndex,
          preferences: widget.preferences,
          entry: entry,
          listLayoutBuilder: widget.listLayoutBuilder,
          onDragUpdate: widget.onDragUpdate,
          onDragEnd: widget.onDragEnd,
          onRemoveWidget: widget.onRemoveWidget,
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

class TreeTile extends StatefulWidget {
  final int gridIndex;

  final SharedPreferences preferences;
  final TreeEntry<NetworkTableTreeRow> entry;
  final VoidCallback onTap;

  final ListLayoutBuilder? listLayoutBuilder;

  final void Function(Offset globalPosition, WidgetContainerModel widget)?
      onDragUpdate;
  final void Function(WidgetContainerModel widget)? onDragEnd;
  final void Function()? onRemoveWidget;

  const TreeTile({
    super.key,
    required this.gridIndex,
    required this.preferences,
    required this.entry,
    required this.onTap,
    this.listLayoutBuilder,
    this.onDragUpdate,
    this.onDragEnd,
    this.onRemoveWidget,
  });

  @override
  State<TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<TreeTile> {
  WidgetContainerModel? draggingWidget;
  bool dragging = false;

  void cancelDrag() {
    if (draggingWidget != null) {
      draggingWidget!.unSubscribe();
      draggingWidget!.disposeModel(deleting: true);
      draggingWidget!.forceDispose();

      widget.onRemoveWidget?.call();

      draggingWidget = null;
    }
    dragging = false;
  }

  @override
  void didUpdateWidget(TreeTile oldWidget) {
    if (widget.gridIndex != oldWidget.gridIndex) {
      cancelDrag();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    cancelDrag();

    super.dispose();
  }

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
            onTap: widget.onTap,
            child: GestureDetector(
              supportedDevices: PointerDeviceKind.values
                  .whereNot((element) => element == PointerDeviceKind.trackpad)
                  .toSet(),
              onPanStart: (details) async {
                if (draggingWidget != null) {
                  return;
                }
                dragging = true;

                draggingWidget = await widget.entry.node.toWidgetContainerModel(
                    listLayoutBuilder: widget.listLayoutBuilder);
                if (!dragging) {
                  draggingWidget?.unSubscribe();
                  draggingWidget?.disposeModel(deleting: true);
                  draggingWidget?.forceDispose();

                  draggingWidget = null;
                }
              },
              onPanUpdate: (details) {
                if (draggingWidget == null) {
                  return;
                }

                draggingWidget!.cursorGlobalLocation = details.globalPosition;

                widget.onDragUpdate?.call(
                  details.globalPosition,
                  draggingWidget!,
                );
              },
              onPanEnd: (details) {
                if (draggingWidget == null) {
                  dragging = false;
                  return;
                }

                widget.onDragEnd?.call(draggingWidget!);

                draggingWidget = null;

                dragging = false;
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                    start: widget.entry.level * 16.0),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(right: 20.0),
                      leading: (widget.entry.hasChildren ||
                              widget.entry.node.containsOnlyMetadata())
                          ? FolderButton(
                              openedIcon: const Icon(Icons.arrow_drop_down),
                              closedIcon: const Icon(Icons.arrow_right),
                              iconSize: 24,
                              isOpen: widget.entry.hasChildren &&
                                  widget.entry.isExpanded,
                              onPressed: widget.entry.hasChildren
                                  ? widget.onTap
                                  : null,
                            )
                          : const SizedBox(width: 8.0),
                      title: Text(widget.entry.node.rowName),
                      trailing: (widget.entry.node.ntTopic != null)
                          ? Text(widget.entry.node.ntTopic!.type,
                              style: trailingStyle)
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
