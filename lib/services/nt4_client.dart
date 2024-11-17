// Written by Michael Jansen from Team 3015, Ranger Robotics
// Additional inspiration taken from Jonah from Team 6328, Mechanical Advantage

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:messagepack/messagepack.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:elastic_dashboard/services/log.dart';

class NT4TypeStr {
  static final Map<String, int> typeMap = {
    'boolean': 0,
    'double': 1,
    'int': 2,
    'float': 3,
    'string': 4,
    'json': 4,
    'raw': 5,
    'rpc': 5,
    'msgpack': 5,
    'protobuf': 5,
    'structschema': 5,
    'boolean[]': 16,
    'double[]': 17,
    'int[]': 18,
    'float[]': 19,
    'string[]': 20,
  };

  static const kBool = 'boolean';
  static const kFloat64 = 'double';
  static const kInt = 'int';
  static const kFloat32 = 'float';
  static const kString = 'string';
  static const kJson = 'json';
  static const kBinaryRaw = 'raw';
  static const kBinaryRPC = 'rpc';
  static const kBinaryMsgpack = 'msgpack';
  static const kBinaryProtobuf = 'protobuf';
  static const kStructSchema = 'structschema';
  static const kBoolArr = 'boolean[]';
  static const kFloat64Arr = 'double[]';
  static const kIntArr = 'int[]';
  static const kFloat32Arr = 'float[]';
  static const kStringArr = 'string[]';
}

class NT4Subscription extends ValueNotifier<Object?> {
  final String topic;
  final NT4SubscriptionOptions options;
  final int uid;

  Object? currentValue;
  int timestamp = 0;

  final List<Function(Object?, int)> _listeners = [];

  NT4Subscription({
    required this.topic,
    this.options = const NT4SubscriptionOptions(),
    this.uid = -1,
  }) : super(null);

  void listen(Function(Object?, int) onChanged) {
    _listeners.add(onChanged);
  }

  Stream<Object?> periodicStream({bool yieldAll = true}) async* {
    final Duration delayTime =
        Duration(microseconds: (options.periodicRateSeconds * 1e6).round());

    yield currentValue;
    Object? lastYielded = currentValue;

    while (true) {
      await Future.delayed(delayTime);

      if (lastYielded != currentValue || yieldAll) {
        yield currentValue;
        lastYielded = currentValue;
      }
    }
  }

  Stream<({Object? value, DateTime timestamp})> timestampedStream(
      {bool yieldAll = false}) async* {
    yield (
      value: currentValue,
      timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
    );

    int lastTimestamp = timestamp;
    int fakeTimestamp = timestamp;

    while (true) {
      await Future.delayed(
          Duration(microseconds: (options.periodicRateSeconds * 1e6).round()));

      if (lastTimestamp != timestamp || yieldAll) {
        yield (
          value: currentValue,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
        );
        lastTimestamp = timestamp;
        fakeTimestamp = timestamp;
      } else if (yieldAll) {
        fakeTimestamp += (options.periodicRateSeconds * 1e6).round();
        yield (
          value: currentValue,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(fakeTimestamp),
        );
      }
    }
  }

  void updateValue(Object? value, int timestamp) {
    for (var listener in _listeners) {
      listener(value, timestamp);
    }
    currentValue = value;
    this.timestamp = timestamp;
    super.value = value;
  }

  Map<String, dynamic> _toSubscribeJson() {
    return {
      'topics': [topic],
      'options': options.toJson(),
      'subuid': uid,
    };
  }

