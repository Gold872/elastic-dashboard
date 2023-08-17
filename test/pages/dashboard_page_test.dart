import 'dart:io';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_util.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await FieldImages.loadFields('assets/fields/');

  String jsonFilePath =
      '${Directory.current.path}/test_resources/test-layout.json';

  String jsonString = File(jsonFilePath).readAsStringSync();

  testWidgets('Dashboard page offline', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOfflineNT4();

    SharedPreferences.setMockInitialValues({
      'layout': jsonString,
      PrefKeys.teamNumber: 353,
      PrefKeys.ipAddress: '10.3.53.2',
    });

    final preferences = await SharedPreferences.getInstance();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
              connectionStream: Stream.value(false), preferences: preferences),
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

  testWidgets('Dashboard page online', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    setupMockOnlineNT4();

    SharedPreferences.setMockInitialValues({
      'layout': jsonString,
      PrefKeys.teamNumber: 353,
      PrefKeys.ipAddress: '10.3.53.2',
    });

    final preferences = await SharedPreferences.getInstance();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
              connectionStream: Stream.value(true), preferences: preferences),
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
}
