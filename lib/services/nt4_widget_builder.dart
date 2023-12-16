import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/differential_drive.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/motor_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/network_alerts.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/profiled_pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/relay_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/three_axis_accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/ultrasonic.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/graph.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/number_slider.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/voltage_view.dart';

class NT4WidgetBuilder {
  static final Map<
      String,
      NT4Widget Function({
        Key? key,
        required Map<String, dynamic> jsonData,
      })> _widgetJsonBuildMap = {};

  static final Map<
      String,
      NT4Widget Function({
        Key? key,
        required String topic,
        String dataType,
        double period,
      })> _widgetNameBuildMap = {};

  static final Map<String, double> _minimumWidthMap = {};
  static final Map<String, double> _minimumHeightMap = {};

  static final Map<String, double> _defaultWidthMap = {};
  static final Map<String, double> _defaultHeightMap = {};

  static const double _normalSize = 128.0;

  static bool _initialized = false;
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }

    logger.info('Configuring NT4 Widget Builder');

    // Single-Topic Widgets
    _widgetJsonBuildMap.addAll({
      BooleanBox.widgetType: BooleanBox.fromJson,
      GraphWidget.widgetType: GraphWidget.fromJson,
      MatchTimeWidget.widgetType: MatchTimeWidget.fromJson,
      MultiColorView.widgetType: MultiColorView.fromJson,
      NumberBar.widgetType: NumberBar.fromJson,
      NumberSlider.widgetType: NumberSlider.fromJson,
      SingleColorView.widgetType: SingleColorView.fromJson,
      TextDisplay.widgetType: TextDisplay.fromJson,
      'Text View': TextDisplay.fromJson,
      ToggleButton.widgetType: ToggleButton.fromJson,
      ToggleSwitch.widgetType: ToggleSwitch.fromJson,
      VoltageView.widgetType: VoltageView.fromJson,
    });

    // Multi-Topic Widgets
    _widgetJsonBuildMap.addAll({
      AccelerometerWidget.widgetType: AccelerometerWidget.fromJson,
      CameraStreamWidget.widgetType: CameraStreamWidget.fromJson,
      ComboBoxChooser.widgetType: ComboBoxChooser.fromJson,
      CommandSchedulerWidget.widgetType: CommandSchedulerWidget.fromJson,
      CommandWidget.widgetType: CommandWidget.fromJson,
      DifferentialDrive.widgetType: DifferentialDrive.fromJson,
      'Differential Drivebase': DifferentialDrive.fromJson,
      EncoderWidget.widgetType: EncoderWidget.fromJson,
      'Quadrature Encoder': EncoderWidget.fromJson,
      FieldWidget.widgetType: FieldWidget.fromJson,
      'Field2d': FieldWidget.fromJson,
      FMSInfo.widgetType: FMSInfo.fromJson,
      Gyro.widgetType: Gyro.fromJson,
      MotorController.widgetType: MotorController.fromJson,
      'Nidec Brushless': MotorController.fromJson,
      NetworkAlerts.widgetType: NetworkAlerts.fromJson,
      PIDControllerWidget.widgetType: PIDControllerWidget.fromJson,
      'PID Controller': PIDControllerWidget.fromJson,
      PowerDistribution.widgetType: PowerDistribution.fromJson,
      'PDP': PowerDistribution.fromJson,
      ProfiledPIDControllerWidget.widgetType:
          ProfiledPIDControllerWidget.fromJson,
      RelayWidget.widgetType: RelayWidget.fromJson,
      RobotPreferences.widgetType: RobotPreferences.fromJson,
      SplitButtonChooser.widgetType: SplitButtonChooser.fromJson,
      SubsystemWidget.widgetType: SubsystemWidget.fromJson,
      SwerveDriveWidget.widgetType: SwerveDriveWidget.fromJson,
      ThreeAxisAccelerometer.widgetType: ThreeAxisAccelerometer.fromJson,
      '3AxisAccelerometer': ThreeAxisAccelerometer.fromJson,
      Ultrasonic.widgetType: Ultrasonic.fromJson,
    });

    // Used when building widgets from network tables (drag and drop)
    _widgetNameBuildMap.addAll({
      BooleanBox.widgetType: BooleanBox.new,
      GraphWidget.widgetType: GraphWidget.new,
      MatchTimeWidget.widgetType: MatchTimeWidget.new,
      MultiColorView.widgetType: MultiColorView.new,
      NumberBar.widgetType: NumberBar.new,
      NumberSlider.widgetType: NumberSlider.new,
      SingleColorView.widgetType: SingleColorView.new,
      TextDisplay.widgetType: TextDisplay.new,
      'Text View': TextDisplay.new,
      ToggleButton.widgetType: ToggleButton.new,
      ToggleSwitch.widgetType: ToggleSwitch.new,
      VoltageView.widgetType: VoltageView.new,
    });

    _widgetNameBuildMap.addAll({
      AccelerometerWidget.widgetType: AccelerometerWidget.new,
      CameraStreamWidget.widgetType: CameraStreamWidget.new,
      ComboBoxChooser.widgetType: ComboBoxChooser.new,
      'String Chooser': ComboBoxChooser.new,
      CommandSchedulerWidget.widgetType: CommandSchedulerWidget.new,
      CommandWidget.widgetType: CommandWidget.new,
      DifferentialDrive.widgetType: DifferentialDrive.new,
      'Differential Drivebase': DifferentialDrive.new,
      EncoderWidget.widgetType: EncoderWidget.new,
      'Quadrature Encoder': EncoderWidget.new,
      FieldWidget.widgetType: FieldWidget.new,
      'Field2d': FieldWidget.new,
      FMSInfo.widgetType: FMSInfo.new,
      Gyro.widgetType: Gyro.new,
      MotorController.widgetType: MotorController.new,
      'Nidec Brushless': MotorController.new,
      NetworkAlerts.widgetType: NetworkAlerts.new,
      PIDControllerWidget.widgetType: PIDControllerWidget.new,
      'PID Controller': PIDControllerWidget.new,
      PowerDistribution.widgetType: PowerDistribution.new,
      'PDP': PowerDistribution.new,
      ProfiledPIDControllerWidget.widgetType: ProfiledPIDControllerWidget.new,
      RelayWidget.widgetType: RelayWidget.new,
      RobotPreferences.widgetType: RobotPreferences.new,
      SplitButtonChooser.widgetType: SplitButtonChooser.new,
      SubsystemWidget.widgetType: SubsystemWidget.new,
      SwerveDriveWidget.widgetType: SwerveDriveWidget.new,
      ThreeAxisAccelerometer.widgetType: ThreeAxisAccelerometer.new,
      '3AxisAccelerometer': ThreeAxisAccelerometer.new,
      Ultrasonic.widgetType: Ultrasonic.new,
    });

    // Min width and height
    _minimumWidthMap.addAll({
      CameraStreamWidget.widgetType: _normalSize * 2,
      CommandSchedulerWidget.widgetType: _normalSize * 2,
      CommandWidget.widgetType: _normalSize * 2,
      DifferentialDrive.widgetType: _normalSize * 2,
      EncoderWidget.widgetType: _normalSize * 2,
      FieldWidget.widgetType: _normalSize * 3,
      FMSInfo.widgetType: _normalSize * 3,
      GraphWidget.widgetType: _normalSize * 2,
      Gyro.widgetType: _normalSize * 2,
      NetworkAlerts.widgetType: _normalSize * 2,
      PIDControllerWidget.widgetType: _normalSize * 2,
      PowerDistribution.widgetType: _normalSize * 3,
      ProfiledPIDControllerWidget.widgetType: _normalSize * 2,
      RobotPreferences.widgetType: _normalSize * 2,
      SubsystemWidget.widgetType: _normalSize * 2,
      SwerveDriveWidget.widgetType: _normalSize * 2,
      Ultrasonic.widgetType: _normalSize * 2,
    });

    _minimumHeightMap.addAll({
      CameraStreamWidget.widgetType: _normalSize * 2,
      CommandSchedulerWidget.widgetType: _normalSize * 2,
      DifferentialDrive.widgetType: _normalSize * 2,
      FieldWidget.widgetType: _normalSize * 2,
      GraphWidget.widgetType: _normalSize * 2,
      Gyro.widgetType: _normalSize * 2,
      NetworkAlerts.widgetType: _normalSize * 2,
      PIDControllerWidget.widgetType: _normalSize * 3,
      PowerDistribution.widgetType: _normalSize * 3,
      ProfiledPIDControllerWidget.widgetType: _normalSize * 3,
      RelayWidget.widgetType: _normalSize * 2,
      RobotPreferences.widgetType: _normalSize * 2,
      SwerveDriveWidget.widgetType: _normalSize * 2,
    });

    // Default width and height (when dragging and dropping)
    _defaultWidthMap.addAll({
      CameraStreamWidget.widgetType: 2,
      CommandSchedulerWidget.widgetType: 2,
      CommandWidget.widgetType: 2,
      DifferentialDrive.widgetType: 3,
      EncoderWidget.widgetType: 2,
      FieldWidget.widgetType: 3,
      FMSInfo.widgetType: 3,
      Gyro.widgetType: 2,
      NetworkAlerts.widgetType: 2,
      PIDControllerWidget.widgetType: 2,
      PowerDistribution.widgetType: 3,
      ProfiledPIDControllerWidget.widgetType: 2,
      RobotPreferences.widgetType: 2,
      SubsystemWidget.widgetType: 2,
      SwerveDriveWidget.widgetType: 2,
      Ultrasonic.widgetType: 2,
    });

    _defaultHeightMap.addAll({
      CameraStreamWidget.widgetType: 2,
      CommandSchedulerWidget.widgetType: 3,
      DifferentialDrive.widgetType: 2,
      FieldWidget.widgetType: 2,
      Gyro.widgetType: 2,
      NetworkAlerts.widgetType: 3,
      PIDControllerWidget.widgetType: 3,
      PowerDistribution.widgetType: 4,
      ProfiledPIDControllerWidget.widgetType: 3,
      RelayWidget.widgetType: 2,
      RobotPreferences.widgetType: 3,
      SwerveDriveWidget.widgetType: 2,
    });

    _initialized = true;
  }

  static NT4Widget buildNT4WidgetFromJson(
      String type, Map<String, dynamic> jsonData,
      {Function(String message)? onWidgetTypeNotFound}) {
    ensureInitialized();

    if (_widgetJsonBuildMap.containsKey(type)) {
      return _widgetJsonBuildMap[type]!(
        key: UniqueKey(),
        jsonData: jsonData,
      );
    } else {
      onWidgetTypeNotFound?.call(
          'Unknown widget type: \'$type\', defaulting to Text Display widget.');

      return TextDisplay.fromJson(key: UniqueKey(), jsonData: jsonData);
    }
  }

  static NT4Widget? buildNT4WidgetFromType(
    String type,
    String topic, {
    String dataType = 'Unknown',
    double period = Settings.defaultPeriod,
  }) {
    ensureInitialized();

    if (_widgetNameBuildMap.containsKey(type)) {
      return _widgetNameBuildMap[type]!(
        key: UniqueKey(),
        topic: topic,
        dataType: dataType,
        period: period,
      );
    }

    return null;
  }

  static double getMinimumWidth(NT4Widget? widget) {
    ensureInitialized();

    if (widget != null && _minimumWidthMap.containsKey(widget.type)) {
      return _minimumWidthMap[widget.type]!;
    } else {
      return _normalSize;
    }
  }

  static double getMinimumHeight(NT4Widget? widget) {
    ensureInitialized();

    if (widget != null && _minimumHeightMap.containsKey(widget.type)) {
      return _minimumHeightMap[widget.type]!;
    } else {
      return _normalSize;
    }
  }

  static double getDefaultWidth(NT4Widget widget) {
    ensureInitialized();

    double snappedNormal = DraggableWidgetContainer.snapToGrid(_normalSize)
        .clamp(128.0, double.infinity);

    if (_defaultWidthMap.containsKey(widget.type)) {
      return snappedNormal * _defaultWidthMap[widget.type]!;
    }
    return snappedNormal;
  }

  static double getDefaultHeight(NT4Widget widget) {
    ensureInitialized();

    double snappedNormal = DraggableWidgetContainer.snapToGrid(_normalSize)
        .clamp(128.0, double.infinity);

    if (_defaultHeightMap.containsKey(widget.type)) {
      return snappedNormal * _defaultHeightMap[widget.type]!;
    }
    return snappedNormal;
  }
}