  Map<String, dynamic> _toUnsubscribeJson() {
    return {
      'subuid': uid,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is NT4Subscription &&
      other.runtimeType == runtimeType &&
      other.topic == topic &&
      other.options == options;

  @override
  int get hashCode => Object.hashAll([topic, options]);
}

class NT4SubscriptionOptions {
  final double periodicRateSeconds;
  final bool all;
  final bool topicsOnly;
  final bool prefix;

  const NT4SubscriptionOptions({
    this.periodicRateSeconds = 0.1,
    this.all = false,
    this.topicsOnly = false,
    this.prefix = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'periodic': periodicRateSeconds,
      'all': all,
      'topicsonly': topicsOnly,
      'prefix': prefix,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is NT4SubscriptionOptions &&
      other.runtimeType == runtimeType &&
      other.periodicRateSeconds == periodicRateSeconds &&
      other.all == all &&
      other.topicsOnly == topicsOnly &&
      other.prefix == prefix;

  @override
  int get hashCode =>
      Object.hashAll([periodicRateSeconds, all, topicsOnly, prefix]);
}

class NT4Topic {
  final String name;
  final String type;
  int id;
  int pubUID;
  final Map<String, dynamic> properties;

  NT4Topic({
    required this.name,
    required this.type,
    this.id = 0,
    this.pubUID = 0,
    required this.properties,
  });

  Map<String, dynamic> toPublishJson() {
    return {
      'name': name,
      'type': type,
      'pubuid': pubUID,
    };
  }

  Map<String, dynamic> toUnpublishJson() {
    return {
      'name': name,
      'pubuid': pubUID,
    };
  }

  Map<String, dynamic> toPropertiesJson() {
    return {
      'name': name,
      'update': properties,
    };
  }

  int getTypeId() {
    return NT4TypeStr.typeMap[type]!;
  }
}

class NT4Client {
  static const int _pingIntervalMsV40 = 1000;
  static const int _pingIntervalMsV41 = 200;

  static const int _pingTimeoutMsV40 = 5000;
  static const int _pingTimeoutMsV41 = 1000;

  String serverBaseAddress;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final List<Function(NT4Topic topic)> _topicAnnounceListeners = [];
  final List<Function(NT4Topic topic)> _topicUnannounceListeners = [];

  final Map<int, NT4Subscription> _subscriptions = {};
  final Set<NT4Subscription> _subscribedTopics = {};
  int _subscriptionUIDCounter = 0;
  int _publishUIDCounter = 0;
  final Map<String, Object?> lastAnnouncedValues = {};
  final Map<String, int> lastAnnouncedTimestamps = {};
  final Map<String, NT4Topic> _clientPublishedTopics = {};
  final Map<int, NT4Topic> announcedTopics = {};
  int _clientId = 0;
  int _serverTimeOffsetUS = 0;
  double _latencyMs = 0;

  WebSocketChannel? _mainWebsocket;
  StreamSubscription? _mainWebsocketListener;
  WebSocketChannel? _rttWebsocket;
  StreamSubscription? _rttWebsocketListener;

  Timer? _pingTimer;
  Timer? _pongTimer;

  int _pingInterval = _pingIntervalMsV40;
  int _timeoutInterval = _pingTimeoutMsV40;

  bool _serverConnectionActive = false;
  bool _rttConnectionActive = false;

  bool get mainWebsocketActive =>
      _mainWebsocket != null && _mainWebsocket!.closeCode == null;
  bool get rttWebsocketActive =>
      _rttWebsocket != null && _rttWebsocket!.closeCode == null;

  bool _useRTT = false;
  bool _attemptingConnection = true;

  int _lastPongTime = 0;

  Map<int, NT4Subscription> get subscriptions => _subscriptions;
  Set<NT4Subscription> get subscribedTopics => _subscribedTopics;
  List<Function(NT4Topic topic)> get topicAnnounceListeners =>
      _topicAnnounceListeners;

  NT4Client({
    required this.serverBaseAddress,
    this.onConnect,
    this.onDisconnect,
  }) {
    Future.delayed(
        const Duration(seconds: 1, milliseconds: 500), () => _connect());
  }

  void setServerBaseAddreess(String serverBaseAddress) {
    this.serverBaseAddress = serverBaseAddress;
    _wsOnClose(false);
    _attemptingConnection = true;
    Future.delayed(const Duration(milliseconds: 100), _connect);
  }

  Stream<double> latencyStream() async* {
    yield _latencyMs;

    double lastYielded = _latencyMs;

    while (true) {
      await Future.delayed(const Duration(seconds: 1));

      if (_latencyMs != lastYielded) {
        yield _latencyMs;
        lastYielded = _latencyMs;
      }
    }
  }

  void addTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _topicAnnounceListeners.add(onAnnounce);

    for (NT4Topic topic in announcedTopics.values) {
      onAnnounce(topic);
    }
  }

  void removeTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _topicAnnounceListeners.remove(onAnnounce);
  }

  void addTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _topicUnannounceListeners.add(onUnannounce);
  }

  void removeTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _topicUnannounceListeners.add(onUnannounce);
  }

