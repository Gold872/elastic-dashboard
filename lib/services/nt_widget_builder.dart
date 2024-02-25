import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/basic_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/differential_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/motor_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/network_alerts.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/profiled_pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/relay_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/three_axis_accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/ultrasonic.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/yagsl_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_slider.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/radial_gauge.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/voltage_view.dart';

class NTWidgetBuilder {
  static final Map<String, NTWidget Function({Key? key})> _widgetNameBuildMap =
      {};

  static final Map<
      String,
      NTWidgetModel Function({
        required String topic,
        String dataType,
        double period,
      })> _modelNameBuildMap = {};

  static final Map<
      String,
      NTWidgetModel Function({
        required Map<String, dynamic> jsonData,
      })> _modelJsonBuildMap = {};

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

    logger.info('Configuring NT Widget Builder');

    _modelNameBuildMap.addAll({
      BooleanBox.widgetType: BooleanBoxModel.new,
      GraphWidget.widgetType: GraphModel.new,
      MatchTimeWidget.widgetType: MatchTimeModel.new,
      NumberBar.widgetType: NumberBarModel.new,
      NumberSlider.widgetType: NumberSliderModel.new,
      RadialGauge.widgetType: RadialGaugeModel.new,
      TextDisplay.widgetType: TextDisplayModel.new,
      'Text View': TextDisplayModel.new,
      VoltageView.widgetType: VoltageViewModel.new,
    });

    _modelNameBuildMap.addAll({
      AccelerometerWidget.widgetType: AccelerometerModel.new,
      SwerveDriveWidget.widgetType: BasicSwerveModel.new,
      CameraStreamWidget.widgetType: CameraStreamModel.new,
      ComboBoxChooser.widgetType: ComboBoxChooserModel.new,
      'String Chooser': ComboBoxChooserModel.new,
      CommandSchedulerWidget.widgetType: CommandSchedulerModel.new,
      CommandWidget.widgetType: CommandModel.new,
      DifferentialDrive.widgetType: DifferentialDriveModel.new,
      'Differential Drivebase': DifferentialDriveModel.new,
      EncoderWidget.widgetType: EncoderModel.new,
      'Quadrature Encoder': EncoderModel.new,
      FieldWidget.widgetType: FieldWidgetModel.new,
      'Field2d': FieldWidgetModel.new,
      FMSInfo.widgetType: FMSInfoModel.new,
      Gyro.widgetType: GyroModel.new,
      MotorController.widgetType: MotorControllerModel.new,
      'Nidec Brushless': MotorControllerModel.new,
      NetworkAlerts.widgetType: NetworkAlertsModel.new,
      PIDControllerWidget.widgetType: PIDControllerModel.new,
      'PID Controller': PIDControllerModel.new,
      PowerDistribution.widgetType: PowerDistributionModel.new,
      'PDP': PowerDistributionModel.new,
      ProfiledPIDControllerWidget.widgetType: ProfiledPIDControllerModel.new,
      RelayWidget.widgetType: RelayModel.new,
      RobotPreferences.widgetType: RobotPreferencesModel.new,
      SplitButtonChooser.widgetType: SplitButtonChooserModel.new,
      SubsystemWidget.widgetType: SubsystemModel.new,
      ThreeAxisAccelerometer.widgetType: ThreeAxisAccelerometerModel.new,
      '3AxisAccelerometer': ThreeAxisAccelerometerModel.new,
      Ultrasonic.widgetType: UltrasonicModel.new,
      YAGSLSwerveDrive.widgetType: YAGSLSwerveDriveModel.new,
    });

    _modelJsonBuildMap.addAll({
      BooleanBox.widgetType: BooleanBoxModel.fromJson,
      GraphWidget.widgetType: GraphModel.fromJson,
      MatchTimeWidget.widgetType: MatchTimeModel.fromJson,
      NumberBar.widgetType: NumberBarModel.fromJson,
      NumberSlider.widgetType: NumberSliderModel.fromJson,
      RadialGauge.widgetType: RadialGaugeModel.fromJson,
      TextDisplay.widgetType: TextDisplayModel.fromJson,
      'Text View': TextDisplayModel.fromJson,
      VoltageView.widgetType: VoltageViewModel.fromJson,
    });

