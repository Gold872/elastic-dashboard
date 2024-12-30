import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

abstract class NTWidgetModel extends ChangeNotifier {
  String get type;

  final NTConnection ntConnection;
  final SharedPreferences preferences;

  late double _period;

  late String _topic;

  String get topic => _topic;

  set topic(value) => _topic = value;

  get period => _period;

  set period(value) => _period = value;

  bool _disposed = false;
  bool _forceDispose = false;

  NTWidgetModel({
    required this.ntConnection,
    required this.preferences,
    required String topic,
    double? period,
  }) : _topic = topic {
    this.period = period ??
        preferences.getDouble(PrefKeys.defaultPeriod) ??
        Defaults.defaultPeriod;

    init();
  }

  NTWidgetModel.fromJson({
    required this.ntConnection,
    required this.preferences,
    required Map<String, dynamic> jsonData,
  }) {
    _topic = tryCast(jsonData['topic']) ?? '';

    _period = tryCast(jsonData['period']) ??
        preferences.getDouble(PrefKeys.defaultPeriod) ??
        Defaults.defaultPeriod;

    init();
  }

  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'period': period,
    };
  }

  void init();

  void unSubscribe();

  void disposeWidget({bool deleting = false});

  void resetSubscription();

  List<String> getAvailableDisplayTypes();

  List<Widget> getEditProperties(BuildContext context) {
    return const [];
  }

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

class SingleTopicNTWidgetModel extends NTWidgetModel {
  String _typeOverride = 'NTWidget';
  @override
  String get type => _typeOverride;

  String dataType = 'Unknown';

  NT4Subscription? subscription;
  NT4Topic? ntTopic;

  SingleTopicNTWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.dataType = 'Unknown',
    super.period,
  }) : super();

  SingleTopicNTWidgetModel.createDefault({
    required super.ntConnection,
    required super.preferences,
    required String type,
    required super.topic,
    this.dataType = 'Unknown',
    super.period,
  })  : _typeOverride = type,
        super();

  SingleTopicNTWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    dataType = tryCast(jsonData['data_type']) ?? dataType;
  }

  @override
  @mustCallSuper
  Map<String, dynamic> toJson() {
    if (dataType == 'Unknown' && ntConnection.isNT4Connected) {
      createTopicIfNull();
      dataType = ntTopic?.type ?? dataType;
    }
    return {
      ...super.toJson(),
      if (dataType != 'Unknown') 'data_type': dataType,
    };
  }

  @override
  List<String> getAvailableDisplayTypes() {
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
          RadialGaugeWidget.widgetType,
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

  @override
  @mustCallSuper
  void init() async {
    subscription = ntConnection.subscribe(topic, period);
  }

  void createTopicIfNull() {
    ntTopic ??= ntConnection.getTopicFromName(topic);
  }

  @override
  void unSubscribe() {
    if (subscription != null) {
      ntConnection.unSubscribe(subscription!);
    }
    refresh();
  }

  @override
  void disposeWidget({bool deleting = false}) {}

  @override
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
}

class MultiTopicNTWidgetModel extends NTWidgetModel {
  @override
  String get type => 'NTWidget';

  List<NT4Subscription> get subscriptions => [];

  MultiTopicNTWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String dataType = '', // To allow for stubbing in NTWidgetBuilder
    super.period,
  }) : super();

  MultiTopicNTWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  @mustCallSuper
  void init() {
    initializeSubscriptions();
  }

  void initializeSubscriptions() {}

  @override
  void unSubscribe() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();
    refresh();
  }

  @override
  List<String> getAvailableDisplayTypes() {
    if (type == 'ComboBox Chooser' || type == 'Split Button Chooser') {
      return ['ComboBox Chooser', 'Split Button Chooser'];
    }

    return [type];
  }

  @override
  void disposeWidget({bool deleting = false}) {}
}

abstract class NTWidget extends StatelessWidget {
  const NTWidget({super.key});
}
