import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/yagsl_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> yagslSwerveJson = {
    'topic': 'Test/YAGSL Swerve Drive',
    'period': 0.100,
    'show_robot_rotation': true,
    'show_desired_states': true,
    'angle_offset': 90.0,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('YAGSL swerve drive from json', () {
    NTWidgetModel yagslSwerveModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'YAGSL Swerve Drive',
      yagslSwerveJson,
    );

    expect(yagslSwerveModel.type, 'YAGSL Swerve Drive');
    expect(yagslSwerveModel.runtimeType, YAGSLSwerveDriveModel);

    if (yagslSwerveModel is! YAGSLSwerveDriveModel) {
      return;
    }

    expect(yagslSwerveModel.showRobotRotation, isTrue);
    expect(yagslSwerveModel.showDesiredStates, isTrue);
    expect(yagslSwerveModel.angleOffset, 90.0);
  });

  test('YAGSL swerve drive to json', () {
    YAGSLSwerveDriveModel yagslSwerveModel = YAGSLSwerveDriveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/YAGSL Swerve Drive',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
      angleOffset: 90.0,
    );

    expect(yagslSwerveModel.toJson(), yagslSwerveJson);
  });

  testWidgets('YAGSL swerve drive widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel yagslSwerveModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'YAGSL Swerve Drive',
      yagslSwerveJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: yagslSwerveModel,
            child: const YAGSLSwerveDrive(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
