import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/basic_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  final Map<String, dynamic> swerveJson = {
    'topic': 'Test/Basic Swerve Drive',
    'period': 0.100,
    'show_robot_rotation': false,
    'rotation_unit': 'Radians',
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('Basic swerve model from json', () {
    NTWidgetModel swerveModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'SwerveDrive',
      swerveJson,
    );

    expect(swerveModel.type, 'SwerveDrive');
    expect(swerveModel.runtimeType, BasicSwerveModel);

    if (swerveModel is! BasicSwerveModel) {
      return;
    }

    expect(swerveModel.showRobotRotation, isFalse);
    expect(swerveModel.rotationUnit, 'Radians');

    expect(swerveModel.frontLeftAngleTopic,
        'Test/Basic Swerve Drive/Front Left Angle');
    expect(swerveModel.frontLeftVelocityTopic,
        'Test/Basic Swerve Drive/Front Left Velocity');

    expect(swerveModel.frontRightAngleTopic,
        'Test/Basic Swerve Drive/Front Right Angle');
    expect(swerveModel.frontRightVelocityTopic,
        'Test/Basic Swerve Drive/Front Right Velocity');

    expect(swerveModel.backLeftAngleTopic,
        'Test/Basic Swerve Drive/Back Left Angle');
    expect(swerveModel.backLeftVelocityTopic,
        'Test/Basic Swerve Drive/Back Left Velocity');

    expect(swerveModel.backRightAngleTopic,
        'Test/Basic Swerve Drive/Back Right Angle');
    expect(swerveModel.backRightVelocityTopic,
        'Test/Basic Swerve Drive/Back Right Velocity');
  });

  test('Basic swerve model to json', () {
    BasicSwerveModel swerveModel = BasicSwerveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Basic Swerve Drive',
      period: 0.100,
      rotationUnit: 'Radians',
      showRobotRotation: false,
    );

    expect(swerveModel.toJson(), swerveJson);
  });

  testWidgets('Basic swerve widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel swerveModel = NTWidgetBuilder.buildNTModelFromJson(
        ntConnection, preferences, 'SwerveDrive', swerveJson);

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: swerveModel,
            child: const SwerveDriveWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
