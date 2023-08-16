import 'dart:io';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockOfflineNT4();
  testWidgets('Dashboard page', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await FieldImages.loadFields('assets/fields/');

    String filePath =
        '${Directory.current.path}/test_resources/test-layout.json';

    String jsonString = File(filePath).readAsStringSync();

    SharedPreferences.setMockInitialValues({
      'layout': jsonString,
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

    await widgetTester.pump(Duration.zero);

    await widgetTester.pumpAndSettle();

    expect(find.text('Network Tables: Disconnected'), findsOneWidget);

    expect(find.text('Teleoperated'), findsOneWidget);
    expect(find.text('Autonomous'), findsOneWidget);
  });
}
