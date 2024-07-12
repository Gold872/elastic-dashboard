import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_slider.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/radial_gauge.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/voltage_view.dart';

class NTWidgetModel extends ChangeNotifier {
  String _typeOverride = 'NTWidget';
  String get type => _typeOverride;

  late String _topic;
  late double _period;
  get topic => _topic;

  set topic(value) => _topic = value;

  get period => _period;

  set period(value) => _period = value;

  String dataType = 'Unknown';

  NT4Subscription? subscription;
  NT4Topic? ntTopic;

  bool _disposed = false;
  bool _forceDispose = false;

  NTWidgetModel({
    required String topic,
    this.dataType = 'Unknown',
    double? period,
  }) : _topic = topic {
    this.period = period ?? Settings.defaultPeriod;

    init();
  }

  NTWidgetModel.createDefault({
    required String type,
    required String topic,
    this.dataType = 'Unknown',
    double? period,
  })  : _typeOverride = type,
        _topic = topic {
    this.period = period ?? Settings.defaultPeriod;

    init();
  }

  NTWidgetModel.fromJson({required Map<String, dynamic> jsonData}) {
    _topic = tryCast(jsonData['topic']) ?? '';
    _period = tryCast(jsonData['period']) ?? Settings.defaultPeriod;
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
      'topic': _topic,
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
          BooleanBox.widgetType,
          ToggleSwitch.widgetType,
          ToggleButton.widgetType,
          TextDisplay.widgetType,
        ];
      case NT4TypeStr.kFloat32:
      case NT4TypeStr.kFloat64:
      case NT4TypeStr.kInt:
        return [
          TextDisplay.widgetType,
          NumberBar.widgetType,
          NumberSlider.widgetType,
          VoltageView.widgetType,
          RadialGauge.widgetType,
          GraphWidget.widgetType,
          MatchTimeWidget.widgetType,
        ];
      case NT4TypeStr.kString:
        return [
          TextDisplay.widgetType,
          SingleColorView.widgetType,
        ];
      case NT4TypeStr.kStringArr:
        return [
          TextDisplay.widgetType,
          MultiColorView.widgetType,
        ];
      case NT4TypeStr.kBoolArr:
      case NT4TypeStr.kFloat32Arr:
      case NT4TypeStr.kFloat64Arr:
      case NT4TypeStr.kIntArr:
        return [
          TextDisplay.widgetType,
        ];
    }

    return [type];
  }

  @mustCallSuper
  void init() async {
    subscription = ntConnection.subscribe(_topic, _period);
  }

  void createTopicIfNull() {
    ntTopic ??= ntConnection.getTopicFromName(_topic);
  }

  void unSubscribe() {
    if (subscription != null) {
      ntConnection.unSubscribe(subscription!);
    }
    refresh();
  }

  void disposeWidget({bool deleting = false}) {}

  void resetSubscription() {
    if (subscription == null) {
      subscription = ntConnection.subscribe(_topic, _period);

      ntTopic = null;

      refresh();
      return;
    }

    bool resetDataType = subscription!.topic != topic;

    ntConnection.unSubscribe(subscription!);
    subscription = ntConnection.subscribe(_topic, _period);

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

  static final Function listEquals = const DeepCollectionEquality().equals;

  @protected
  List<Object> getCurrentData() {
    return [];
  }

  Stream<Object> get multiTopicPeriodicStream async* {
    final Duration delayTime = Duration(
        microseconds: ((subscription?.options.periodicRateSeconds ??
                    Settings.defaultPeriod) *
                1e6)
            .round());

    int previousHash = Object.hashAll(getCurrentData());

    while (true) {
      int currentHash = Object.hashAll(getCurrentData());

      if (previousHash != currentHash) {
        yield Object();
        previousHash = currentHash;
      }

      await Future.delayed(delayTime);
    }
  }

  void forceDispose() {
    disposeWidget(deleting: true);
    _forceDispose = true;
    dispose();
  }

  @override
  void dispose() {
    if (!hasListeners || _forceDispose) {
      super.dispose();

      _disposed = true;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void refresh() {
    Future(() => notifyListeners());
  }
}

abstract class NTWidget extends StatelessWidget {
  const NTWidget({super.key});
}
