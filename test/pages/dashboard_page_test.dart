import 'dart:io';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/network_table_tree.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String jsonFilePath =
      '${Directory.current.path}/test_resources/test-layout.json';

  late String jsonString;

  late SharedPreferences preferences;

  setUpAll(() async {
    await FieldImages.loadFields('assets/fields/');

    jsonString = File(jsonFilePath).readAsStringSync();

    SharedPreferences.setMockInitialValues({
      PrefKeys.layout: jsonString,
      PrefKeys.teamNumber: 353,
      PrefKeys.ipAddress: '10.3.53.2',
    });

    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('Dashboard page loading offline', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          connectionStream: Stream.value(false),
          preferences: preferences,
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.textContaining('Network Tables: Disconnected'), findsWidgets);
    expect(find.textContaining('Network Tables: Connected'), findsNothing);
    expect(find.textContaining('(10.3.53.2)'), findsNothing);
    expect(find.text('Team 353'), findsOneWidget);

    expect(find.text('Teleoperated'), findsOneWidget);
    expect(find.text('Autonomous'), findsOneWidget);
  });

  testWidgets('Dashboard page loading online', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOnlineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          connectionStream: Stream.value(true),
          preferences: preferences,
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.textContaining('Network Tables: Disconnected'), findsNothing);
    expect(find.textContaining('Network Tables: Connected'), findsWidgets);
    expect(find.textContaining('(10.3.53.2)'), findsWidgets);
    expect(find.text('Team 353'), findsOneWidget);

    expect(find.text('Teleoperated'), findsOneWidget);
    expect(find.text('Autonomous'), findsOneWidget);
  });

  testWidgets('Add widget dialog', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOnlineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          connectionStream: Stream.value(true),
          preferences: preferences,
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Add Widget'), findsOneWidget);
    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

    await widgetTester.tap(find.text('Add Widget'));

    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsOneWidget);

    final smartDashboardTile = find.widgetWithText(TreeTile, 'SmartDashboard');

    expect(smartDashboardTile, findsOneWidget);

    await widgetTester.tap(smartDashboardTile);
    await widgetTester.pumpAndSettle();

    final testValueTile = find.widgetWithText(TreeTile, 'Test Value 1');
    final testValueContainer =
        find.widgetWithText(WidgetContainer, 'Test Value 1');

    expect(testValueTile, findsOneWidget);
    expect(find.widgetWithText(TreeTile, 'Test Value 2'), findsOneWidget);

    await widgetTester.drag(testValueTile, const Offset(100, 100));
    await widgetTester.pumpAndSettle();

    expect(testValueContainer, findsNothing);

    await widgetTester.drag(testValueTile, const Offset(300, -150));
    await widgetTester.pumpAndSettle(const Duration(seconds: 5));

    expect(testValueContainer, findsOneWidget);

    final dialogDragHandle = find.byIcon(Icons.drag_handle);

    expect(dialogDragHandle, findsOneWidget);

    await widgetTester.drag(dialogDragHandle, const Offset(100, 0));
    await widgetTester.pumpAndSettle();
  });

  testWidgets('Changing tabs', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          connectionStream: Stream.value(false),
          preferences: preferences,
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(ComboBoxChooser), findsNothing);

    expect(find.byType(EditableTabBar), findsOneWidget);

    final autonomousTab = find.widgetWithText(AnimatedContainer, 'Autonomous');

    expect(autonomousTab, findsOneWidget);

    await widgetTester.tap(autonomousTab);
    await widgetTester.pumpAndSettle();

    expect(find.byType(ComboBoxChooser), findsOneWidget);
  });

  testWidgets('Creating new tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          connectionStream: Stream.value(false),
          preferences: preferences,
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(DashboardGrid, skipOffstage: false), findsNWidgets(2));

    expect(find.byType(EditableTabBar), findsOneWidget);

    final createNewTabButton = find.descendant(
        of: find.byType(EditableTabBar), matching: find.byIcon(Icons.add));

    expect(createNewTabButton, findsOneWidget);

    await widgetTester.tap(createNewTabButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(DashboardGrid, skipOffstage: false), findsNWidgets(3));
  });
}
