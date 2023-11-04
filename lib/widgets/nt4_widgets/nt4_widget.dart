import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:flutter/material.dart';

class NT4WidgetNotifier extends ChangeNotifier {
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

mixin NT4Widget on StatelessWidget {
  String get type;

  late String topic;
  late double period;

  NT4Subscription? subscription;
  NT4WidgetNotifier? notifier;
  NT4Topic? nt4Topic;

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
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

    if (nt4Topic == null) {
      return [type];
    }

    switch (nt4Topic!.type) {
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

  void init() async {
    subscription = nt4Connection.subscribe(topic, period);
  }

  void createTopicIfNull() {
    nt4Topic ??= nt4Connection.getTopicFromName(topic);
  }

  void dispose({bool deleting = false}) {}

  void unSubscribe() {
    if (subscription != null) {
      nt4Connection.unSubscribe(subscription!);
    }
  }

  void resetSubscription() {
    if (subscription == null) {
      subscription = nt4Connection.subscribe(topic, period);

      nt4Topic = null;
      return;
    }

    nt4Connection.unSubscribe(subscription!);
    subscription = nt4Connection.subscribe(topic, period);

    nt4Topic = null;

    refresh();
  }

  void refresh() {
    Future(() async {
      notifier?.refresh();
    });
  }
}
