import 'dart:convert';
import 'dart:io';

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/widgets/dashboard_grid.dart';
import 'package:elastic_dashboard/widgets/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/single_topic/text_display.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockOfflineNT4();

  testWidgets('Dashboard grid loading', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;
    // WidgetController.hitTestWarningShouldBeFatal = true;

    await FieldImages.loadFields('assets/fields/');

    String filePath =
        '${Directory.current.path}/test_resources/test-layout.json';

    String jsonString = File(filePath).readAsStringSync();

    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    expect(jsonData.containsKey('tabs'), true);

    expect(jsonData['tabs'][0].containsValue('Teleoperated'), true);
    expect(jsonData['tabs'][0].containsKey('grid_layout'), true);

    expect(jsonData['tabs'][1].containsValue('Autonomous'), true);
    expect(jsonData['tabs'][1].containsKey('grid_layout'), true);

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (context) => DashboardGridModel(),
            child: DashboardGrid.fromJson(
                jsonData: jsonData['tabs'][0]['grid_layout']),
          ),
        ),
      ),
    );

    await widgetTester.pump(Duration.zero);

    // await widgetTester.pumpAndSettle();

    expect(find.bySubtype<DraggableWidgetContainer>(), findsNWidgets(6));
    expect(find.bySubtype<NT4Widget>(), findsNWidgets(6));

    expect(find.bySubtype<TextDisplay>(), findsOneWidget);
    expect(find.bySubtype<BooleanBox>(), findsOneWidget);
    expect(find.bySubtype<FieldWidget>(), findsOneWidget);
    expect(find.bySubtype<PowerDistribution>(), findsOneWidget);
    expect(find.bySubtype<Gyro>(), findsOneWidget);
    expect(find.bySubtype<PIDControllerWidget>(), findsOneWidget);

    await widgetTester.ensureVisible(find.text('Test Number'));

    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Test Number'),
        buttons: kSecondaryMouseButton);

    await widgetTester.pumpAndSettle();

    expect(
        find.text('Test Number', skipOffstage: false), findsAtLeastNWidgets(2));
    expect(find.text('Edit Properties', skipOffstage: false), findsOneWidget);
  });
}