  NT4Subscription subscribe({
    required String topic,
    NT4SubscriptionOptions options = const NT4SubscriptionOptions(),
  }) {
    NT4Subscription newSub = NT4Subscription(
      topic: topic,
      uid: getNewSubUID(),
      options: options,
    );

    _subscriptions[newSub.uid] = newSub;
    _subscribedTopics.add(newSub);
    _wsSubscribe(newSub);

    if (lastAnnouncedValues.containsKey(topic) &&
        lastAnnouncedTimestamps.containsKey(topic)) {
      newSub.updateValue(
          lastAnnouncedValues[topic], lastAnnouncedTimestamps[topic]!);
    }

    return newSub;
  }

  void unSubscribe(NT4Subscription sub) {
    _subscriptions.remove(sub.uid);
    _subscribedTopics.remove(sub);
    _wsUnsubscribe(sub);

    // If there are no other subscriptions that are in the same table/tree
    if (!_subscribedTopics.any((element) =>
        element.topic.startsWith('${sub.topic}/') ||
        sub.topic.startsWith('${element.topic}/') ||
        sub.topic == element.topic)) {
      // If there are any topics associated with the table/tree, unpublish them
      for (NT4Topic topic in _clientPublishedTopics.values.where((element) =>
          element.name.startsWith('${sub.topic}/') ||
          sub.topic.startsWith('${element.name}/') ||
          sub.topic == element.name)) {
        Future(() => unpublishTopic(topic));
      }
    }
  }

  void clearAllSubscriptions() {
    for (NT4Subscription sub in _subscriptions.values) {
      unSubscribe(sub);
    }
    _subscriptions.clear();
  }

  void setProperties(NT4Topic topic, bool isPersistent, bool isRetained) {
    topic.properties['persistent'] = isPersistent;
    topic.properties['retained'] = isRetained;
    _wsSetProperties(topic);
  }

  NT4Topic? getTopicFromName(String topic) {
    return announcedTopics.values.firstWhereOrNull((e) => e.name == topic);
  }

  bool isTopicPublished(NT4Topic? topic) {
    return _clientPublishedTopics.containsValue(topic);
  }

  NT4Topic publishNewTopic(String name, String type) {
    NT4Topic newTopic = NT4Topic(name: name, type: type, properties: {});
    publishTopic(newTopic);
    return newTopic;
  }

  void publishTopic(NT4Topic topic) {
    if (_clientPublishedTopics.containsKey(topic.name)) {
      topic.pubUID = _clientPublishedTopics[topic.name]!.pubUID;
      return;
    }

    topic.pubUID = getNewPubUID();
    _clientPublishedTopics[topic.name] = topic;
    _wsPublish(topic);
  }

  void unpublishTopic(NT4Topic topic) {
    _clientPublishedTopics.remove(topic.name);
    _wsUnpublish(topic);
  }

  void addSample(NT4Topic topic, dynamic data, [int? timestamp]) {
    timestamp ??= getServerTimeUS();

    _wsSendBinary(
        serialize([topic.pubUID, timestamp, topic.getTypeId(), data]));

    lastAnnouncedValues[topic.name] = data;
    lastAnnouncedTimestamps[topic.name] = timestamp;
    for (NT4Subscription sub in _subscriptions.values) {
      if (sub.topic == topic.name) {
        sub.updateValue(data, timestamp);
      }
    }
  }

  void addSampleFromName(String topic, dynamic data, [int? timestamp]) {
    for (NT4Topic t in announcedTopics.values) {
      if (t.name == topic) {
        addSample(t, data, timestamp);
        return;
      }
    }
    logger.debug('[NT4] Topic not found: $topic');
  }

  int _getClientTimeUS() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  int getServerTimeUS() {
    return _getClientTimeUS() + _serverTimeOffsetUS;
  }

