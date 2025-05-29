import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/yagsl_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';

class NetworkTableTreeRow {
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final String topic;
  final String rowName;

  final TreeTopicEntry? entry;

  List<NetworkTableTreeRow> children = [];

  NetworkTableTreeRow({
    required this.ntConnection,
    required this.preferences,
    required this.topic,
    required this.rowName,
    this.entry,
  });

  bool hasRow(String name) {
    for (NetworkTableTreeRow child in children) {
      if (child.rowName == name) {
        return true;
      }
    }
    return false;
  }

  bool hasRows(List<String> names) {
    for (String row in names) {
      if (!hasRow(row)) {
        return false;
      }
    }

    return true;
  }

  bool containsOnlyMetadata() {
    if (children.isEmpty) {
      return false;
    }

    return !children.any((row) => !row.rowName.startsWith('.'));
  }

  void addRow(NetworkTableTreeRow row) {
    if (hasRow(row.rowName)) {
      return;
    }

    children.add(row);
  }

  NetworkTableTreeRow getRow(String name) {
    for (NetworkTableTreeRow row in children) {
      if (row.rowName == name) {
        return row;
      }
    }

    throw Exception("Trying to retrieve a row that doesn't exist");
  }

  NetworkTableTreeRow createNewRow({
    required String topic,
    required String name,
    TreeTopicEntry? entry,
  }) {
    NetworkTableTreeRow newRow = NetworkTableTreeRow(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: topic,
      rowName: name,
      entry: entry,
    );
    addRow(newRow);

    return newRow;
  }

  void sort() {
    children.sort((a, b) {
      if (a.children.isNotEmpty && b.children.isEmpty) {
        return -1;
      } else if (a.children.isEmpty && b.children.isNotEmpty) {
        return 1;
      }

      return a.rowName.compareTo(b.rowName);
    });

    for (NetworkTableTreeRow child in children) {
      child.sort();
    }
  }

  void clearRows() {
    children.clear();
  }

  static SingleTopicNTWidgetModel? getNTWidgetFromTopic(
    NTConnection ntConnection,
    SharedPreferences preferences,
    TreeTopicEntry entry,
  ) {
    NT4Type checked = entry.type().nonNullable;

    logger.info(
      'meta: ${entry.meta}, name: ${entry.topic.name}, topic.type: ${entry.topic.type}',
    );

    if (checked.fragment == NT4TypeFragment.boolean) {
      return BooleanBoxModel(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: entry.topic.name,
        dataType: entry.type(),
        ntStructMeta: entry.meta,
      );
    } else if (checked.isViewable) {
      return TextDisplayModel(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: entry.topic.name,
        dataType: entry.type(),
        ntStructMeta: entry.meta,
      );
    }

    return null;
  }

  Future<NTWidgetModel?>? getPrimaryWidget() async {
    if (entry == null) {
      if (hasRow('.type')) {
        return await getTypedWidget('$topic/.type');
      }

      bool isCameraStream = hasRows([
            'mode',
            'modes',
            'source',
            'streams',
          ]) &&
          (hasRow('description') || hasRow('connected'));

      if (isCameraStream) {
        return CameraStreamModel(
            ntConnection: ntConnection, preferences: preferences, topic: topic);
      }

      if (hasRows([
        'desiredStates',
        'maxSpeed',
        'measuredStates',
        'robotRotation',
        'rotationUnit',
        'sizeFrontBack',
        'sizeLeftRight',
      ])) {
        return YAGSLSwerveDriveModel(
            ntConnection: ntConnection, preferences: preferences, topic: topic);
      }

      return null;
    }

    return getNTWidgetFromTopic(ntConnection, preferences, entry!);
  }

  Future<String?> getTypeString(String typeTopic) async {
    return ntConnection.subscribeAndRetrieveData(typeTopic,
        timeout: const Duration(milliseconds: 500));
  }

  Future<NTWidgetModel?>? getTypedWidget(String typeTopic) async {
    String? type = await getTypeString(typeTopic);

    if (type == null) {
      return null;
    }

    return NTWidgetBuilder.buildNTModelFromType(
      ntConnection,
      preferences,
      entry?.meta,
      type,
      topic,
    );
  }

  Future<List<NTWidgetContainerModel>?> getListLayoutChildren() async {
    Iterable<Future<WidgetContainerModel?>> childrenFutures = children
        .whereNot((e) => e.rowName.startsWith('.'))
        .map((e) => e.toWidgetContainerModel(resortToListLayout: false));

    Iterable<NTWidgetContainerModel> listChildren =
        (await Future.wait(childrenFutures)).whereType();

    if (listChildren.isEmpty) {
      return null;
    }

    return listChildren.toList();
  }

  Future<WidgetContainerModel?> toWidgetContainerModel({
    bool resortToListLayout = true,
    ListLayoutBuilder? listLayoutBuilder,
  }) async {
    NTWidgetModel? primary = await getPrimaryWidget();

    if (primary == null || !NTWidgetBuilder.isRegistered(primary.type)) {
      primary?.unSubscribe();
      primary?.disposeWidget(deleting: true);
      primary?.forceDispose();

      if (resortToListLayout && listLayoutBuilder != null) {
        List<NTWidgetContainerModel>? listLayoutChildren =
            await getListLayoutChildren();

        if (listLayoutChildren != null) {
          return listLayoutBuilder.call(
            title: rowName,
            children: listLayoutChildren,
          );
        }
      }
      return null;
    }

    NTWidget? widget = NTWidgetBuilder.buildNTWidgetFromModel(primary);

    if (widget == null) {
      primary.unSubscribe();
      primary.disposeWidget(deleting: true);
      primary.forceDispose();
      return null;
    }

    double width = NTWidgetBuilder.getDefaultWidth(primary);
    double height = NTWidgetBuilder.getDefaultHeight(primary);

    return NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.fromLTWH(0.0, 0.0, width, height),
      title: rowName,
      childModel: primary,
    );
  }

  Future<WidgetContainer?> toWidgetContainer() async {
    NTWidgetModel? primary = await getPrimaryWidget();
    if (primary == null) {
      return null;
    }
    NTWidget? widget = NTWidgetBuilder.buildNTWidgetFromModel(primary);

    if (widget == null) {
      primary.unSubscribe();
      primary.disposeWidget(deleting: true);
      primary.forceDispose();

      return null;
    }

    double width = NTWidgetBuilder.getDefaultWidth(primary);
    double height = NTWidgetBuilder.getDefaultHeight(primary);

    return WidgetContainer(
      title: rowName,
      width: width,
      height: height,
      cornerRadius:
          preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
      child: widget,
    );
  }
}
