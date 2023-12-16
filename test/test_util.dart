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
void setupMockOfflineNT4() {
  HttpOverrides.global = null;

  final mockNT4Connection = MockNTConnection();
  final mockNT4Client = MockNT4Client();
  final mockSubscription = MockNT4Subscription();

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockNT4Connection.nt4Client).thenReturn(mockNT4Client);

  when(mockNT4Connection.isNT4Connected).thenReturn(false);

  when(mockNT4Connection.connectionStatus())
      .thenAnswer((_) => Stream.value(false));

  when(mockNT4Connection.dsConnectionStatus())
      .thenAnswer((_) => Stream.value(false));

  when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT4Connection.getTopicFromName(any))
      .thenReturn(NT4Topic(name: '', type: NT4TypeStr.kString, properties: {}));

  NTConnection.instance = mockNT4Connection;
}

void setupMockOnlineNT4() {
  HttpOverrides.global = null;

  final mockNT4Connection = MockNTConnection();
  final mockNT4Client = MockNT4Client();
  final mockSubscription = MockNT4Subscription();

  when(mockNT4Client.announcedTopics).thenReturn({
    1: NT4Topic(
      name: '/SmartDashboard/Test Value 1',
      type: NT4TypeStr.kInt,
      properties: {},
    ),
    2: NT4Topic(
      name: '/SmartDashboard/Test Value 2',
      type: NT4TypeStr.kFloat32,
      properties: {},
    ),
  });

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockNT4Connection.nt4Client).thenReturn(mockNT4Client);

  when(mockNT4Connection.isNT4Connected).thenReturn(true);

  when(mockNT4Connection.connectionStatus())
      .thenAnswer((_) => Stream.value(true));

  when(mockNT4Connection.dsConnectionStatus())
      .thenAnswer((_) => Stream.value(true));

  when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT4Connection.getTopicFromName(any))
      .thenReturn(NT4Topic(name: '', type: NT4TypeStr.kString, properties: {}));

  NTConnection.instance = mockNT4Connection;
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
