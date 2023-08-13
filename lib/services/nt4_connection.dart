import 'dart:ui';

import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';

class NT4Connection {
  static late NT4Client nt4Client;

  static late NT4Subscription allTopicsSubscription;

  static List<VoidCallback> onConnectedListeners = [];
  static List<VoidCallback> onDisconnectedListeners = [];

  static bool connected = false;

  static void connect() async {
    nt4Client = NT4Client(
        serverBaseAddress: Globals.ipAddress,
        onConnect: () {
          connected = true;

          for (VoidCallback callback in onConnectedListeners) {
            callback.call();
          }
        },
        onDisconnect: () {
          connected = false;

          for (VoidCallback callback in onDisconnectedListeners) {
            callback.call();
          }
        });

    // Allows all published topics to be announced
    allTopicsSubscription = nt4Client.subscribe('');
  }

  static void addConnectedListener(VoidCallback callback) {
    onConnectedListeners.add(callback);
  }

  static void addDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.add(callback);
  }

  static Stream<bool> connectionStatus() async* {
    yield connected;
    bool lastYielded = connected;

    while (true) {
      if (connected != lastYielded) {
        yield connected;
        lastYielded = connected;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  static NT4Subscription subscribe(String topic, [double period = 0.1]) {
    return nt4Client.subscribe(topic, period);
  }

  static void unSubscribe(NT4Subscription subscription) {
    nt4Client.unSubscribe(subscription);
  }

  static NT4Topic? getTopicFromSubscription(NT4Subscription subscription) {
    return nt4Client.getTopicFromName(subscription.topic);
  }

  static NT4Topic? getTopicFromName(String topic) {
    return nt4Client.getTopicFromName(topic);
  }

  static Object? getLastAnnouncedValue(String topic) {
    if (nt4Client.lastAnnouncedValues.containsKey(topic)) {
      return nt4Client.lastAnnouncedValues[topic];
    }

    return null;
  }

  static void unpublishTopic(NT4Topic topic) {
    nt4Client.unpublishTopic(topic);
  }

  static void updateDataFromSubscription(
      NT4Subscription subscription, dynamic data) {
    nt4Client.addSampleFromName(subscription.topic, data);
  }

  static void updateDataFromTopic(NT4Topic topic, dynamic data) {
    nt4Client.addSample(topic, data);
  }
}
