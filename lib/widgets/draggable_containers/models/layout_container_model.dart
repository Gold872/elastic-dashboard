import 'dart:ui';

import 'package:flutter/foundation.dart';

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
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'type': type,
    'properties': getProperties(),
  };

  Map<String, dynamic> getProperties() => {};

  bool willAcceptWidget(WidgetContainerModel widget, {Offset? globalPosition});

  void addWidget(WidgetContainerModel widget);

  void removeWidget(WidgetContainerModel widget);
}
