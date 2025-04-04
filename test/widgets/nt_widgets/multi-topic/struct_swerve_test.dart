import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/struct_swerve.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> structSwerveJson = {
    'topic': 'Test/Struct Swerve',
    'period': 0.100,
    'show_robot_rotation': true,
    'show_desired_states': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('Struct swerve from json', () {
    NTWidgetModel structSwerveModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Struct Swerve',
      structSwerveJson,
    );

    expect(structSwerveModel.type, 'Struct Swerve');
    expect(structSwerveModel.runtimeType, StructSwerveModel);

    if (structSwerveModel is! StructSwerveModel) {
      return;
    }

    expect(structSwerveModel.showRobotRotation, isTrue);
    expect(structSwerveModel.showDesiredStates, isTrue);
  });

  test('Struct swerve to json', () {
    StructSwerveModel structSwerveModel = StructSwerveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Struct Swerve',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
    );

    expect(structSwerveModel.toJson(), structSwerveJson);
  });

  testWidgets('Struct swerve widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel structSwerveModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Struct Swerve',
      structSwerveJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: structSwerveModel,
            child: const StructSwerve(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Struct swerve edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    StructSwerveModel structSwerveModel = StructSwerveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Struct Swerve',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Struct Swerve',
      childModel: structSwerveModel,
    );

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            key: key,
            value: ntContainerModel,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    ntContainerModel.showEditProperties(key.currentContext!);

    await widgetTester.pumpAndSettle();

    final showRobotRotation =
        find.widgetWithText(DialogToggleSwitch, 'Show Robot Rotation');
    final showDesiredStates =
        find.widgetWithText(DialogToggleSwitch, 'Show Desired States');

    expect(showRobotRotation, findsOneWidget);
    expect(showDesiredStates, findsOneWidget);

    await widgetTester.tap(
      find.descendant(
        of: showRobotRotation,
        matching: find.byType(Switch),
      ),
    );
    await widgetTester.pumpAndSettle();
    expect(structSwerveModel.showRobotRotation, false);

    await widgetTester.tap(
      find.descendant(
        of: showDesiredStates,
        matching: find.byType(Switch),
      ),
    );
    await widgetTester.pumpAndSettle();
    expect(structSwerveModel.showDesiredStates, false);
  });
}
