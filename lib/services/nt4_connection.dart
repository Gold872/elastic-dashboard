import 'package:elastic_dashboard/services/ds_interop.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:flutter/foundation.dart';

NT4Connection get nt4Connection => NT4Connection.instance;

class NT4Connection {
  static NT4Connection instance = NT4Connection._internal();

  late NT4Client _ntClient;
  late DSInteropClient _dsClient;

  late NT4Subscription allTopicsSubscription;

  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  bool _ntConnected = false;
  bool _dsConnected = false;

  bool get isNT4Connected => _ntConnected;
  NT4Client get nt4Client => _ntClient;

  bool get isDSConnected => _dsConnected;
  DSInteropClient get dsClient => _dsClient;

  NT4Connection._internal();

  factory NT4Connection() {
    return instance;
  }

  void nt4Connect(String ipAddress) async {
    _ntClient = NT4Client(
        serverBaseAddress: ipAddress,
        onConnect: () {
          _ntConnected = true;

          for (VoidCallback callback in onConnectedListeners) {
            callback.call();
          }
        },
        onDisconnect: () {
          _ntConnected = false;

          for (VoidCallback callback in onDisconnectedListeners) {
            callback.call();
          }
        });

    // Allows all published topics to be announced
    allTopicsSubscription = _ntClient.subscribeTopicsOnly('/');
  }

  void dsClientConnect(Function(String ip)? onIPAnnounced) {
    _dsClient = DSInteropClient(
      onNewIPAnnounced: onIPAnnounced,
      onConnect: () => _dsConnected = true,
      onDisconnect: () => _dsConnected = false,
    );
  }

  void addConnectedListener(VoidCallback callback) {
    onConnectedListeners.add(callback);
  }

  void addDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.add(callback);
  }

  Stream<bool> connectionStatus() async* {
    yield _ntConnected;
    bool lastYielded = _ntConnected;

    while (true) {
      if (_ntConnected != lastYielded) {
        yield _ntConnected;
        lastYielded = _ntConnected;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void changeIPAddress(String ipAddress) {
    if (_ntClient.serverBaseAddress == ipAddress) {
      return;
    }

    _ntClient.setServerBaseAddreess(ipAddress);
  }

  NT4Subscription subscribe(String topic, [double period = 0.1]) {
    return _ntClient.subscribe(topic, period);
  }

  void unSubscribe(NT4Subscription subscription) {
    _ntClient.unSubscribe(subscription);
  }

  NT4Topic? getTopicFromSubscription(NT4Subscription subscription) {
    return _ntClient.getTopicFromName(subscription.topic);
  }

  NT4Topic? getTopicFromName(String topic) {
    return _ntClient.getTopicFromName(topic);
  }

  Object? getLastAnnouncedValue(String topic) {
    if (_ntClient.lastAnnouncedValues.containsKey(topic)) {
      return _ntClient.lastAnnouncedValues[topic];
    }

    return null;
  }

  void unpublishTopic(NT4Topic topic) {
    _ntClient.unpublishTopic(topic);
  }

  void updateDataFromSubscription(NT4Subscription subscription, dynamic data) {
    _ntClient.addSampleFromName(subscription.topic, data);
  }

  void updateDataFromTopic(NT4Topic topic, dynamic data) {
    _ntClient.addSample(topic, data);
  }
}
