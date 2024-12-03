import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/ds_interop.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';

typedef SubscriptionIdentification = ({
  String topic,
  NT4SubscriptionOptions options
});

class NTConnection {
  late NT4Client _ntClient;
  late DSInteropClient _dsClient;

  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  final ValueNotifier<bool> _ntConnected = ValueNotifier(false);
  ValueNotifier<bool> get ntConnected => _ntConnected;
  bool _dsConnected = false;

  bool get isNT4Connected => _ntConnected.value;

  bool get isDSConnected => _dsConnected;
  DSInteropClient get dsClient => _dsClient;

  int get serverTime => _ntClient.getServerTimeUS();

  @visibleForTesting
  List<NT4Subscription> get subscriptions => subscriptionUseCount.keys.toList();

  @visibleForTesting
  String get serverBaseAddress => _ntClient.serverBaseAddress;

  Map<int, NT4Subscription> subscriptionMap = {};
  Map<NT4Subscription, int> subscriptionUseCount = {};

  NTConnection(String ipAddress) {
    nt4Connect(ipAddress);
  }

  void nt4Connect(String ipAddress) {
    _ntClient = NT4Client(
        serverBaseAddress: ipAddress,
        onConnect: () {
          _ntConnected.value = true;

          for (VoidCallback callback in onConnectedListeners) {
            callback.call();
          }
        },
        onDisconnect: () {
          _ntConnected.value = false;

          for (VoidCallback callback in onDisconnectedListeners) {
            callback.call();
          }
        });

    // Allows all published topics to be announced
    _ntClient.subscribe(
      topic: '',
      options: const NT4SubscriptionOptions(topicsOnly: true),
    );
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

  void removeTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _ntClient.removeTopicAnnounceListener(onAnnounce);
  }

  void addTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _ntClient.addTopicUnannounceListener(onUnannounce);
  }

  void removeTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _ntClient.removeTopicUnannounceListener(onUnannounce);
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
    yield _ntConnected.value;
    bool lastYielded = _ntConnected.value;

    while (true) {
      if (_ntConnected.value != lastYielded) {
        yield _ntConnected.value;
        lastYielded = _ntConnected.value;
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
    NT4SubscriptionOptions subscriptionOptions =
        NT4SubscriptionOptions(periodicRateSeconds: period);

    int hashCode = Object.hash(topic, subscriptionOptions);

    if (subscriptionMap.containsKey(hashCode)) {
      NT4Subscription existingSubscription = subscriptionMap[hashCode]!;
      subscriptionUseCount.update(existingSubscription, (value) => value + 1);

      return existingSubscription;
    }

    NT4Subscription newSubscription =
        _ntClient.subscribe(topic: topic, options: subscriptionOptions);

    subscriptionMap[hashCode] = newSubscription;
    subscriptionUseCount[newSubscription] = 1;

    return newSubscription;
  }

  NT4Subscription subscribeAll(String topic, [double period = 0.1]) {
    return _ntClient.subscribe(
        topic: topic,
        options: NT4SubscriptionOptions(
          periodicRateSeconds: period,
          all: true,
        ));
  }

  void unSubscribe(NT4Subscription subscription) {
    if (!subscriptionUseCount.containsKey(subscription)) {
      _ntClient.unSubscribe(subscription);
      return;
    }

    int hashCode = Object.hash(subscription.topic, subscription.options);

    subscriptionUseCount.update(subscription, (value) => value - 1);

    if (subscriptionUseCount[subscription]! <= 0) {
      subscriptionMap.remove(hashCode);
      subscriptionUseCount.remove(subscription);
      _ntClient.unSubscribe(subscription);
    }
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

  @visibleForTesting
  void updateDataFromTopicName(String topic, dynamic data) {
    _ntClient.addSampleFromName(topic, data);
  }
}