    _modelJsonBuildMap.addAll({
      AccelerometerWidget.widgetType: AccelerometerModel.fromJson,
      SwerveDriveWidget.widgetType: BasicSwerveModel.fromJson,
      CameraStreamWidget.widgetType: CameraStreamModel.fromJson,
      ComboBoxChooser.widgetType: ComboBoxChooserModel.fromJson,
      CommandSchedulerWidget.widgetType: CommandSchedulerModel.fromJson,
      CommandWidget.widgetType: CommandModel.fromJson,
      DifferentialDrive.widgetType: DifferentialDriveModel.fromJson,
      'Differential Drivebase': DifferentialDriveModel.fromJson,
      EncoderWidget.widgetType: EncoderModel.fromJson,
      'Quadrature Encoder': EncoderModel.fromJson,
      FieldWidget.widgetType: FieldWidgetModel.fromJson,
      'Field2d': FieldWidgetModel.fromJson,
      FMSInfo.widgetType: FMSInfoModel.fromJson,
      Gyro.widgetType: GyroModel.fromJson,
      MotorController.widgetType: MotorControllerModel.fromJson,
      'Nidec Brushless': MotorControllerModel.fromJson,
      NetworkAlerts.widgetType: NetworkAlertsModel.fromJson,
      PIDControllerWidget.widgetType: PIDControllerModel.fromJson,
      'PID Controller': PIDControllerModel.fromJson,
      PowerDistribution.widgetType: PowerDistributionModel.fromJson,
      'PDP': PowerDistributionModel.fromJson,
      ProfiledPIDControllerWidget.widgetType:
          ProfiledPIDControllerModel.fromJson,
      RelayWidget.widgetType: RelayModel.fromJson,
      RobotPreferences.widgetType: RobotPreferencesModel.fromJson,
      SplitButtonChooser.widgetType: SplitButtonChooserModel.fromJson,
      SubsystemWidget.widgetType: SubsystemModel.fromJson,
      ThreeAxisAccelerometer.widgetType: ThreeAxisAccelerometerModel.fromJson,
      '3AxisAccelerometer': ThreeAxisAccelerometerModel.fromJson,
      Ultrasonic.widgetType: UltrasonicModel.fromJson,
      YAGSLSwerveDrive.widgetType: YAGSLSwerveDriveModel.fromJson,
    });

    // Used when building widgets from network tables (drag and drop)
    _widgetNameBuildMap.addAll({
      BooleanBox.widgetType: BooleanBox.new,
      GraphWidget.widgetType: GraphWidget.new,
      MatchTimeWidget.widgetType: MatchTimeWidget.new,
      MultiColorView.widgetType: MultiColorView.new,
      NumberBar.widgetType: NumberBar.new,
      NumberSlider.widgetType: NumberSlider.new,
      RadialGauge.widgetType: RadialGauge.new,
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
      YAGSLSwerveDrive.widgetType: YAGSLSwerveDrive.new,
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
      RadialGauge.widgetType: _normalSize * 1.6,
      RobotPreferences.widgetType: _normalSize * 2,
      SubsystemWidget.widgetType: _normalSize * 2,
      SwerveDriveWidget.widgetType: _normalSize * 2,
      Ultrasonic.widgetType: _normalSize * 2,
      YAGSLSwerveDrive.widgetType: _normalSize * 2,
    });

