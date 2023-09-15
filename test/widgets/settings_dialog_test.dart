import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_util.dart';
import 'settings_dialog_test.mocks.dart';

@GenerateNiceMocks([MockSpec<FakeSettingsMethods>()])
class FakeSettingsMethods {
  void changeColor() {}

  void changeIPAddress() {}

  void changeTeamNumber() {}

  void changeAutoTeamIP() {}

  void changeShowGrid() {}

  void changeGridSize() {}

  void changeCornerRadius() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late MockFakeSettingsMethods fakeSettings;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.ipAddress: '127.0.0.1',
      PrefKeys.teamNumber: 353,
      PrefKeys.useTeamNumberForIP: false,
      PrefKeys.teamColor: Colors.blueAccent.value,
      PrefKeys.showGrid: false,
      PrefKeys.gridSize: 128,
      PrefKeys.cornerRadius: 15.0,
    });

    preferences = await SharedPreferences.getInstance();

    fakeSettings = MockFakeSettingsMethods();
  });

  setUp(() {
    reset(fakeSettings);
  });

  testWidgets('Settings Dialog', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Team Number'), findsOneWidget);
    expect(find.text('Team Color'), findsOneWidget);
    expect(find.text('Use Team # for IP'), findsOneWidget);
    expect(find.text('IP Address'), findsOneWidget);
    expect(find.text('Show Grid'), findsWidgets);
    expect(find.text('Grid Size'), findsWidgets);
    expect(find.text('Corner Radius'), findsOneWidget);

    final closeButton = find.widgetWithText(TextButton, 'Close');

    expect(closeButton, findsOneWidget);

    await widgetTester.tap(closeButton);
    await widgetTester.pumpAndSettle();
  });

  testWidgets('Change team number', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onTeamNumberChanged: (data) async {
            fakeSettings.changeTeamNumber();

            await preferences.setInt(PrefKeys.teamNumber, int.parse(data!));
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final teamNumberField = find.widgetWithText(DialogTextInput, 'Team Number');

    expect(teamNumberField, findsOneWidget);
    expect(find.descendant(of: teamNumberField, matching: find.text('353')),
        findsOneWidget);

    await widgetTester.enterText(teamNumberField, '2601');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(preferences.getInt(PrefKeys.teamNumber), 2601);
    expect(preferences.getString(PrefKeys.ipAddress), '127.0.0.1');
    verify(fakeSettings.changeTeamNumber()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Change team color', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onColorChanged: (color) async {
            fakeSettings.changeColor();

            await preferences.setInt(PrefKeys.teamColor, color.value);
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final teamColorBox = find.byType(DialogColorPicker);

    expect(teamColorBox, findsOneWidget);

    final teamColorButton = find.byType(ElevatedButton);

    expect(teamColorButton, findsOneWidget);

    // For some reason the widgetTester.tap() won't work...
    ElevatedButton elevatedColorButton =
        teamColorButton.evaluate().first.widget as ElevatedButton;

    elevatedColorButton.onPressed?.call();

    await widgetTester.pumpAndSettle();

    expect(find.text('Select Color', skipOffstage: false), findsOneWidget);
    expect(find.byType(ColorPicker), findsOneWidget);

    final hexInput = find.widgetWithText(TextField, 'Hex Code');

    expect(hexInput, findsOneWidget);

    await widgetTester.enterText(hexInput, '0000FF');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    final saveButton = find.text('Save');

    expect(saveButton, findsOneWidget);
    await widgetTester.tap(saveButton);

    expect(preferences.getInt(PrefKeys.teamColor),
        const Color.fromARGB(255, 0, 0, 255).value);
    verify(fakeSettings.changeColor()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Change auto team number IP', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onUseTeamNumberToggle: (value) async {
            fakeSettings.changeAutoTeamIP();

            await preferences.setBool(PrefKeys.useTeamNumberForIP, value);

            if (value) {
              await preferences.setString(
                  PrefKeys.ipAddress,
                  IPAddressUtil.teamNumberToIP(
                      preferences.getInt(PrefKeys.teamNumber)!));
            }
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final ipSwitch = find.descendant(
        of: find.widgetWithText(DialogToggleSwitch, 'Use Team # for IP'),
        matching: find.byType(Switch));

    expect(ipSwitch, findsOneWidget);

    await widgetTester.tap(ipSwitch);
    await widgetTester.pumpAndSettle();

    expect(preferences.getBool(PrefKeys.useTeamNumberForIP), true);
    expect(preferences.getString(PrefKeys.ipAddress), '10.26.01.2');

    await widgetTester.tap(ipSwitch);

    await widgetTester.pumpAndSettle();

    verify(fakeSettings.changeAutoTeamIP()).called(2);
    expect(preferences.getBool(PrefKeys.useTeamNumberForIP), false);
    expect(preferences.getString(PrefKeys.ipAddress), '10.26.01.2');
  });

  testWidgets('Change IP address', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onIPAddressChanged: (data) async {
            fakeSettings.changeIPAddress();

            await preferences.setString(PrefKeys.ipAddress, data!);
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final ipAddressField = find.widgetWithText(DialogTextInput, 'IP Address');

    expect(ipAddressField, findsOneWidget);

    await widgetTester.enterText(ipAddressField, '10.3.53.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(preferences.getString(PrefKeys.ipAddress), '10.3.53.2');
    verify(fakeSettings.changeIPAddress()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Toggle grid', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onGridToggle: (value) async {
            fakeSettings.changeShowGrid();

            await preferences.setBool(PrefKeys.showGrid, value);
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final gridSwitch = find.widgetWithText(DialogToggleSwitch, 'Show Grid');

    expect(gridSwitch, findsOneWidget);

    // Widget tester.tap will not work for some reason
    final switchWidget = find
        .descendant(of: gridSwitch, matching: find.byType(Switch))
        .evaluate()
        .first
        .widget as Switch;

    switchWidget.onChanged?.call(true);
    await widgetTester.pumpAndSettle();

    expect(preferences.getBool(PrefKeys.showGrid), true);

    switchWidget.onChanged?.call(false);
    await widgetTester.pumpAndSettle();

    expect(preferences.getBool(PrefKeys.showGrid), false);
    verify(fakeSettings.changeShowGrid()).called(2);
  });

  testWidgets('Change grid size', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onGridSizeChanged: (gridSize) async {
            fakeSettings.changeGridSize();

            await preferences.setInt(PrefKeys.gridSize, int.parse(gridSize!));
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final gridSizeField = find.widgetWithText(DialogTextInput, 'Grid Size');

    expect(gridSizeField, findsOneWidget);

    await widgetTester.enterText(gridSizeField, '64');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(preferences.getInt(PrefKeys.gridSize), 64);
    verify(fakeSettings.changeGridSize()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Change corner radius', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onCornerRadiusChanged: (radius) async {
            fakeSettings.changeCornerRadius();

            await preferences.setDouble(
                PrefKeys.cornerRadius, double.parse(radius!));
          },
          preferences: preferences,
        ),
      ),
    ));

    await widgetTester.pumpAndSettle();

    final cornerRadiusField =
        find.widgetWithText(DialogTextInput, 'Corner Radius');

    expect(cornerRadiusField, findsOneWidget);

    await widgetTester.enterText(cornerRadiusField, '25.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(preferences.getDouble(PrefKeys.cornerRadius), 25.0);
    verify(fakeSettings.changeCornerRadius()).called(greaterThanOrEqualTo(1));
  });
}
