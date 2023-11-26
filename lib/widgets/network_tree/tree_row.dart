import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/differential_drive.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/network_alerts.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/three_axis_accelerometer.dart';
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

    switch (type) {
      case 'Gyro':
        return Gyro(key: UniqueKey(), topic: topic);
      case '3AxisAccelerometer':
        return ThreeAxisAccelerometer(key: UniqueKey(), topic: topic);
      case 'Accelerometer':
        return AccelerometerWidget(key: UniqueKey(), topic: topic);
      case 'Encoder':
      case 'Quadrature Encoder':
        return EncoderWidget(key: UniqueKey(), topic: topic);
      case 'Field2d':
        return FieldWidget(key: UniqueKey(), topic: topic);
      case 'PowerDistribution':
        return PowerDistribution(key: UniqueKey(), topic: topic);
      case 'PIDController':
        return PIDControllerWidget(key: UniqueKey(), topic: topic);
      case 'DifferentialDrive':
        return DifferentialDrive(key: UniqueKey(), topic: topic);
      case 'SwerveDrive':
        return SwerveDriveWidget(key: UniqueKey(), topic: topic);
      case 'String Chooser':
        return ComboBoxChooser(key: UniqueKey(), topic: topic);
      case 'Subsystem':
        return SubsystemWidget(key: UniqueKey(), topic: topic);
      case 'Command':
        return CommandWidget(key: UniqueKey(), topic: topic);
      case 'Scheduler':
        return CommandSchedulerWidget(key: UniqueKey(), topic: topic);
      case 'FMSInfo':
        return FMSInfo(key: UniqueKey(), topic: topic);
      case 'RobotPreferences':
        return RobotPreferences(key: UniqueKey(), topic: topic);
      case 'Alerts':
        return NetworkAlerts(key: UniqueKey(), topic: topic);
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
    } else if (primary is EncoderWidget) {
      width = normalGridSize * 2;
    } else if (primary is CameraStreamWidget) {
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
    } else if (primary is DifferentialDrive) {
      width = normalGridSize * 3;
      height = normalGridSize * 2;
    } else if (primary is SwerveDriveWidget) {
      width = normalGridSize * 2;
      height = normalGridSize * 2;
    } else if (primary is SubsystemWidget) {
      width = normalGridSize * 2;
    } else if (primary is CommandWidget) {
      width = normalGridSize * 2;
    } else if (primary is CommandSchedulerWidget) {
      width = normalGridSize * 2;
      height = normalGridSize * 3;
    } else if (primary is FMSInfo) {
      width = normalGridSize * 3;
    } else if (primary is RobotPreferences) {
      width = normalGridSize * 2;
      height = normalGridSize * 3;
    } else if (primary is NetworkAlerts) {
      width = normalGridSize * 2;
      height = normalGridSize * 3;
    }

    return WidgetContainer(
      title: rowName,
      width: width,
      height: height,
      child: primary,
    );
  }
}
