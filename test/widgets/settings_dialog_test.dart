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
          onColorChanged: (color) async {
            fakeSettings.changeColor();

            await preferences.setInt(PrefKeys.teamColor, color.value);
          },
          onIPAddressChanged: (data) async {
            fakeSettings.changeIPAddress();

            await preferences.setString(PrefKeys.ipAddress, data!);
          },
          onTeamNumberChanged: (data) async {
            fakeSettings.changeTeamNumber();

            await preferences.setInt(PrefKeys.teamNumber, int.parse(data!));
          },
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

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Team Number'), findsOneWidget);
    expect(find.text('Team Color'), findsOneWidget);
    expect(find.text('Use Team # for IP'), findsOneWidget);
    expect(find.text('IP Address'), findsOneWidget);
  });

  testWidgets('Change team number', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SettingsDialog(
          onColorChanged: (color) async {
            fakeSettings.changeColor();

            await preferences.setInt(PrefKeys.teamColor, color.value);
          },
          onIPAddressChanged: (data) async {
            fakeSettings.changeIPAddress();

            await preferences.setString(PrefKeys.ipAddress, data!);
          },
          onTeamNumberChanged: (data) async {
            fakeSettings.changeTeamNumber();

            await preferences.setInt(PrefKeys.teamNumber, int.parse(data!));
          },
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
          onIPAddressChanged: (data) async {
            fakeSettings.changeIPAddress();

            await preferences.setString(PrefKeys.ipAddress, data!);
          },
          onTeamNumberChanged: (data) async {
            fakeSettings.changeTeamNumber();

            await preferences.setInt(PrefKeys.teamNumber, int.parse(data!));
          },
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
          onColorChanged: (color) async {
            fakeSettings.changeColor();

            await preferences.setInt(PrefKeys.teamColor, color.value);
          },
          onIPAddressChanged: (data) async {
            fakeSettings.changeIPAddress();

            await preferences.setString(PrefKeys.ipAddress, data!);
          },
          onTeamNumberChanged: (data) async {
            fakeSettings.changeTeamNumber();

            await preferences.setInt(PrefKeys.teamNumber, int.parse(data!));
          },
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

    final ipSwitch = find.byType(DialogToggleSwitch);

    expect(ipSwitch, findsOneWidget);

    await widgetTester.tap(ipSwitch);

    await widgetTester.pumpAndSettle();

    expect(preferences.getBool(PrefKeys.useTeamNumberForIP), true);
    expect(preferences.getString(PrefKeys.ipAddress), '10.26.01.2');

    await widgetTester.tap(find.byType(DialogToggleSwitch));

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
          onColorChanged: (color) async {
            fakeSettings.changeColor();

            await preferences.setInt(PrefKeys.teamColor, color.value);
          },
          onIPAddressChanged: (data) async {
            fakeSettings.changeIPAddress();

            await preferences.setString(PrefKeys.ipAddress, data!);
          },
          onTeamNumberChanged: (data) async {
            fakeSettings.changeTeamNumber();

            await preferences.setInt(PrefKeys.teamNumber, int.parse(data!));
          },
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

    final ipAddressField = find.widgetWithText(DialogTextInput, 'IP Address');

    expect(ipAddressField, findsOneWidget);

    await widgetTester.enterText(ipAddressField, '10.3.53.2');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump();

    expect(preferences.getString(PrefKeys.ipAddress), '10.3.53.2');
    verify(fakeSettings.changeIPAddress()).called(greaterThanOrEqualTo(1));
  });
}