  void _rttSendTimestamp() {
    var timeTopic = announcedTopics[-1];
    if (timeTopic != null) {
      int timeToSend = _getClientTimeUS();

      var rawData =
          serialize([timeTopic.pubUID, 0, timeTopic.getTypeId(), timeToSend]);

      if (_useRTT) {
        if (rttWebsocketActive && mainWebsocketActive) {
          _rttWebsocket?.sink.add(rawData);
        }
      } else if (mainWebsocketActive) {
        _mainWebsocket?.sink.add(rawData);
      }
    }
  }

  void _rttHandleRecieveTimestamp(int serverTimestamp, int clientTimestamp) {
    int rxTime = _getClientTimeUS();

    int rtt = rxTime - clientTimestamp;
    int serverTimeAtRx = (serverTimestamp - rtt / 2.0).round();
    _serverTimeOffsetUS = serverTimeAtRx - rxTime;

    _lastPongTime = rxTime;

    _latencyMs = (rtt / 2) / 1000;
  }

  void _wsSubscribe(NT4Subscription sub) {
    _wsSendJSON('subscribe', sub._toSubscribeJson());
  }

  void _wsUnsubscribe(NT4Subscription sub) {
    _wsSendJSON('unsubscribe', sub._toUnsubscribeJson());
  }

  void _wsPublish(NT4Topic topic) {
    _wsSendJSON('publish', topic.toPublishJson());
  }

  void _wsUnpublish(NT4Topic topic) {
    _wsSendJSON('unpublish', topic.toUnpublishJson());
  }

  void _wsSetProperties(NT4Topic topic) {
    _wsSendJSON('setproperties', topic.toPropertiesJson());
  }

  void _wsSendJSON(String method, Map<String, dynamic> params) {
    if (!mainWebsocketActive) {
      return;
    }

    _mainWebsocket?.sink.add(jsonEncode([
      {
        'method': method,
        'params': params,
      }
    ]));
  }

  void _wsSendBinary(dynamic data) {
    if (!mainWebsocketActive) {
      return;
    }

    _mainWebsocket?.sink.add(data);
  }

  void _connect() async {
    if (_serverConnectionActive || !_attemptingConnection) {
      return;
    }

    _clientId = Random().nextInt(99999999);

    String mainServerAddr = 'ws://$serverBaseAddress:5810/nt/Elastic';

    _mainWebsocket =
        WebSocketChannel.connect(Uri.parse(mainServerAddr), protocols: [
      'networktables.first.wpi.edu',
      'v4.1.networktables.first.wpi.edu',
    ]);

    try {
      await _mainWebsocket!.ready;
    } catch (e) {
      // Failed to connect... try again
      logger.info(
          'Failed to connect to network tables, attempting to reconnect in 500 ms');
      if (_attemptingConnection) {
        Future.delayed(const Duration(milliseconds: 500), _connect);
      }
      return;
    }
    _attemptingConnection = false;

    if (!mainServerAddr.contains(serverBaseAddress)) {
      logger.info('IP Address changed while connecting, aborting connection');
      await _mainWebsocket?.sink.close();
      return;
    }

    _pingTimer?.cancel();
    _pongTimer?.cancel();

    if (_mainWebsocket!.protocol == 'v4.1.networktables.first.wpi.edu') {
      _useRTT = true;
      _pingInterval = _pingIntervalMsV41;
      _timeoutInterval = _pingTimeoutMsV41;
    } else {
      _useRTT = false;
      _pingInterval = _pingIntervalMsV40;
      _timeoutInterval = _pingTimeoutMsV40;
    }

    _mainWebsocketListener = _mainWebsocket!.stream.listen(
      (data) {
        // Prevents repeated calls to onConnect and reconnecting after changing ip addresses
        if (!_serverConnectionActive &&
            mainServerAddr.contains(serverBaseAddress)) {
          _onFirstMessageReceived();
        }
        _wsOnMessage(data);
      },
      onDone: _wsOnClose,
      onError: (err) {
        logger.error('NT4 Error', err);
      },
      cancelOnError: true,
    );

    if (_useRTT) {
      await _rttConnect();
    }

    NT4Topic timeTopic = NT4Topic(
        name: 'Time',
        type: NT4TypeStr.kInt,
        id: -1,
        pubUID: -1,
        properties: {});
    announcedTopics[timeTopic.id] = timeTopic;

    _lastPongTime = 0;
    _rttSendTimestamp();

    _pingTimer = Timer.periodic(Duration(milliseconds: _pingInterval), (timer) {
      _rttSendTimestamp();
    });
    _pongTimer =
        Timer.periodic(Duration(milliseconds: _pingInterval), _checkPingStatus);

    for (NT4Topic topic in _clientPublishedTopics.values) {
      _wsPublish(topic);
      _wsSetProperties(topic);
    }

    for (NT4Subscription sub in _subscriptions.values) {
      _wsSubscribe(sub);
    }
  }

