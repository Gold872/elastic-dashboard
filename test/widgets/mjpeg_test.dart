import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import '../test_util.dart';
import '../test_util.mocks.dart';

Client createStreamClient([
  Map<String, StreamedResponse> mockRequests = const {},
]) {
  MockClient mockClient = MockClient();

  when(mockClient.send(any)).thenAnswer((invocation) {
    Request request = invocation.positionalArguments[0];

    if (mockRequests.containsKey(request.url.toString())) {
      return Future.value(mockRequests[request.url.toString()]);
    } else {
      // throw an exception by default
      throw ClientException('Connection attempt cancelled');
    }
  });

  return mockClient;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
  });

  testWidgets('Connection times out', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    MjpegController controller = MjpegController.withMockClient(
      stream: 'http://10.0.0.2:1181/?action=stream',
      httpClient: createStreamClient(),
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Mjpeg(
            controller: controller,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
        find.text('Attempting to establish HTTP connection.'), findsOneWidget);

    await widgetTester.pump(const Duration(seconds: 5));

    // Let the connection time out
    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsNothing);
    expect(find.textContaining('Connection timed out'), findsOneWidget);

    controller.dispose();

    // Destroyes the visilibty detector and cancels its timers
    await widgetTester.pumpWidget(const Placeholder());
    await widgetTester
        .pump(VisibilityDetectorController.instance.updateInterval);
  });

  testWidgets('Return stream with error code', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    MjpegController controller = MjpegController.withMockClient(
      stream: 'http://10.0.0.2:1181/?action=stream',
      httpClient: createStreamClient({
        'http://10.0.0.2:1181/?action=stream': StreamedResponse(
          Stream.value([]),
          400,
          reasonPhrase: 'Placeholder error message',
        ),
      }),
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Mjpeg(
            controller: controller,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
        find.text('Attempting to establish HTTP connection.'), findsOneWidget);

    await widgetTester
        .pump(VisibilityDetectorController.instance.updateInterval);

    await widgetTester.pumpAndSettle();

    expect(controller.errorState.value, isNotNull);
    expect(find.byType(CustomLoadingIndicator), findsNothing);
    expect(
        find.textContaining(
            'Stream returned status code 400: "Placeholder error message"'),
        findsOneWidget);

    controller.dispose();

    // Destroyes the visilibty detector and cancels its timers
    await widgetTester.pumpWidget(const Placeholder());
    await widgetTester
        .pump(VisibilityDetectorController.instance.updateInterval);
  });

  testWidgets('Waiting for image in stream', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    MjpegController controller = MjpegController.withMockClient(
      stream: 'http://10.0.0.2:1181/?action=stream',
      httpClient: createStreamClient({
        'http://10.0.0.2:1181/?action=stream': StreamedResponse(
          Stream.value([]),
          200,
        ),
      }),
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Mjpeg(
            controller: controller,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
        find.text('Attempting to establish HTTP connection.'), findsOneWidget);

    await widgetTester
        .pump(VisibilityDetectorController.instance.updateInterval);

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(controller.errorState.value, isNull);

    expect(
        find.text(
            'Connection established but no data received.\nCamera may be disconnected from device.'),
        findsOneWidget);

    controller.dispose();

    // Destroyes the visilibty detector and cancels its timers
    await widgetTester.pumpWidget(const Placeholder());
    await widgetTester
        .pump(VisibilityDetectorController.instance.updateInterval);
  });
}
