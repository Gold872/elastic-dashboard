import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';

class NTWidgetNotifier extends ChangeNotifier {
  // No idea why this is needed, but it was throwing errors ¯\_(ツ)_/¯
  bool _disposed = false;

  @override
  void dispose() {
    super.dispose();

    _disposed = true;
  }

  void refresh() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

abstract class NTWidget extends StatelessWidget {
  String get type;

  late String topic;
  late double period;

  String dataType = 'Unknown';

  NT4Subscription? subscription;
  NTWidgetNotifier? notifier;
  NT4Topic? ntTopic;

  NTWidget({
    super.key,
    required this.topic,
    this.dataType = 'Unknown',
    double? period,
  }) {
    this.period = period ?? Settings.defaultPeriod;

    init();
  }

  NTWidget.fromJson({super.key, required Map<String, dynamic> jsonData}) {
    topic = tryCast(jsonData['topic']) ?? '';
    period = tryCast(jsonData['period']) ?? Settings.defaultPeriod;
    dataType = tryCast(jsonData['data_type']) ?? dataType;

    init();
  }

  @mustCallSuper
  Map<String, dynamic> toJson() {
    if (dataType == 'Unknown' && ntConnection.isNT4Connected) {
      createTopicIfNull();
      dataType = ntTopic?.type ?? dataType;
    }
    return {
      'topic': topic,
      'period': period,
      if (dataType != 'Unknown') 'data_type': dataType,
    };
  }

  List<Widget> getEditProperties(BuildContext context) {
    return const [];
  }

  List<String> getAvailableDisplayTypes() {
    if (type == 'ComboBox Chooser' || type == 'Split Button Chooser') {
      return ['ComboBox Chooser', 'Split Button Chooser'];
    }

    createTopicIfNull();
    dataType = ntTopic?.type ?? dataType;

    switch (dataType) {
      case NT4TypeStr.kBool:
        return [
          'Boolean Box',
          'Toggle Switch',
          'Toggle Button',
          'Text Display',
        ];
      case NT4TypeStr.kFloat32:
      case NT4TypeStr.kFloat64:
      case NT4TypeStr.kInt:
        return [
          'Text Display',
          'Number Bar',
          'Number Slider',
          'Voltage View',
          'Graph',
          'Match Time',
        ];
      case NT4TypeStr.kString:
        return ['Text Display', 'Single Color View'];
      case NT4TypeStr.kStringArr:
        return ['Text Display', 'Multi Color View'];
      case NT4TypeStr.kBoolArr:
      case NT4TypeStr.kFloat32Arr:
      case NT4TypeStr.kFloat64Arr:
      case NT4TypeStr.kIntArr:
        return ['Text Display'];
    }

    return [type];
  }

  @mustCallSuper
  void init() async {
    subscription = ntConnection.subscribe(topic, period);
  }

  void createTopicIfNull() {
    ntTopic ??= ntConnection.getTopicFromName(topic);
  }

  void dispose({bool deleting = false}) {}

  void unSubscribe() {
    if (subscription != null) {
      ntConnection.unSubscribe(subscription!);
    }
  }

  void resetSubscription() {
    if (subscription == null) {
      subscription = ntConnection.subscribe(topic, period);

      ntTopic = null;

      refresh();
      return;
    }

    bool resetDataType = subscription!.topic != topic;

    ntConnection.unSubscribe(subscription!);
    subscription = ntConnection.subscribe(topic, period);

    ntTopic = null;

    createTopicIfNull();
    if (resetDataType) {
      if (ntTopic == null && ntConnection.isNT4Connected) {
        dataType = 'Unknown';
      } else {
        dataType = ntTopic?.type ?? dataType;
      }
    }

    refresh();
  }

  @mustCallSuper
  void refresh() {
    Future(() async {
      notifier?.refresh();
      subscription?.requestNewValue();
    });
  }

  static final Function listEquals = const DeepCollectionEquality().equals;

  @protected
  List<Object> getCurrentData() {
    return [];
  }

  @protected
  Stream<Object> get multiTopicPeriodicStream async* {
    List<Object> previousData = getCurrentData();

    while (true) {
      List<Object> currentData = getCurrentData();

      if (!listEquals(previousData, currentData)) {
        yield Object();
        previousData = currentData;
      }

      await Future.delayed(Duration(
          milliseconds: ((subscription?.options.periodicRateSeconds ??
                      Settings.defaultPeriod) *
                  1000)
              .round()));
    }
  }
}
