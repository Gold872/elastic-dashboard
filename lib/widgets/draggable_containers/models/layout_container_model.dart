import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'nt_widget_container_model.dart';
import 'widget_container_model.dart';

abstract class LayoutContainerModel extends WidgetContainerModel {
  String get type;

  LayoutContainerModel({
    required super.preferences,
    required super.initialPosition,
    required super.title,
    super.minWidth,
    super.minHeight,
  }) : super();

  LayoutContainerModel.fromJson({
    required super.jsonData,
    required super.preferences,
    super.enabled,
    super.minWidth,
    super.minHeight,
    super.onJsonLoadingWarning,
  }) : super.fromJson();

  @override
  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': type,
      'properties': getProperties(),
    };
  }

  Map<String, dynamic> getProperties() {
    return {};
  }

  bool willAcceptWidget(WidgetContainerModel widget, {Offset? globalPosition});

  void addWidget(NTWidgetContainerModel model);
}
