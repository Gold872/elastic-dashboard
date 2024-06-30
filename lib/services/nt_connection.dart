import 'package:elastic_dashboard/services/ds_interop.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:flutter/foundation.dart';

/// Manages connections to NetworkTables (NT4) and Driver Station (DS) interoperation clients.
class NTConnection {
  static NTConnection instance = NTConnection._internal();

  late NT4Client _ntClient;
  late DSInteropClient _dsClient;

  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  bool _ntConnected = false;
  bool _dsConnected = false;

  /// Indicates whether the NT4 client is connected.
  bool get isNT4Connected => _ntConnected;

  /// Retrieves the NT4 client instance.
  NT4Client get nt4Client => _ntClient;

  /// Indicates whether the Driver Station (DS) client is connected.
  bool get isDSConnected => _dsConnected;

  /// Retrieves the DS client instance.
  DSInteropClient get dsClient => _dsClient;

  NTConnection._internal();

  factory NTConnection() {
    return instance;
  }

  /// Establishes a connection to the NT4 server using the specified [ipAddress].
  ///
  /// Sets up callbacks for connection and disconnection events.
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

  /// Establishes a connection to the Driver Station (DS) client.
  ///
  /// Sets up callbacks for IP announcement and driver station docking changes.
  void dsClientConnect({
    Function(String ip)? onIPAnnounced,
    Function(bool isDocked)? onDriverStationDockChanged,
  }) {
    _dsClient = DSInteropClient(
      onNewIPAnnounced: onIPAnnounced,
      onDriverStationDockChanged: onDriverStationDockChanged,
      onConnect: () => _dsConnected = true,
      onDisconnect: () => _dsConnected = false,
    );
  }

  /// Adds a listener for NT4 connection events.
  void addConnectedListener(VoidCallback callback) {
    onConnectedListeners.add(callback);
  }

  /// Adds a listener for NT4 disconnection events.
  void addDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.add(callback);
  }

  /// Subscribes to a topic on NT4 and retrieves data of type [T] from it.
  ///
  /// Returns null if no data is received within [timeout].
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

  /// Stream that emits the current connection status of NT4.
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

  /// Stream that emits the current connection status of DS.
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

  /// Stream that emits latency information from the NT4 client.
  Stream<double> latencyStream() {
    return nt4Client.latencyStream();
  }

  /// Changes the NT4 server IP address if it differs from the current one.
  void changeIPAddress(String ipAddress) {
    if (_ntClient.serverBaseAddress == ipAddress) {
      return;
    }

    _ntClient.setServerBaseAddreess(ipAddress);
  }

  /// Subscribes to a topic on NT4.
  NT4Subscription subscribe(String topic, [double period = 0.1]) {
    return _ntClient.subscribe(topic, period);
  }

  /// Subscribes to all subtopics of a topic on NT4.
  NT4Subscription subscribeAll(String topic, [double period = 0.1]) {
    return _ntClient.subscribeAll(topic, period);
  }

  /// Unsubscribes from a subscription on NT4.
  void unSubscribe(NT4Subscription subscription) {
    _ntClient.unSubscribe(subscription);
  }

  /// Retrieves the NT4 topic from a subscription.
  NT4Topic? getTopicFromSubscription(NT4Subscription subscription) {
    return _ntClient.getTopicFromName(subscription.topic);
  }

  /// Retrieves the NT4 topic by its name.
  NT4Topic? getTopicFromName(String topic) {
    return _ntClient.getTopicFromName(topic);
  }

  /// Checks if a given NT4 topic is published.
  bool isTopicPublished(NT4Topic? topic) {
    return _ntClient.isTopicPublished(topic);
  }

  /// Retrieves the last announced value for a given NT4 topic.
  Object? getLastAnnouncedValue(String topic) {
    return _ntClient.lastAnnouncedValues[topic];
  }

  /// Unpublishes an NT4 topic.
  void unpublishTopic(NT4Topic topic) {
    _ntClient.unpublishTopic(topic);
  }

  /// Updates data for a subscription on NT4.
  void updateDataFromSubscription(NT4Subscription subscription, dynamic data) {
    _ntClient.addSampleFromName(subscription.topic, data);
  }

  /// Updates data for a topic on NT4.
  void updateDataFromTopic(NT4Topic topic, dynamic data) {
    _ntClient.addSample(topic, data);
  }
}

/// Retrieves the singleton instance of [NTConnection].
NTConnection get ntConnection => NTConnection.instance;