  Future<void> _rttConnect() async {
    if (!_useRTT || _rttConnectionActive) {
      return;
    }

    String rttServerAddr = 'ws://$serverBaseAddress:5810/nt/Elastic';
    _rttWebsocket = WebSocketChannel.connect(Uri.parse(rttServerAddr),
        protocols: ['rtt.networktables.first.wpi.edu']);

    try {
      await _rttWebsocket!.ready;
    } catch (e) {
      logger.info(
          'Failed to connect to RTT Network Tables protocol, attempting to reconnect in 500 ms');
      Future.delayed(const Duration(milliseconds: 500), _rttConnect);
      return;
    }

    if (!rttServerAddr.contains(serverBaseAddress)) {
      logger.info(
          'IP Addressed changed while connecting to RTT, aborting connection');
      await _rttWebsocket?.sink.close();
      return;
    }

    _rttWebsocketListener = _rttWebsocket!.stream.listen(
      (data) {
        if (!_rttConnectionActive) {
          logger.info('RTT protocol connected on $serverBaseAddress');
          _rttConnectionActive = true;
        }

        if (!_serverConnectionActive && mainWebsocketActive) {
          _onFirstMessageReceived();
        }

        if (data is! List<int>) {
          return;
        }

        var msg = Unpacker.fromList(data).unpackList();

        int topicID = msg[0] as int;
        int timestampUS = msg[1] as int;
        var value = msg[3];

        if (value is! int) {
          return;
        }

        if (topicID & 0xFF == 0xFF) {
          _rttHandleRecieveTimestamp(timestampUS, value);
        }
      },
      onDone: _rttOnClose,
      onError: (err) {
        logger.error('RTT Error', err);
      },
      cancelOnError: true,
    );
  }

  void _onFirstMessageReceived() {
    logger.info(
        'Network Tables connected on IP address $serverBaseAddress with protocol ${_mainWebsocket!.protocol}');
    lastAnnouncedValues.clear();
    lastAnnouncedTimestamps.clear();

    for (NT4Subscription sub in _subscriptions.values) {
      sub.currentValue = null;
    }

    _serverConnectionActive = true;

    onConnect?.call();
  }

  void _rttOnClose() async {
    await _rttWebsocketListener?.cancel();
    _rttWebsocketListener = null;
    await _rttWebsocket?.sink.close();
    _rttWebsocket = null;

    _lastPongTime = 0;
    _rttConnectionActive = false;
    _useRTT = false;

    logger.info('RTT Connection closed');
  }

  void _wsOnClose([bool autoReconnect = true]) async {
    _attemptingConnection = false;

    _pingTimer?.cancel();
    _pongTimer?.cancel();

    await _mainWebsocketListener?.cancel();
    await _mainWebsocket?.sink.close();

    await _rttWebsocketListener?.cancel();
    await _rttWebsocket?.sink.close();

    _mainWebsocket = null;
    _rttWebsocket = null;

    _mainWebsocketListener = null;
    _rttWebsocketListener = null;

    _serverConnectionActive = false;
    _rttConnectionActive = false;
    _useRTT = false;

    _lastPongTime = 0;
    _latencyMs = 0;

    logger.info('Network Tables disconnected');
    onDisconnect?.call();

    announcedTopics.clear();

    logger.debug('[NT4] Connection closed. Attempting to reconnect in 500 ms');
    if (autoReconnect && !_attemptingConnection) {
      _attemptingConnection = true;
      Future.delayed(const Duration(milliseconds: 500), _connect);
    }
  }

