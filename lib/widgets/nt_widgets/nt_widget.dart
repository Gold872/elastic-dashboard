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
  bool _disposed = false;
  bool _forceDispose = false;

  void forceDispose() {
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

  @protected
  NT4Subscription? subscription;
  @protected
  NTWidgetModel? notifier;
  @protected
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
    subscription = ntConnection.subscribe(topic, period);
  }

  @protected
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
