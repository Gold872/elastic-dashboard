import 'dart:io';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/network_table_tree.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titlebar_buttons/titlebar_buttons.dart';

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

  testWidgets('Closing tab', (widgetTester) async {
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

    final closeTabButton = find
        .descendant(
            of: find.byType(EditableTabBar), matching: find.byIcon(Icons.close))
        .last;

    expect(closeTabButton, findsOneWidget);

    await widgetTester.tap(closeTabButton);
    await widgetTester.pumpAndSettle();

    expect(find.text('Confirm Tab Close', skipOffstage: false), findsOneWidget);

    final confirmButton =
        find.widgetWithText(TextButton, 'OK', skipOffstage: false);

    expect(confirmButton, findsOneWidget);

    await widgetTester.tap(confirmButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(DashboardGrid, skipOffstage: false), findsNWidgets(1));
  });

  testWidgets('Renaming tab', (widgetTester) async {
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

    final teleopTab = find.widgetWithText(AnimatedContainer, 'Teleoperated');

    expect(teleopTab, findsOneWidget);

    await widgetTester.tap(teleopTab, buttons: kSecondaryButton);
    await widgetTester.pumpAndSettle();

    final renameButton =
        find.widgetWithText(ListTile, 'Rename', skipOffstage: false);

    expect(renameButton, findsOneWidget);

    await widgetTester.tap(renameButton);
    await widgetTester.pumpAndSettle();

    expect(find.text('Rename Tab'), findsOneWidget);

    final nameTextField = find.widgetWithText(DialogTextInput, 'Name');

    expect(nameTextField, findsOneWidget);

    await widgetTester.enterText(nameTextField, 'New Tab Name!');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    final saveButton = find.widgetWithText(TextButton, 'Save');

    expect(saveButton, findsOneWidget);

    await widgetTester.tap(saveButton);
    await widgetTester.pumpAndSettle();

    expect(
        find.widgetWithText(AnimatedContainer, 'Teleoperated'), findsNothing);
    expect(find.widgetWithText(AnimatedContainer, 'New Tab Name!'),
        findsOneWidget);
  });

  testWidgets('Minimizing window', (widgetTester) async {
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

    final minimizeButton = find.byType(DecoratedMinimizeButton);

    expect(minimizeButton, findsOneWidget);

    await widgetTester.tap(minimizeButton);
  });

  testWidgets('Maximizing/unmaximizing window', (widgetTester) async {
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

    final appBar = find.byType(CustomAppBar);

    expect(appBar, findsOneWidget);

    await widgetTester.tap(appBar);
    await widgetTester.pump(kDoubleTapMinTime);
    await widgetTester.tap(appBar);

    await widgetTester.pumpAndSettle();

    final maximizeButton = find.byType(DecoratedMaximizeButton);

    expect(maximizeButton, findsOneWidget);

    await widgetTester.tap(maximizeButton);
  });

  testWidgets('Closing window', (widgetTester) async {
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

    final closeButton = find.byType(DecoratedCloseButton);

    expect(closeButton, findsOneWidget);

    await widgetTester.tap(closeButton);
  });

  testWidgets('Opening settings', (widgetTester) async {
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

    final settingsButton = find.widgetWithIcon(MenuItemButton, Icons.settings);

    expect(settingsButton, findsOneWidget);

    final settingsButtonWidget =
        settingsButton.evaluate().first.widget as MenuItemButton;

    settingsButtonWidget.onPressed?.call();

    await widgetTester.pumpAndSettle();

    expect(find.byType(SettingsDialog), findsOneWidget);
  });
}
