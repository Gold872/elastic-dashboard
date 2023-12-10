import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/services/nt4_widget_builder.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';

class NetworkTableTreeRow {
  final String topic;
  final String rowName;

  final NT4Topic? nt4Topic;

  List<NetworkTableTreeRow> children = [];

  NetworkTableTreeRow(
      {required this.topic, required this.rowName, this.nt4Topic});

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

  NetworkTableTreeRow createNewRow(
      {required String topic, required String name, NT4Topic? nt4Topic}) {
    NetworkTableTreeRow newRow =
        NetworkTableTreeRow(topic: topic, rowName: name, nt4Topic: nt4Topic);
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

  static NT4Widget? getNT4WidgetFromTopic(NT4Topic nt4Topic) {
    switch (nt4Topic.type) {
      case NT4TypeStr.kFloat64:
      case NT4TypeStr.kInt:
      case NT4TypeStr.kFloat32:
      case NT4TypeStr.kBoolArr:
      case NT4TypeStr.kFloat64Arr:
      case NT4TypeStr.kFloat32Arr:
      case NT4TypeStr.kIntArr:
      case NT4TypeStr.kString:
      case NT4TypeStr.kStringArr:
        return TextDisplay(
          key: UniqueKey(),
          topic: nt4Topic.name,
        );
      case NT4TypeStr.kBool:
        return BooleanBox(
          key: UniqueKey(),
          topic: nt4Topic.name,
        );
    }
    return null;
  }

  Future<NT4Widget?>? getPrimaryWidget() async {
    if (nt4Topic == null) {
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

      // If it's a camera stream
      if (isCameraStream) {
        return CameraStreamWidget(key: UniqueKey(), topic: topic);
      }

      return null;
    }

    return getNT4WidgetFromTopic(nt4Topic!);
  }

  Future<String?> getTypeString(String typeTopic) async {
    return nt4Connection.subscribeAndRetrieveData(typeTopic);
  }

  Future<NT4Widget?>? getTypedWidget(String typeTopic) async {
    String? type = await getTypeString(typeTopic);

    if (type == null) {
      return null;
    }

    return NT4WidgetBuilder.buildNT4WidgetFromType(type, topic);
  }

  Future<WidgetContainer?> toWidgetContainer() async {
    NT4Widget? primary = await getPrimaryWidget();

    if (primary == null) {
      return null;
    }

    double width = NT4WidgetBuilder.getDefaultWidth(primary);
    double height = NT4WidgetBuilder.getDefaultHeight(primary);

    return WidgetContainer(
      title: rowName,
      width: width,
      height: height,
      child: primary,
    );
  }
}