  void _wsOnMessage(data) {
    if (data is String) {
      var rxArr = jsonDecode(data.toString());

      if (rxArr is! List) {
        logger.warning('[NT4] Ignoring text message, not an array');
      }

      for (var msg in rxArr) {
        if (msg is! Map) {
          logger.warning('[NT4] Ignoring text message, not a json object');
          continue;
        }

        var method = msg['method'];
        var params = msg['params'];

        if (method == null || method is! String) {
          logger.warning('[NT4] Ignoring text message, method not string');
          continue;
        }

        if (params == null || params is! Map) {
          logger.warning('[NT4] Ignoring text message, params not json object');
          continue;
        }

        if (method == 'announce') {
          NT4Topic? currentTopic;
          for (NT4Topic topic in _clientPublishedTopics.values) {
            if (params['name'] == topic.name) {
              currentTopic = topic;
            }
          }

          NT4Topic newTopic = NT4Topic(
              name: params['name'],
              type: params['type'],
              id: params['id'],
              pubUID: params['pubid'] ?? (currentTopic?.pubUID ?? 0),
              properties: params['properties']);
          announcedTopics[newTopic.id] = newTopic;

          for (final listener in _topicAnnounceListeners) {
            listener.call(newTopic);
          }
        } else if (method == 'unannounce') {
          NT4Topic? removedTopic = announcedTopics[params['id']];
          if (removedTopic == null) {
            logger.warning(
                '[NT4] Ignorining unannounce, topic was not previously announced');
            return;
          }
          announcedTopics.remove(removedTopic.id);

          for (final listener in _topicUnannounceListeners) {
            listener.call(removedTopic);
          }
        } else if (method == 'properties') {
          String topicName = params['name'];
          NT4Topic? topic = getTopicFromName(topicName);
          if (topic == null) {
            logger
                .warning('[NT4] Ignoring properties, topic was not announced');
            return;
          }

          Map<String, dynamic> update = tryCast(params['update']) ?? {};
          for (MapEntry<String, dynamic> entry in update.entries) {
            if (entry.value == null) {
              topic.properties.remove(entry.key);
            } else {
              topic.properties[entry.key] = entry.value;
            }
          }
        } else {
          logger
              .warning('[NT4] Ignoring text message - unknown method $method');
          return;
        }
      }
    } else {
      var u = Unpacker.fromList(data);

      bool done = false;
      while (!done) {
        try {
          var msg = u.unpackList();

          int topicID = msg[0] as int;
          int timestampUS = msg[1] as int;
          var value = msg[3];

          if (topicID >= 0) {
            NT4Topic topic = announcedTopics[topicID]!;
            lastAnnouncedValues[topic.name] = value;
            lastAnnouncedTimestamps[topic.name] = timestampUS;
            for (NT4Subscription sub in _subscriptions.values) {
              if (sub.topic == topic.name) {
                sub.updateValue(value, timestampUS);
              }
            }
          } else if (topicID & 0xFF == 0xFF && !_useRTT) {
            _rttHandleRecieveTimestamp(timestampUS, value as int);
          } else {
            logger.warning(
                '[NT4] ignoring binary data, invalid topic ID: $topicID');
          }
        } catch (err) {
          done = true;
        }
      }
    }
  }

  void _checkPingStatus(Timer timer) {
    if (!_serverConnectionActive || _lastPongTime == 0) {
      return;
    }

    int currentTime = _getClientTimeUS();

    if (currentTime - _lastPongTime > _timeoutInterval * 1000) {
      logger.info('Network Tables connection timed out');
      _wsOnClose();
    }
  }

  int getNewSubUID() {
    _subscriptionUIDCounter++;
    return _subscriptionUIDCounter + _clientId;
  }

  int getNewPubUID() {
    _publishUIDCounter++;
    return _publishUIDCounter + _clientId;
  }
}

class NT4ValueReq {
  final List<String> topics;

  const NT4ValueReq({
    this.topics = const [],
  });

  Map<String, dynamic> toGetValsJson() {
    return {
      'topics': topics,
    };
  }
}
