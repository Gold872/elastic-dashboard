import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> fmsInfoJson = {
    'topic': 'Test/FMSInfo',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  NTConnection createNTConnection({
    String eventName = '',
    bool redAlliance = false,
    int matchNumber = 0,
    int matchType = 0,
    int replayNumber = 0,
    bool enabled = false,
    bool auto = false,
    bool test = false,
    bool estop = false,
    bool fmsAttached = false,
    bool dsAttached = false,
  }) {
    int fmsControlData = 0;
    if (enabled) {
      fmsControlData |= FMSInfo.ENABLED_FLAG;
    }
    if (auto) {
      fmsControlData |= FMSInfo.AUTO_FLAG;
    }
    if (test) {
      fmsControlData |= FMSInfo.TEST_FLAG;
    }
    if (estop) {
      fmsControlData |= FMSInfo.EMERGENCY_STOP_FLAG;
    }
    if (fmsAttached) {
      fmsControlData |= FMSInfo.FMS_ATTACHED_FLAG;
    }
    if (dsAttached) {
      fmsControlData |= FMSInfo.DS_ATTACHED_FLAG;
    }

    return createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/FMSInfo/EventName',
          type: NT4TypeStr.kString,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/FMSInfo/FMSControlData',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/FMSInfo/IsRedAlliance',
          type: NT4TypeStr.kBool,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/FMSInfo/MatchNumber',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/FMSInfo/MatchType',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
        NT4Topic(
          name: 'Test/FMSInfo/ReplayNumber',
          type: NT4TypeStr.kInt,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/FMSInfo/EventName': eventName,
        'Test/FMSInfo/FMSControlData': fmsControlData,
        'Test/FMSInfo/IsRedAlliance': redAlliance,
        'Test/FMSInfo/MatchNumber': matchNumber,
        'Test/FMSInfo/MatchType': matchType,
        'Test/FMSInfo/ReplayNumber': replayNumber,
      },
    );
  }

  Future<void> pushFMSInfoWidget(
      WidgetTester widgetTester, NTConnection ntConnection) async {
    NTWidgetModel fmsInfoModel = NTWidgetBuilder.buildNTModelFromJson(
        ntConnection, preferences, 'FMSInfo', fmsInfoJson);

    return widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: fmsInfoModel,
            child: const FMSInfo(),
          ),
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createNTConnection(
      eventName: 'CMPTX',
      redAlliance: false,
      matchNumber: 15,
      matchType: 3,
      replayNumber: 1,
      enabled: true,
      fmsAttached: true,
      dsAttached: true,
    );
  });

  test('FMSInfo from json', () {
    NTWidgetModel fmsInfoModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'FMSInfo',
      fmsInfoJson,
    );

    expect(fmsInfoModel.type, 'FMSInfo');
    expect(fmsInfoModel.runtimeType, FMSInfoModel);
  });

  test('FMSInfo to json', () {
    FMSInfoModel fmsInfoModel = FMSInfoModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/FMSInfo',
      period: 0.100,
    );

    expect(fmsInfoModel.toJson(), fmsInfoJson);
  });

  testWidgets('FMSInfo CMPTX E15, Teleop Enabled', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushFMSInfoWidget(widgetTester, ntConnection);

    await widgetTester.pumpAndSettle();

    expect(find.text('CMPTX Elimination match 15 (replay 1)'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    expect(find.text('Robot State: Teleoperated'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue.shade900),
        findsOneWidget);
  });

  testWidgets('FMSInfo NYSU Q72, Auto Enabled', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushFMSInfoWidget(
        widgetTester,
        createNTConnection(
          eventName: 'NYSU',
          redAlliance: false,
          matchNumber: 72,
          matchType: 2,
          replayNumber: 1,
          enabled: true,
          auto: true,
          fmsAttached: true,
          dsAttached: true,
        ));

    await widgetTester.pumpAndSettle();

    expect(find.text('NYSU Qualification match 72 (replay 1)'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    expect(find.text('Robot State: Autonomous'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.blue.shade900),
        findsOneWidget);
  });

  testWidgets('FMSInfo NYLI2 P7, Estopped', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushFMSInfoWidget(
        widgetTester,
        createNTConnection(
          eventName: 'NYLI2',
          redAlliance: true,
          matchNumber: 7,
          matchType: 1,
          replayNumber: 1,
          estop: true,
          fmsAttached: true,
          dsAttached: true,
        ));

    await widgetTester.pumpAndSettle();

    expect(find.text('NYLI2 Practice match 7 (replay 1)'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Connected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    expect(find.text('EMERGENCY STOPPED'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red.shade900),
        findsOneWidget);
  });

  testWidgets('FMSInfo Unkown Match, test enabled', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushFMSInfoWidget(
        widgetTester,
        createNTConnection(
          eventName: '',
          redAlliance: true,
          matchNumber: 0,
          matchType: 0,
          replayNumber: 0,
          enabled: true,
          test: true,
          fmsAttached: false,
          dsAttached: true,
        ));

    await widgetTester.pumpAndSettle();

    expect(find.text('Unknown match 0'), findsOneWidget);
    expect(find.text('DriverStation Connected'), findsOneWidget);
    expect(find.text('FMS Disconnected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(1));
    expect(find.byIcon(Icons.clear), findsNWidgets(1));

    expect(find.text('Robot State: Test'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red.shade900),
        findsOneWidget);
  });

  testWidgets('FMSInfo Unknown Match, everything disconnected',
      (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pushFMSInfoWidget(
        widgetTester,
        createNTConnection(
          eventName: '',
          redAlliance: true,
          matchNumber: 0,
          matchType: 0,
          replayNumber: 0,
        ));

    await widgetTester.pumpAndSettle();

    expect(find.text('Unknown match 0'), findsOneWidget);
    expect(find.text('DriverStation Disconnected'), findsOneWidget);
    expect(find.text('FMS Disconnected'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(0));
    expect(find.byIcon(Icons.clear), findsNWidgets(2));

    expect(find.text('Robot State: Disabled'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red.shade900),
        findsOneWidget);
  });
}
