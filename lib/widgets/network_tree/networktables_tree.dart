import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree_row.dart';

class NetworkTableTree extends StatefulWidget {
  final Function(Offset globalPosition, DraggableNTWidgetContainer widget)?
      onDragUpdate;
  final Function(DraggableNTWidgetContainer widget)? onDragEnd;
  final DraggableNTWidgetContainer? Function(WidgetContainer? widget)?
      widgetContainerBuilder;

  const NetworkTableTree(
      {super.key,
      this.onDragUpdate,
      this.onDragEnd,
      this.widgetContainerBuilder});

  @override
  State<NetworkTableTree> createState() => _NetworkTableTreeState();
}

class _NetworkTableTreeState extends State<NetworkTableTree> {
  final NetworkTableTreeRow root = NetworkTableTreeRow(topic: '/', rowName: '');
  late final TreeController<NetworkTableTreeRow> treeController;

  late final Function(Offset globalPosition, DraggableNTWidgetContainer widget)?
      onDragUpdate = widget.onDragUpdate;
  late final Function(DraggableNTWidgetContainer widget)? onDragEnd =
      widget.onDragEnd;
  late final DraggableNTWidgetContainer? Function(WidgetContainer? widget)?
      widgetContainerBuilder = widget.widgetContainerBuilder;

  late final Function(NT4Topic topic) onNewTopicAnnounced;

  @override
  void initState() {
    super.initState();

    treeController = TreeController<NetworkTableTreeRow>(
        roots: root.children, childrenProvider: (node) => node.children);

    ntConnection.nt4Client
        .addTopicAnnounceListener(onNewTopicAnnounced = (topic) {
      setState(() {
        treeController.rebuild();
      });
    });
  }

  @override
  void dispose() {
    ntConnection.nt4Client.removeTopicAnnounceListener(onNewTopicAnnounced);

    super.dispose();
  }

  void createRows(NT4Topic nt4Topic) {
    String topic = nt4Topic.name;

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

    for (NT4Topic topic in ntConnection.nt4Client.announcedTopics.values) {
      if (topic.name == 'Time') {
        continue;
      }

      topics.add(topic);
    }

    for (NT4Topic topic in topics) {
      createRows(topic);
    }

    root.sort();

    return TreeView<NetworkTableTreeRow>(
      treeController: treeController,
      nodeBuilder:
          (BuildContext context, TreeEntry<NetworkTableTreeRow> entry) {
        return TreeTile(
          key: UniqueKey(),
          entry: entry,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          widgetContainerBuilder: widgetContainerBuilder,
          onTap: () {
            setState(() => treeController.toggleExpansion(entry.node));
          },
        );
      },
    );
  }
}

class TreeTile extends StatelessWidget {
  TreeTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.widgetContainerBuilder,
  });

  final TreeEntry<NetworkTableTreeRow> entry;
  final VoidCallback onTap;
  final Function(Offset globalPosition, DraggableNTWidgetContainer widget)?
      onDragUpdate;
  final Function(DraggableNTWidgetContainer widget)? onDragEnd;
  final DraggableNTWidgetContainer? Function(WidgetContainer? widget)?
      widgetContainerBuilder;

  DraggableNTWidgetContainer? draggingWidget;

  @override
  Widget build(BuildContext context) {
    TextStyle trailingStyle =
        Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey);
    return Column(
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

              draggingWidget = widgetContainerBuilder
                  ?.call(await entry.node.toWidgetContainer());
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
                    leading: (entry.hasChildren)
                        ? FolderButton(
                            openedIcon: const Icon(Icons.arrow_drop_down),
                            closedIcon: const Icon(Icons.arrow_right),
                            iconSize: 24,
                            isOpen: entry.hasChildren ? entry.isExpanded : null,
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
    );
  }
}