    _minimumHeightMap.addAll({
      YAGSLSwerveDrive.widgetType: _normalSize * 2,
      CameraStreamWidget.widgetType: _normalSize * 2,
      ComboBoxChooser.widgetType: _normalSize * 0.85,
      CommandSchedulerWidget.widgetType: _normalSize * 2,
      CommandWidget.widgetType: _normalSize * 0.90,
      DifferentialDrive.widgetType: _normalSize * 2,
      EncoderWidget.widgetType: _normalSize * 0.86,
      FieldWidget.widgetType: _normalSize * 2,
      FMSInfo.widgetType: _normalSize,
      GraphWidget.widgetType: _normalSize * 2,
      Gyro.widgetType: _normalSize * 2,
      MotorController.widgetType: _normalSize * 0.92,
      NetworkAlerts.widgetType: _normalSize * 2,
      NumberBar.widgetType: _normalSize,
      NumberSlider.widgetType: _normalSize,
      PIDControllerWidget.widgetType: _normalSize * 3,
      PowerDistribution.widgetType: _normalSize * 3,
      ProfiledPIDControllerWidget.widgetType: _normalSize * 3,
      RadialGauge.widgetType: _normalSize * 1.6,
      RelayWidget.widgetType: _normalSize * 2,
      RobotPreferences.widgetType: _normalSize * 2,
      SwerveDriveWidget.widgetType: _normalSize * 2,
      VoltageView.widgetType: _normalSize,
    });

    // Default width and height (when dragging and dropping)
    _defaultWidthMap.addAll({
      YAGSLSwerveDrive.widgetType: 2,
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
      YAGSLSwerveDrive.widgetType: 2,
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

  static NTWidget? buildNTWidgetFromModel(NTWidgetModel model, {Key? key}) {
    ensureInitialized();

    if (_widgetNameBuildMap.containsKey(model.type)) {
      return _widgetNameBuildMap[model.type]!(key: key);
    }
    return null;
  }

  static NTWidgetModel buildNTModelFromType(
    String type,
    String topic, {
    String dataType = 'Unknown',
    double? period,
  }) {
    period ??= Settings.defaultPeriod;

    ensureInitialized();

    if (_modelNameBuildMap.containsKey(type)) {
      return _modelNameBuildMap[type]!(
        topic: topic,
        dataType: dataType,
        period: period,
      );
    }

    return NTWidgetModel.createDefault(
      type: type,
      topic: topic,
      dataType: dataType,
      period: period,
    );
  }

  static NTWidgetModel buildNTModelFromJson(
      String type, Map<String, dynamic> jsonData,
      {Function(String message)? onWidgetTypeNotFound}) {
    ensureInitialized();

    if (_modelJsonBuildMap.containsKey(type)) {
      return _modelJsonBuildMap[type]!(jsonData: jsonData);
    }

    onWidgetTypeNotFound
        ?.call('Unknown widget type: \'$type\', defaulting to Empty Model.');
    return NTWidgetModel.createDefault(
      type: type,
      topic: tryCast(jsonData['topic']) ?? '',
      dataType: tryCast(jsonData['data_type']) ?? 'Unknown',
      period: tryCast(jsonData['period']),
    );
  }

  static double getMinimumWidth(NTWidgetModel widget) {
    ensureInitialized();

    if (_minimumWidthMap.containsKey(widget.type)) {
      return _minimumWidthMap[widget.type]!;
    } else {
      return Settings.gridSize.toDouble();
    }
  }

  static double getMinimumHeight(NTWidgetModel widget) {
    ensureInitialized();

    if (_minimumHeightMap.containsKey(widget.type)) {
      return _minimumHeightMap[widget.type]!;
    } else {
      return Settings.gridSize.toDouble();
    }
  }

  static double getDefaultWidth(NTWidgetModel widget) {
    ensureInitialized();

    double snappedNormal = DraggableWidgetContainer.snapToGrid(_normalSize)
        .clamp(128.0, double.infinity);

    if (_defaultWidthMap.containsKey(widget.type)) {
      return snappedNormal * _defaultWidthMap[widget.type]!;
    }
    return snappedNormal;
  }

  static double getDefaultHeight(NTWidgetModel widget) {
    ensureInitialized();

    double snappedNormal = DraggableWidgetContainer.snapToGrid(_normalSize)
        .clamp(128.0, double.infinity);

    if (_defaultHeightMap.containsKey(widget.type)) {
      return snappedNormal * _defaultHeightMap[widget.type]!;
    }
    return snappedNormal;
  }
}
