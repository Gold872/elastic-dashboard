import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'test_util.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NTConnection>(),
  MockSpec<NT4Client>(),
  MockSpec<NT4Subscription>()
])
MockNTConnection createMockOfflineNT4() {
  HttpOverrides.global = null;

  final mockNT4Connection = MockNTConnection();
  final mockSubscription = MockNT4Subscription();

  when(mockNT4Connection.announcedTopics()).thenReturn({});

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockSubscription.listen(any)).thenAnswer((realInvocation) {});

  when(mockNT4Connection.isNT4Connected).thenReturn(false);

  when(mockNT4Connection.serverTime).thenReturn(0);

  when(mockNT4Connection.connectionStatus())
      .thenAnswer((_) => Stream.value(false));

  when(mockNT4Connection.dsConnectionStatus())
      .thenAnswer((_) => Stream.value(false));

  when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribeAll(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.getTopicFromName(any)).thenReturn(null);

  return mockNT4Connection;
}

MockNTConnection createMockOnlineNT4({
  List<NT4Topic>? virtualTopics,
  Map<String, dynamic>? virtualValues,
  int serverTime = 0,
}) {
  HttpOverrides.global = null;

  final mockNT4Connection = MockNTConnection();
  final mockSubscription = MockNT4Subscription();

  virtualTopics ??= [
    NT4Topic(
      name: '/SmartDashboard/Test Value 1',
      type: NT4TypeStr.kInt,
      properties: {},
    ),
    NT4Topic(
      name: '/SmartDashboard/Test Value 2',
      type: NT4TypeStr.kFloat32,
      properties: {},
    ),
  ];

  virtualValues ??= {};

  Map<int, NT4Topic> virtualTopicsMap = {};

  List<Function(Object?, int)> subscriptionListeners = [];

  for (int i = 0; i < virtualTopics.length; i++) {
    virtualTopicsMap.addAll({i + 1: virtualTopics[i]});
  }

  when(mockNT4Connection.announcedTopics()).thenReturn(virtualTopicsMap);

  when(mockNT4Connection.addTopicAnnounceListener(any))
      .thenAnswer((realInvocation) {
    if (virtualTopics == null) {
      return;
    }
    for (NT4Topic topic in virtualTopics) {
      realInvocation.positionalArguments[0].call(topic);
    }
  });

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockSubscription.listen(any)).thenAnswer((realInvocation) {});

  when(mockNT4Connection.isNT4Connected).thenReturn(true);

  when(mockNT4Connection.serverTime).thenReturn(serverTime);

  when(mockNT4Connection.connectionStatus())
      .thenAnswer((_) => Stream.value(true));

  when(mockNT4Connection.dsConnectionStatus())
      .thenAnswer((_) => Stream.value(true));

  when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribeAll(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.getTopicFromName(any)).thenReturn(null);

  when(mockNT4Connection.publishNewTopic(any, any)).thenAnswer((invocation) {
    NT4Topic newTopic = NT4Topic(
        name: invocation.positionalArguments[0],
        type: invocation.positionalArguments[1],
        properties: {});

    virtualTopicsMap[virtualTopicsMap.length] = newTopic;
    return newTopic;
  });

  when(mockNT4Connection.updateDataFromTopic(any, any))
      .thenAnswer((invocation) {
    NT4Topic topic = invocation.positionalArguments[0];
    Object? data = invocation.positionalArguments[1];

    virtualValues![topic.name] = data;
  });

  when(mockNT4Connection.updateDataFromTopicName(any, any))
      .thenAnswer((invocation) {
    String topic = invocation.positionalArguments[0];
    Object? data = invocation.positionalArguments[1];

    virtualValues![topic] = data;
  });

  for (NT4Topic topic in virtualTopics) {
    MockNT4Subscription topicSubscription = MockNT4Subscription();

    when(mockNT4Connection.getTopicFromName(topic.name)).thenReturn(topic);

    when(topicSubscription.periodicStream(yieldAll: anyNamed('yieldAll')))
        .thenAnswer((_) => Stream.value(virtualValues?[topic.name]));

    when(topicSubscription.listen(any)).thenAnswer((realInvocation) {
      subscriptionListeners.add(realInvocation.positionalArguments[0]);
    });

    when(topicSubscription.updateValue(any, any)).thenAnswer(
      (invoc) {
        for (var value in subscriptionListeners) {
          value.call(
              invoc.positionalArguments[0], invoc.positionalArguments[1]);
        }
      },
    );

    when(mockNT4Connection.getLastAnnouncedValue(topic.name))
        .thenAnswer((_) => virtualValues?[topic.name]);

    when(mockNT4Connection.subscribe(topic.name, any))
        .thenReturn(topicSubscription);

    when(mockNT4Connection.subscribeAll(topic.name, any))
        .thenReturn(topicSubscription);
  }

  return mockNT4Connection;
}

void ignoreOverflowErrors(
  FlutterErrorDetails details, {
  bool forceReport = false,
}) {
  // ---

  bool ifIsOverflowError = false;
  bool isUnableToLoadAsset = false;

  // Detect overflow error.
  var exception = details.exception;
  if (exception is FlutterError) {
    ifIsOverflowError = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('A RenderFlex overflowed by'),
    );
    isUnableToLoadAsset = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('Unable to load asset'),
    );
  }

  // Ignore if is overflow error.
  if (ifIsOverflowError || isUnableToLoadAsset) {
    return;
  } else {
    FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
    // exit(1);
  }
}
