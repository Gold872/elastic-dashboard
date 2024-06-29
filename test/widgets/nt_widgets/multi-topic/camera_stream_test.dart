import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> cameraStreamJson = {
    'topic': 'Test/Camera Stream',
    'period': 0.100,
    'compression': 50,
    'fps': 60,
    'resolution': [100.0, 100.0],
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('Camera stream from json', () {
    NTWidgetModel cameraStreamModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Camera Stream',
      cameraStreamJson,
    );

    expect(cameraStreamModel.type, 'Camera Stream');
    expect(cameraStreamModel.runtimeType, CameraStreamModel);

    if (cameraStreamModel is! CameraStreamModel) {
      return;
    }

    expect(cameraStreamModel.fps, 60);
    expect(cameraStreamModel.quality, 50);
    expect(cameraStreamModel.resolution, const Size(100.0, 100.0));

    expect(cameraStreamModel.getUrlWithParameters('0.0.0.0'),
        '0.0.0.0?resolution=100x100&fps=60&compression=50');

    cameraStreamModel.fps = null;

    expect(cameraStreamModel.getUrlWithParameters('0.0.0.0'),
        '0.0.0.0?resolution=100x100&compression=50');

    cameraStreamModel.resolution = const Size(0.0, 100);

    expect(cameraStreamModel.getUrlWithParameters('0.0.0.0'),
        '0.0.0.0?compression=50');

    cameraStreamModel.quality = null;

    expect(cameraStreamModel.getUrlWithParameters('0.0.0.0'), '0.0.0.0?');
  });

  test('Camera stream to json', () {
    CameraStreamModel cameraStreamModel = CameraStreamModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Camera Stream',
      period: 0.100,
      compression: 50,
      fps: 60,
      resolution: const Size(100.0, 100.0),
    );

    expect(cameraStreamModel.toJson(), cameraStreamJson);
  });

  testWidgets('Camera stream online widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel cameraStreamModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Camera Stream',
      cameraStreamJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: cameraStreamModel,
            child: const CameraStreamWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
        find.text('Waiting for Camera Stream connection...'), findsOneWidget);
  });

  testWidgets('Camera stream offline widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel cameraStreamModel = NTWidgetBuilder.buildNTModelFromJson(
      createMockOfflineNT4(),
      preferences,
      'Camera Stream',
      cameraStreamJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: cameraStreamModel,
            child: const CameraStreamWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
        find.text('Waiting for Network Tables connection...'), findsOneWidget);
  });
}
