import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titlebar_buttons/titlebar_buttons.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/layout_drag_tile.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';
import '../test_util.dart';
import '../test_util.mocks.dart';

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
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.textContaining('Network Tables: Disconnected'), findsOneWidget);
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
          preferences: preferences,
          version: '0.0.0.0',
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

  testWidgets('Save layout (button)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final fileButton = find.widgetWithText(SubmenuButton, 'File');

    expect(fileButton, findsOneWidget);

    await widgetTester.tap(fileButton);
    await widgetTester.pumpAndSettle();

    final saveButton = find.widgetWithText(MenuItemButton, 'Save');

    expect(saveButton, findsOneWidget);

    await widgetTester.tap(saveButton);
    await widgetTester.pumpAndSettle();

    expect(jsonString, preferences.getString(PrefKeys.layout));
  });

  testWidgets('Add widget dialog (widgets)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOnlineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

    expect(addWidget, findsOneWidget);
    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

    MenuItemButton addWidgetButton =
        addWidget.evaluate().first.widget as MenuItemButton;

    addWidgetButton.onPressed?.call();

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

    await widgetTester.drag(testValueTile, const Offset(100, 100),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(testValueContainer, findsNothing);

    await widgetTester.drag(testValueTile, const Offset(300, -150),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(testValueContainer, findsOneWidget);

    final dialogDragHandle = find.byIcon(Icons.drag_handle);

    expect(dialogDragHandle, findsOneWidget);

    await widgetTester.drag(dialogDragHandle, const Offset(100, 0));
    await widgetTester.pumpAndSettle();
  });

  testWidgets('Add widget dialog (layouts)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOnlineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

    expect(addWidget, findsOneWidget);
    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

    MenuItemButton addWidgetButton =
        addWidget.evaluate().first.widget as MenuItemButton;

    addWidgetButton.onPressed?.call();

    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsOneWidget);

    final layoutsTab = find.text('Layouts');
    expect(layoutsTab, findsOneWidget);

    await widgetTester.tap(layoutsTab);
    await widgetTester.pumpAndSettle();

    final listLayoutContainer =
        find.widgetWithText(WidgetContainer, 'List Layout');
    expect(listLayoutContainer, findsNothing);

    final listLayoutTile = find.widgetWithText(LayoutDragTile, 'List Layout');
    expect(listLayoutTile, findsOneWidget);

    await widgetTester.drag(listLayoutTile, const Offset(100, 100),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(listLayoutContainer, findsNothing);

    await widgetTester.drag(listLayoutTile, const Offset(300, -150),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(listLayoutContainer, findsOneWidget);
  });

  testWidgets('List Layouts', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOnlineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

    expect(addWidget, findsOneWidget);
    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

    MenuItemButton addWidgetButton =
        addWidget.evaluate().first.widget as MenuItemButton;

    addWidgetButton.onPressed?.call();

    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsOneWidget);

    final layoutsTab = find.text('Layouts');
    expect(layoutsTab, findsOneWidget);

    await widgetTester.tap(layoutsTab);
    await widgetTester.pumpAndSettle();

    final listLayoutContainer =
        find.widgetWithText(WidgetContainer, 'List Layout');
    expect(listLayoutContainer, findsNothing);

    final listLayoutTile = find.widgetWithText(LayoutDragTile, 'List Layout');
    expect(listLayoutTile, findsOneWidget);

    await widgetTester.drag(listLayoutTile, const Offset(100, 100),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(listLayoutContainer, findsNothing);

    await widgetTester.drag(listLayoutTile, const Offset(300, -150),
        kind: PointerDeviceKind.mouse);
    await widgetTester.pumpAndSettle();

    expect(listLayoutContainer, findsOneWidget);

    final closeButton = find.widgetWithText(TextButton, 'Close');
    expect(closeButton, findsOneWidget);

    await widgetTester.tap(closeButton);
    await widgetTester.pumpAndSettle();

    final listLayout = find.ancestor(
        of: find.widgetWithText(WidgetContainer, 'List Layout'),
        matching: find.byType(DraggableListLayout));
    expect(listLayout, findsOneWidget);

    final testBooleanContainer =
        find.widgetWithText(WidgetContainer, 'Test Boolean');
    expect(testBooleanContainer, findsOneWidget);

    final testBooleanInLayout = find.descendant(
        of: find.widgetWithText(WidgetContainer, 'List Layout'),
        matching: find.byType(BooleanBox));

    expect(testBooleanInLayout, findsNothing);

    // Drag into layout
    await widgetTester.timedDrag(testBooleanContainer, const Offset(250, 32),
        const Duration(milliseconds: 500));
    await widgetTester.pumpAndSettle();

    expect(testBooleanInLayout, findsOneWidget);

    // Drag out of layout
    await widgetTester.timedDrag(testBooleanInLayout, const Offset(-200, -60),
        const Duration(milliseconds: 500));
    await widgetTester.pumpAndSettle();

    expect(testBooleanInLayout, findsNothing);
  });

  testWidgets('Adding widgets from shuffleboard api', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    List<Function(NT4Topic topic)> fakeAnnounceCallbacks = [];

    // A custom mock is set up to reproduce behavior when actually running
    final mockNT4Connection = MockNTConnection();
    final mockNT4Client = MockNT4Client();
    final mockSubscription = MockNT4Subscription();

    when(mockNT4Connection.isNT4Connected).thenReturn(true);
    when(mockNT4Connection.connectionStatus())
        .thenAnswer((_) => Stream.value(true));
    when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

    when(mockSubscription.periodicStream())
        .thenAnswer((_) => Stream.value(null));

    when(mockNT4Client.addTopicAnnounceListener(any))
        .thenAnswer((realInvocation) {
      fakeAnnounceCallbacks.add(realInvocation.positionalArguments[0]);
    });

    when(mockNT4Connection.nt4Client).thenReturn(mockNT4Client);

    when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

    when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

    when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

    when(mockNT4Connection.subscribeAndRetrieveData<List<Object?>>(
            '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Number/Position'))
        .thenAnswer((realInvocation) => Future.value([2.0, 0.0]));

    when(mockNT4Connection.subscribeAndRetrieveData<List<Object?>>(
            '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Number/Size'))
        .thenAnswer((realInvocation) => Future.value([2.0, 2.0]));

    when(mockNT4Connection.subscribeAndRetrieveData<List<Object?>>(
            '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Layout/Position'))
        .thenAnswer((realInvocation) => Future.value([0.0, 0.0]));

    when(mockNT4Connection.subscribeAndRetrieveData<List<Object?>>(
            '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Layout/Size'))
        .thenAnswer((realInvocation) => Future.value([2.0, 3.0]));

    when(mockNT4Connection.subscribeAndRetrieveData<String?>(
            '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Layout/PreferredComponent'))
        .thenAnswer((realInvocation) => Future.value('List Layout'));

    when(mockNT4Connection.subscribeAndRetrieveData<String?>(
            '/Shuffleboard/Test-Tab/Shuffleboard Test Layout/.type'))
        .thenAnswer((realInvocation) => Future.value('ShuffleboardLayout'));

    NTConnection.instance = mockNT4Connection;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    await widgetTester.runAsync(() async {
      for (final callback in fakeAnnounceCallbacks) {
        callback.call(NT4Topic(
          name:
              '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Number/Position',
          type: NT4TypeStr.kFloat32Arr,
          properties: {},
        ));
        callback.call(NT4Topic(
          name:
              '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Number/Size',
          type: NT4TypeStr.kFloat32Arr,
          properties: {},
        ));
        callback.call(NT4Topic(
          name: '/Shuffleboard/Test-Tab/Shuffleboard Test Number',
          type: NT4TypeStr.kInt,
          properties: {},
        ));

        callback.call(NT4Topic(
          name:
              '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Layout/Position',
          type: NT4TypeStr.kFloat32Arr,
          properties: {},
        ));
        callback.call(NT4Topic(
          name:
              '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Layout/Size',
          type: NT4TypeStr.kFloat32Arr,
          properties: {},
        ));
        callback.call(NT4Topic(
          name:
              '/Shuffleboard/.metadata/Test-Tab/Shuffleboard Test Layout/PreferredComponent',
          type: NT4TypeStr.kString,
          properties: {},
        ));
        callback.call(NT4Topic(
          name: '/Shuffleboard/Test-Tab/Shuffleboard Test Layout',
          type: NT4TypeStr.kInt,
          properties: {},
        ));
      }

      // Gives enough time for the widgets to be placed automatically
      // It has to be done this way since the listener runs the functions asynchronously
      await Future.delayed(const Duration(seconds: 3));
    });

    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(AnimatedContainer, 'Test-Tab'), findsOneWidget);
    expect(
        find.widgetWithText(WidgetContainer, 'Shuffleboard Test Number',
            skipOffstage: false),
        findsOneWidget);
    expect(
        find.widgetWithText(WidgetContainer, 'Shuffleboard Test Layout',
            skipOffstage: false),
        findsOneWidget);
    expect(find.bySubtype<DraggableListLayout>(skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('About dialog', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final helpButton = find.widgetWithText(SubmenuButton, 'Help');

    expect(helpButton, findsOneWidget);

    await widgetTester.tap(helpButton);
    await widgetTester.pumpAndSettle();

    final showAboutDialogButton = find.widgetWithText(MenuItemButton, 'About');

    expect(showAboutDialogButton, findsOneWidget);

    await widgetTester.tap(showAboutDialogButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AboutDialog), findsOneWidget);
  });

  testWidgets('Changing tabs', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
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
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

    expect(find.byType(EditableTabBar), findsOneWidget);

    final createNewTabButton = find.descendant(
        of: find.byType(EditableTabBar), matching: find.byIcon(Icons.add));

    expect(createNewTabButton, findsOneWidget);

    await widgetTester.tap(createNewTabButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(3));
  });

  testWidgets('Closing tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

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

    expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(1));
  });

  testWidgets('Reordering tabs', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

    final editableTabBar = find.byType(EditableTabBar);

    expect(editableTabBar, findsOneWidget);

    final tabLeftButton =
        find.descendant(of: editableTabBar, matching: find.byIcon(Icons.west));
    final tabRightButton =
        find.descendant(of: editableTabBar, matching: find.byIcon(Icons.east));

    expect(tabLeftButton, findsOneWidget);
    expect(tabRightButton, findsOneWidget);

    editableTabBarWidget() =>
        (editableTabBar.evaluate().first.widget as EditableTabBar);

    expect(editableTabBarWidget().currentIndex, 0);

    await widgetTester.tap(tabLeftButton);
    await widgetTester.pumpAndSettle();

    expect(editableTabBarWidget().currentIndex, 0,
        reason: 'Tab index should not change since index is 0');

    await widgetTester.tap(tabRightButton);
    await widgetTester.pumpAndSettle();

    expect(editableTabBarWidget().currentIndex, 1);

    await widgetTester.tap(tabRightButton);
    await widgetTester.pumpAndSettle();

    expect(editableTabBarWidget().currentIndex, 1,
        reason:
            'Tab index should not change since index is equal to number of tabs');

    await widgetTester.tap(tabLeftButton);
    await widgetTester.pumpAndSettle();

    expect(editableTabBarWidget().currentIndex, 0);
  });

  testWidgets('Renaming tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final teleopTab = find.widgetWithText(AnimatedContainer, 'Teleoperated');

    expect(teleopTab, findsOneWidget);

    await widgetTester.tap(teleopTab, buttons: kSecondaryButton);
    await widgetTester.pumpAndSettle();

    final renameButton = find.text('Rename');

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
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final minimizeButton = find.ancestor(
        of: find.byType(DecoratedMinimizeButton),
        matching: find.byType(InkWell));

    expect(minimizeButton, findsOneWidget);

    await widgetTester.tap(minimizeButton);
  });

  testWidgets('Maximizing/unmaximizing window', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final appBar = find.byType(CustomAppBar);

    expect(appBar, findsOneWidget);

    await widgetTester.tapAt(const Offset(250, 0));
    await widgetTester.pump(kDoubleTapMinTime);
    await widgetTester.tapAt(const Offset(250, 0));

    await widgetTester.pumpAndSettle();

    final maximizeButton = find.ancestor(
        of: find.byType(DecoratedMaximizeButton),
        matching: find.byType(InkWell));

    await widgetTester.tap(maximizeButton);
  });

  testWidgets('Closing window (All changes saved)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final gyroWidget = find.widgetWithText(WidgetContainer, 'Test Gyro');

    expect(gyroWidget, findsOneWidget);

    // Drag to a location
    await widgetTester.drag(gyroWidget, const Offset(256, -128));
    await widgetTester.pumpAndSettle();

    // Drag back to its original location
    await widgetTester.drag(gyroWidget, const Offset(-256, 128));
    await widgetTester.pumpAndSettle();

    final closeButton = find.ancestor(
        of: find.byType(DecoratedCloseButton), matching: find.byType(InkWell));

    await widgetTester.tap(closeButton);
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, 'Unsaved Changes'), findsNothing);
  });

  testWidgets('Closing window (Unsaved changes)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final gyroWidget = find.widgetWithText(WidgetContainer, 'Test Gyro');

    expect(gyroWidget, findsOneWidget);

    // Drag to a location
    await widgetTester.drag(gyroWidget, const Offset(256, -128));

    await widgetTester.pumpAndSettle();

    final closeButton = find.ancestor(
        of: find.byType(DecoratedCloseButton), matching: find.byType(InkWell));

    expect(closeButton, findsOneWidget);

    await widgetTester.tap(closeButton);
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, 'Unsaved Changes'), findsOneWidget);

    final discardButton = find.widgetWithText(TextButton, 'Discard');

    expect(discardButton, findsOneWidget);

    await widgetTester.tap(discardButton);
    await widgetTester.pumpAndSettle();
  });

  testWidgets('Opening settings', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          preferences: preferences,
          version: '0.0.0.0',
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
