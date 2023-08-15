/// Written by Michael Jansen from Team 3015, Ranger Robotics

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:messagepack/messagepack.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NT4Client {
  final String serverBaseAddress;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  final Map<int, NT4Subscription> _subscriptions = {};
  final Set<NT4Subscription> _subscribedTopics = {};
  int _subscriptionUIDCounter = 0;
  int _publishUIDCounter = 0;
  final Map<String, Object?> lastAnnouncedValues = {};
  final Map<String, NT4Topic> _clientPublishedTopics = {};
  final Map<int, NT4Topic> announcedTopics = {};
  int _clientId = 0;
  final String _serverAddr = '';
  bool _serverConnectionActive = false;
  int _serverTimeOffsetUS = 0;

  WebSocketChannel? _ws;

  NT4Client({
    required this.serverBaseAddress,
    this.onConnect,
    this.onDisconnect,
  }) {
    Timer.periodic(const Duration(milliseconds: 5000), (timer) {
      _wsSendTimestamp();
    });

    _wsConnect();
  }

  NT4Subscription subscribe(String topic, [double period = 0.1]) {
    NT4Subscription newSub = NT4Subscription(
      topic: topic,
      uid: getNewSubUID(),
      options: NT4SubscriptionOptions(periodicRateSeconds: period),
    );

    if (_subscribedTopics.contains(newSub)) {
      NT4Subscription subscription = _subscribedTopics.lookup(newSub)!;
      subscription.useCount++;

      return subscription;
    }

    newSub.useCount++;

    _subscriptions[newSub.uid] = newSub;
    _subscribedTopics.add(newSub);
    _wsSubscribe(newSub);

    if (lastAnnouncedValues.containsKey(topic)) {
      newSub.updateValue(lastAnnouncedValues[topic]);
    }

    return newSub;
  }

  NT4Subscription subscribeAllSamples(String topic) {
    NT4Subscription newSub = NT4Subscription(
      topic: topic,
      uid: getNewSubUID(),
      options: const NT4SubscriptionOptions(all: true),
    );

    if (_subscribedTopics.contains(newSub)) {
      NT4Subscription subscription = _subscribedTopics.lookup(newSub)!;
      subscription.useCount++;

      return subscription;
    }

    newSub.useCount++;

    _subscriptions[newSub.uid] = newSub;
    _wsSubscribe(newSub);
    return newSub;
  }

  NT4Subscription subscribeTopicsOnly(String topic) {
    NT4Subscription newSub = NT4Subscription(
      topic: topic,
      uid: getNewSubUID(),
      options: const NT4SubscriptionOptions(topicsOnly: true),
    );

    if (_subscribedTopics.contains(newSub)) {
      NT4Subscription subscription = _subscribedTopics.lookup(newSub)!;
      subscription.useCount++;

      return subscription;
    }

    newSub.useCount++;

    _subscriptions[newSub.uid] = newSub;
    _wsSubscribe(newSub);
    return newSub;
  }

  void unSubscribe(NT4Subscription sub) {
    sub.useCount--;

    if (sub.useCount <= 0) {
      _subscriptions.remove(sub.uid);
      _subscribedTopics.remove(sub);
      _wsUnsubscribe(sub);
    }
  }

  void clearAllSubscriptions() {
    for (NT4Subscription sub in _subscriptions.values) {
      sub.useCount = 0;
      unSubscribe(sub);
    }
  }

  void setProperties(NT4Topic topic, bool isPersistent, bool isRetained) {
    topic.properties['persistent'] = isPersistent;
    topic.properties['retained'] = isRetained;
    _wsSetProperties(topic);
  }

  NT4Topic? getTopicFromName(String topic) {
    for (NT4Topic t in announcedTopics.values) {
      if (t.name == topic) {
        return t;
      }
    }
    if (kDebugMode) {
      print('[NT4] Topic not found: $topic');
    }
    return null;
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
    timestamp ??= _getServerTimeUS();

    _wsSendBinary(
        serialize([topic.pubUID, timestamp, topic.getTypeId(), data]));

    lastAnnouncedValues[topic.name] = data;
    for (NT4Subscription sub in _subscriptions.values) {
      if (sub.topic == topic.name) {
        sub.updateValue(data);
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
    if (kDebugMode) {
      print('[NT4] Topic not found: $topic');
    }
  }

  int _getClientTimeUS() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  int _getServerTimeUS() {
    return _getClientTimeUS() + _serverTimeOffsetUS;
  }

  void _wsSendTimestamp() {
    var timeTopic = announcedTopics[-1];
    if (timeTopic != null) {
      int timeToSend = _getClientTimeUS();
      addSample(timeTopic, timeToSend, 0);
    }
  }

  void _wsHandleRecieveTimestamp(int serverTimestamp, int clientTimestamp) {
    int rxTime = _getClientTimeUS();

    int rtt = rxTime - clientTimestamp;
    int serverTimeAtRx = (serverTimestamp - rtt / 2.0).round();
    _serverTimeOffsetUS = serverTimeAtRx - rxTime;
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
    _ws?.sink.add(jsonEncode([
      {
        'method': method,
        'params': params,
      }
    ]));
  }

  void _wsSendBinary(dynamic data) {
    _ws?.sink.add(data);
  }

  void _wsConnect() async {
    _clientId = Random().nextInt(99999999);

    String serverAddr = 'ws://$serverBaseAddress:5810/nt/elastic';

    _ws = WebSocketChannel.connect(Uri.parse(serverAddr),
        protocols: ['networktables.first.wpi.edu']);

    try {
      await _ws!.ready;
    } catch (e) {
      // Failed to connect... try again
      Future.delayed(const Duration(seconds: 1), _wsConnect);
      return;
    }

    _ws!.stream.listen(
      (data) {
        if (!_serverConnectionActive) {
          _serverConnectionActive = true;
          onConnect?.call();
        }
        _wsOnMessage(data);
      },
      onDone: _wsOnClose,
      onError: (err) {
        if (kDebugMode) {
          print('NT4 ERR: $err');
        }
      },
    );

    NT4Topic timeTopic = NT4Topic(
        name: "Time",
        type: NT4TypeStr.kInt,
        id: -1,
        pubUID: -1,
        properties: {});
    announcedTopics[timeTopic.id] = timeTopic;

    _wsSendTimestamp();

    for (NT4Topic topic in _clientPublishedTopics.values) {
      _wsPublish(topic);
      _wsSetProperties(topic);
    }

    for (NT4Subscription sub in _subscriptions.values) {
      _wsSubscribe(sub);
    }
  }

  void _wsOnClose() {
    _ws = null;
    _serverConnectionActive = false;

    onDisconnect?.call();

    announcedTopics.clear();

    lastAnnouncedValues.clear();

    if (kDebugMode) {
      print('[NT4] Connection closed. Attempting to reconnect in 1s');
    }
    Future.delayed(const Duration(seconds: 1), _wsConnect);
  }

  void _wsOnMessage(data) {
    if (data is String) {
      var rxArr = jsonDecode(data.toString());

      if (rxArr is! List) {
        if (kDebugMode) {
          print('[NT4] Ignoring text message, not an array');
        }
      }

      for (var msg in rxArr) {
        if (msg is! Map) {
          if (kDebugMode) {
            print('[NT4] Ignoring text message, not a json object');
          }
          continue;
        }

        var method = msg['method'];
        var params = msg['params'];

        if (method == null || method is! String) {
          if (kDebugMode) {
            print('[NT4] Ignoring text message, method not string');
          }
          continue;
        }

        if (params == null || params is! Map) {
          if (kDebugMode) {
            print('[NT4] Ignoring text message, params not json object');
          }
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
        } else if (method == 'unannounce') {
          NT4Topic? removedTopic = announcedTopics[params['id']];
          if (removedTopic == null) {
            if (kDebugMode) {
              print(
                  '[NT4] Ignorining unannounce, topic was not previously announced');
            }
            return;
          }
          announcedTopics.remove(removedTopic.id);
        } else if (method == 'properties') {
        } else {
          if (kDebugMode) {
            print('[NT4] Ignoring text message - unknown method $method');
          }
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
          // int typeID = msg[2] as int;
          var value = msg[3];

          if (topicID >= 0) {
            NT4Topic topic = announcedTopics[topicID]!;
            lastAnnouncedValues[topic.name] = value;
            for (NT4Subscription sub in _subscriptions.values) {
              if (sub.topic == topic.name) {
                sub.updateValue(value);
              }
            }
          } else if (topicID == -1) {
            _wsHandleRecieveTimestamp(timestampUS, value as int);
          } else {
            if (kDebugMode) {
              print('[NT4] ignoring binary data, invalid topic ID');
            }
          }
        } catch (err) {
          done = true;
        }
      }
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
      Object.hashAllUnordered([periodicRateSeconds, all, topicsOnly, prefix]);
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

class NT4Subscription {
  final String topic;
  final NT4SubscriptionOptions options;
  final int uid;

  int useCount = 0;

  Object? currentValue;
  final List<Function(Object?)> _listeners = [];

  NT4Subscription({
    required this.topic,
    this.options = const NT4SubscriptionOptions(),
    this.uid = -1,
  });

  void listen(Function(Object?) onChanged) {
    _listeners.add(onChanged);
  }

  Stream<Object?> periodicStream() async* {
    while (true) {
      yield currentValue;
      await Future.delayed(
          Duration(milliseconds: (options.periodicRateSeconds * 1000).round()));
    }
  }

  void updateValue(Object? value) {
    currentValue = value;
    for (var listener in _listeners) {
      listener(currentValue);
    }
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
  int get hashCode => Object.hashAllUnordered([topic, options]);
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
    'protobuff': 5,
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
  static const kBoolArr = 'boolean[]';
  static const kFloat64Arr = 'double[]';
  static const kIntArr = 'int[]';
  static const kFloat32Arr = 'float[]';
  static const kStringArr = 'string[]';
}
