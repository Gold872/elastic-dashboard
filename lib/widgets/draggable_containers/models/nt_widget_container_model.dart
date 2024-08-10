import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/empty_nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'widget_container_model.dart';

class NTWidgetContainerModel extends WidgetContainerModel {
  final NTConnection ntConnection;
  late NTWidget child;
  late NTWidgetModel childModel;

  NTWidgetContainerModel({
    required this.ntConnection,
    required super.preferences,
    required super.initialPosition,
    required super.title,
    required this.childModel,
    super.enabled,
  });

  NTWidgetContainerModel.fromJson({
    required this.ntConnection,
    required super.jsonData,
    required super.preferences,
    super.enabled,
    super.onJsonLoadingWarning,
  }) : super.fromJson();

  @override
  void init() {
    super.init();

    minWidth = NTWidgetBuilder.getMinimumWidth(childModel);
    minHeight = NTWidgetBuilder.getMinimumHeight(childModel);

    NTWidget? childWidget = NTWidgetBuilder.buildNTWidgetFromModel(childModel);

    if (childWidget != null) {
      child = childWidget;
    } else {
      childWidget = const EmptyNTWidget();
      child = childWidget;
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': childModel.type,
      'properties': getChildJson(),
    };
  }

  Map<String, dynamic> getChildJson() {
    return childModel.toJson();
  }

  @override
  void fromJson(Map<String, dynamic> jsonData,
      {Function(String errorMessage)? onJsonLoadingWarning}) {
    super.fromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);

    if (!jsonData.containsKey('type')) {
      onJsonLoadingWarning?.call(
          'NetworkTables widget does not specify a widget type, defaulting to blank placeholder widget');
    }

    Map<String, dynamic> widgetProperties = {};

    if (jsonData.containsKey('properties')) {
      widgetProperties = tryCast(jsonData['properties']) ?? {};
    } else {
      onJsonLoadingWarning?.call(
          'Network tables widget does not have any properties, defaulting to an empty properties map.');
    }

    String type = tryCast(jsonData['type']) ?? '';

    childModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      type,
      widgetProperties,
      onWidgetTypeNotFound: onJsonLoadingWarning,
    );
  }

  @override
  void disposeModel({bool deleting = false}) {
    super.disposeModel(deleting: deleting);

    childModel.disposeWidget(deleting: deleting);
  }

  @override
  void forceDispose() {
    super.forceDispose();
    childModel.forceDispose();
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    childModel.unSubscribe();
  }

  @override
  void updateGridSize(int oldGridSize, int newGridSize) {
    super.updateGridSize(oldGridSize, newGridSize);
    updateMinimumSize();
  }

  @override
  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Properties'),
          content: SizedBox(
            width: 353,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  List<Widget>? childProperties =
                      childModel.getEditProperties(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...getContainerEditProperties(),
                      const SizedBox(height: 5),
                      getWidgetTypeProperties(setState),
                      const Divider(),
                      // Settings for the widget inside (only if there are properties)
                      if (childProperties.isNotEmpty) ...[
                        Text('${childModel.type} Widget Settings'),
                        const SizedBox(height: 5),
                        ...childProperties,
                        const Divider(),
                      ],
                      // Settings for the NT Connection
                      ...getNTEditProperties(),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                childModel.refresh();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).then((_) {
      childModel.refresh();
    });
  }

  Widget getWidgetTypeProperties(StateSetter setState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Text('Widget Type')),
        DialogDropdownChooser<String>(
          choices: childModel.getAvailableDisplayTypes(),
          initialValue: childModel.type,
          onSelectionChanged: (String? value) {
            setState(() {
              changeChildToType(value);
            });
          },
        ),
      ],
    );
  }

  List<Widget> getNTEditProperties() {
    return [
      const Text('Network Tables Settings (Advanced)'),
      const SizedBox(height: 5),
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Topic
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                childModel.topic = value;
                childModel.resetSubscription();
              },
              label: 'Topic',
              initialText: childModel.topic,
            ),
          ),
          const SizedBox(width: 5),
          // Period
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newPeriod = double.tryParse(value);
                if (newPeriod == null || newPeriod <= 0.01) {
                  return;
                }

                childModel.period = newPeriod;
                childModel.resetSubscription();
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Period',
              initialText: childModel.period.toString(),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  List<ContextMenuEntry> getContextMenuItems() {
    List<ContextMenuEntry> widgetTypes = [];
    for (String type in childModel.getAvailableDisplayTypes()) {
      widgetTypes.add(
        MenuItem(
          label: type,
          icon: (childModel.type == type) ? Icons.check : null,
          onSelected: () {
            if (childModel.type != type) {
              changeChildToType(type);
            }
          },
          value: childModel.type != type,
        ),
      );
    }
    return [
      MenuItem.submenu(
        label: 'Show As',
        items: widgetTypes,
      ),
    ];
  }

  @override
  WidgetContainer getDraggingWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: draggingRect.width,
      height: draggingRect.height,
      cornerRadius:
          preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
      opacity: 0.80,
      child: ChangeNotifierProvider.value(
        value: childModel,
        child: child,
      ),
    );
  }

  @override
  WidgetContainer getWidgetContainer(BuildContext context) {
    return WidgetContainer(
      title: title,
      width: displayRect.width,
      height: displayRect.height,
      cornerRadius:
          preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
      opacity: (previewVisible) ? 0.25 : 1.00,
      child: Opacity(
        opacity: (enabled) ? 1.00 : 0.50,
        child: AbsorbPointer(
          absorbing: !enabled,
          child: ChangeNotifierProvider.value(
            value: childModel,
            child: child,
          ),
        ),
      ),
    );
  }

  void changeChildToType(String? type) {
    if (type == null) {
      return;
    }

    if (type == childModel.type) {
      return;
    }

    childModel.disposeWidget(deleting: true);
    childModel.unSubscribe();
    childModel.forceDispose();

    childModel = NTWidgetBuilder.buildNTModelFromType(
      ntConnection,
      preferences,
      type,
      childModel.topic,
      dataType: childModel.dataType,
      period: (type != 'Graph')
          ? childModel.period
          : preferences.getDouble(PrefKeys.defaultGraphPeriod) ??
              Defaults.defaultGraphPeriod,
    );

    NTWidget? newWidget = NTWidgetBuilder.buildNTWidgetFromModel(childModel);

    newWidget ??= const EmptyNTWidget();

    child = newWidget;

    minWidth = NTWidgetBuilder.getMinimumWidth(childModel);
    minHeight = NTWidgetBuilder.getMinimumHeight(childModel);

    notifyListeners();
  }

  void updateMinimumSize() {
    minWidth = NTWidgetBuilder.getMinimumWidth(childModel);
    minHeight = NTWidgetBuilder.getMinimumHeight(childModel);

    notifyListeners();
  }
}
