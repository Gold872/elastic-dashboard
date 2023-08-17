import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';
import 'package:flutter/material.dart';

class TreeRow {
  final String topic;
  final String rowName;

  final NT4Topic? nt4Topic;

  List<TreeRow> children = [];

  TreeRow({required this.topic, required this.rowName, this.nt4Topic});

  bool hasRow(String name) {
    for (TreeRow child in children) {
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

  void addRow(TreeRow row) {
    if (hasRow(row.rowName)) {
      return;
    }

    children.add(row);
  }

  TreeRow getRow(String name) {
    for (TreeRow row in children) {
      if (row.rowName == name) {
        return row;
      }
    }

    throw Exception("Trying to retrieve a row that doesn't exist");
  }

  TreeRow createNewRow(
      {required String topic, required String name, NT4Topic? nt4Topic}) {
    TreeRow newRow = TreeRow(topic: topic, rowName: name, nt4Topic: nt4Topic);
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

    for (TreeRow child in children) {
      child.sort();
    }
  }

  Future<NT4Widget?>? getPrimaryWidget() async {
    if (nt4Topic == null) {
      if (hasRow('.type')) {
        return await getTypedWidget('$topic/.type');
      }

      // If it's a camera stream
      if (hasRows([
        'Property',
        'PropertyInfo',
        'RawProperty',
        'RawPropertyInfo',
        'connected',
        'description',
        'mode',
        'modes',
        'source',
        'streams',
      ])) {
        return CameraStreamWidget(key: UniqueKey(), topic: topic);
      }

      return null;
    }

    switch (nt4Topic!.type) {
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
          topic: nt4Topic!.name,
        );
      case NT4TypeStr.kBool:
        return BooleanBox(
          key: UniqueKey(),
          topic: nt4Topic!.name,
        );
    }
    return null;
  }

  Future<String?> getTypeString(String typeTopic) async {
    NT4Subscription typeSubscription = nt4Connection.subscribe(typeTopic);

    Object? type;
    try {
      type = await typeSubscription
          .periodicStream()
          .firstWhere((element) => element != null && element is String)
          .timeout(const Duration(seconds: 2, milliseconds: 500));
    } catch (e) {
      type = null;
    }

    nt4Connection.unSubscribe(typeSubscription);

    return type as String?;
  }

  Future<NT4Widget?>? getTypedWidget(String typeTopic) async {
    String? type = await getTypeString(typeTopic);

    if (type == null) {
      return null;
    }

    switch (type) {
      case 'Gyro':
        return Gyro(key: UniqueKey(), topic: topic);
      case 'Field2d':
        return FieldWidget(key: UniqueKey(), topic: topic);
      case 'PowerDistribution':
        return PowerDistribution(key: UniqueKey(), topic: topic);
      case 'PIDController':
        return PIDControllerWidget(key: UniqueKey(), topic: topic);
      case 'String Chooser':
        return ComboBoxChooser(key: UniqueKey(), topic: topic);
      case 'FMSInfo':
        return FMSInfo(key: UniqueKey(), topic: topic);
    }

    return null;
  }

  Future<WidgetContainer?> toWidgetContainer() async {
    NT4Widget? primary = await getPrimaryWidget();

    if (primary == null) {
      return null;
    }

    double normalGridSize = DraggableWidgetContainer.snapToGrid(128);

    double width = normalGridSize;
    double height = normalGridSize;

    if (primary is Gyro) {
      width = normalGridSize * 2;
      height = normalGridSize * 2;
    } else if (primary is FieldWidget) {
      width = normalGridSize * 3;
      height = normalGridSize * 2;
    } else if (primary is PowerDistribution) {
      width = normalGridSize * 3;
      height = normalGridSize * 4;
    } else if (primary is PIDControllerWidget) {
      width = normalGridSize * 2;
      height = normalGridSize * 3;
    } else if (primary is FMSInfo) {
      width = normalGridSize * 3;
    }

    return WidgetContainer(
      title: rowName,
      width: width,
      height: height,
      child: primary,
    );
  }
}
