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

  when(mockClient.send(any)).thenAnswer((invocation) async {
    Request request = invocation.positionalArguments[0];

    if (mockRequests.containsKey(request.url.toString())) {
      return Future.value(mockRequests[request.url.toString()]);
    } else {
      await Future<void>.delayed(Duration.zero);
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
      streams: ['http://10.0.0.2:1181/?action=stream'],
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
      streams: ['http://10.0.0.2:1181/?action=stream'],
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

  test('Cycles through invalid URLs', retry: 5, () async {
    MjpegController controller = MjpegController.withMockClient(
      streams: [
        'http://10.0.0.2:1181/?action=stream',
        'http://10.0.0.2:1182/?action=stream',
      ],
      timeout: const Duration(milliseconds: 100),
      httpClient: createStreamClient(),
    );

    // Trick the controller into being visible and start streaming
    final Key visibleKey = UniqueKey();
    controller.setMounted(visibleKey, true);
    controller.setVisible(visibleKey, true);

    expect(controller.errorState.value, isNull);
    expect(controller.cycleState, StreamCycleState.connecting);
    expect(controller.currentStreamIndex, 0);

    // Wait for the error to throw
    await Future<void>.delayed(Duration.zero);
    DateTime startTime = DateTime.now();

    expect(controller.errorState.value, isNotNull);
    expect(controller.cycleState, StreamCycleState.attemptReconnect);

    // Begins reconnect in 100 ms
    // Timing has to be very precise so any delays could throw it off
    await Future.delayed(
      startTime.difference(DateTime.now()) + const Duration(milliseconds: 100),
    );

    expect(
      controller.cycleState,
      StreamCycleState.connecting,
      reason: 'Waits 100 ms between reconnection and connection',
    );
    expect(controller.currentStreamIndex, 1);
    expect(controller.currentStream, 'http://10.0.0.2:1182/?action=stream');

    // Wait for the error to throw
    await Future<void>.delayed(Duration.zero);
    startTime = DateTime.now();

    expect(controller.errorState.value, isNotNull);
    expect(
      controller.cycleState,
      StreamCycleState.attemptReconnect,
      reason: 'Immediately retries connection after error',
    );
    expect(controller.currentStreamIndex, 1);
    expect(controller.currentStream, 'http://10.0.0.2:1182/?action=stream');

    // 100 ms timing has to be very precise
    await Future.delayed(
      startTime.difference(DateTime.now()) + const Duration(milliseconds: 100),
    );

    expect(controller.currentStreamIndex, 0);
    expect(controller.cycleState, StreamCycleState.connecting);
    expect(controller.currentStream, 'http://10.0.0.2:1181/?action=stream');

    controller.dispose();
  });

  testWidgets('Waiting for image in stream', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    MjpegController controller = MjpegController.withMockClient(
      streams: ['http://10.0.0.2:1181/?action=stream'],
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
