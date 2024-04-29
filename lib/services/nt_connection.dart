import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/ds_interop.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';

class NTConnection {
  late NT4Client _ntClient;
  late DSInteropClient _dsClient;

  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  bool _ntConnected = false;
  bool _dsConnected = false;

  bool get isNT4Connected => _ntConnected;

  bool get isDSConnected => _dsConnected;
  DSInteropClient get dsClient => _dsClient;

  NTConnection(String ipAddress) {
    nt4Connect(ipAddress);
  }

  void nt4Connect(String ipAddress) {
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
    _ntClient.subscribeTopicsOnly('/');
  }

  void dsClientConnect(
      {Function(String ip)? onIPAnnounced,
      Function(bool isDocked)? onDriverStationDockChanged}) {
    _dsClient = DSInteropClient(
      onNewIPAnnounced: onIPAnnounced,
      onDriverStationDockChanged: onDriverStationDockChanged,
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

  void addTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _ntClient.addTopicAnnounceListener(onAnnounce);
  }

  void removeTopicAnnounceListener(Function(NT4Topic topic) onUnannounce) {
    _ntClient.removeTopicAnnounceListener(onUnannounce);
  }

  void recallTopicAnnounceListeners() {
    _ntClient.recallAnnounceListeners();
  }

  Future<T?>? subscribeAndRetrieveData<T>(String topic,
      {period = 0.1,
      timeout = const Duration(seconds: 2, milliseconds: 500)}) async {
    NT4Subscription subscription = subscribe(topic, period);

    T? value;
    try {
      value = await subscription
          .periodicStream()
          .firstWhere((element) => element != null && element is T)
          .timeout(timeout) as T?;
    } catch (e) {
      value = null;
    }

    unSubscribe(subscription);

    return value;
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

  Stream<bool> dsConnectionStatus() async* {
    yield _dsConnected;
    bool lastYielded = _dsConnected;

    while (true) {
      if (_dsConnected != lastYielded) {
        yield _dsConnected;
        lastYielded = _dsConnected;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Map<int, NT4Topic> announcedTopics() {
    return _ntClient.announcedTopics;
  }

  Stream<double> latencyStream() {
    return _ntClient.latencyStream();
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

  void publishTopic(NT4Topic topic) {
    _ntClient.publishTopic(topic);
  }

  NT4Topic publishNewTopic(String name, String type) {
    return _ntClient.publishNewTopic(name, type);
  }

  bool isTopicPublished(NT4Topic? topic) {
    return _ntClient.isTopicPublished(topic);
  }

  Object? getLastAnnouncedValue(String topic) {
    return _ntClient.lastAnnouncedValues[topic];
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
