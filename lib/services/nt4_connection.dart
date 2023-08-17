import 'package:elastic_dashboard/services/nt4.dart';
import 'package:flutter/foundation.dart';

NT4Connection get nt4Connection => NT4Connection.instance;

class NT4Connection {
  static NT4Connection instance = NT4Connection._internal();

  late NT4Client _client;

  late NT4Subscription allTopicsSubscription;

  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  bool _connected = false;

  bool get isConnected => _connected;
  NT4Client get nt4Client => _client;

  NT4Connection._internal();

  factory NT4Connection() {
    return instance;
  }

  void connect(String ipAddress) async {
    _client = NT4Client(
        serverBaseAddress: ipAddress,
        onConnect: () {
          _connected = true;

          for (VoidCallback callback in onConnectedListeners) {
            callback.call();
          }
        },
        onDisconnect: () {
          _connected = false;

          for (VoidCallback callback in onDisconnectedListeners) {
            callback.call();
          }
        });

    // Allows all published topics to be announced
    allTopicsSubscription = _client.subscribe('');
  }

  void addConnectedListener(VoidCallback callback) {
    onConnectedListeners.add(callback);
  }

  void addDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.add(callback);
  }

  Stream<bool> connectionStatus() async* {
    yield _connected;
    bool lastYielded = _connected;

    while (true) {
      if (_connected != lastYielded) {
        yield _connected;
        lastYielded = _connected;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void changeIPAddress(String ipAddress) {
    if (_client.serverBaseAddress == ipAddress) {
      return;
    }

    _client.setServerBaseAddreess(ipAddress);
  }

  NT4Subscription subscribe(String topic, [double period = 0.1]) {
    return _client.subscribe(topic, period);
  }

  void unSubscribe(NT4Subscription subscription) {
    _client.unSubscribe(subscription);
  }

  NT4Topic? getTopicFromSubscription(NT4Subscription subscription) {
    return _client.getTopicFromName(subscription.topic);
  }

  NT4Topic? getTopicFromName(String topic) {
    return _client.getTopicFromName(topic);
  }

  Object? getLastAnnouncedValue(String topic) {
    if (_client.lastAnnouncedValues.containsKey(topic)) {
      return _client.lastAnnouncedValues[topic];
    }

    return null;
  }

  void unpublishTopic(NT4Topic topic) {
    _client.unpublishTopic(topic);
  }

  void updateDataFromSubscription(NT4Subscription subscription, dynamic data) {
    _client.addSampleFromName(subscription.topic, data);
  }

  void updateDataFromTopic(NT4Topic topic, dynamic data) {
    _client.addSample(topic, data);
  }
}
