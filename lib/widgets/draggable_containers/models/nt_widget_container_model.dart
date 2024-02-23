import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'widget_container_model.dart';

class NTWidgetContainerModel extends WidgetContainerModel {
  late NTWidget child;
  NTWidgetModel childModel = NTWidgetModel();

  NTWidgetContainerModel({
    required super.initialPosition,
    required super.title,
    required this.child,
    super.enabled,
  });

  NTWidgetContainerModel.fromJson({
    required super.jsonData,
    super.enabled,
    super.onJsonLoadingWarning,
  }) : super.fromJson();

  @override
  void init() {
    super.init();

    minWidth = NTWidgetBuilder.getMinimumWidth(child);
    minHeight = NTWidgetBuilder.getMinimumHeight(child);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'type': child.type,
      'properties': getChildJson(),
    };
  }

  Map<String, dynamic> getChildJson() {
    return child.toJson();
  }

  @override
  void fromJson(Map<String, dynamic> jsonData,
      {Function(String errorMessage)? onJsonLoadingWarning}) {
    super.fromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);

    if (!jsonData.containsKey('type')) {
      onJsonLoadingWarning?.call(
          'NetworkTables widget does not specify a widget type, defaulting to text display widget');
    }

    Map<String, dynamic> widgetProperties = {};

    if (jsonData.containsKey('properties')) {
      widgetProperties = tryCast(jsonData['properties']) ?? {};
    } else {
      onJsonLoadingWarning?.call(
          'Network tables widget does not have any properties, defaulting to an empty properties map.');
    }

    String type = tryCast(jsonData['type']) ?? '';

    child = NTWidgetBuilder.buildNTWidgetFromJson(type, widgetProperties,
        onWidgetTypeNotFound: onJsonLoadingWarning);
    childModel.forceDispose();

    childModel = NTWidgetModel();
  }

  @override
  void disposeModel({bool deleting = false}) {
    super.disposeModel(deleting: deleting);

    child.dispose(deleting: deleting);
  }

  @override
  void forceDispose() {
    super.forceDispose();
    childModel.forceDispose();
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    child.unSubscribe();
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
                      child.getEditProperties(context);
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
                        Text('${child.type} Widget Settings'),
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
                child.refresh();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).then((_) {
      child.refresh();
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
          choices: child.getAvailableDisplayTypes(),
          initialValue: child.type,
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
                child.topic = value;
                child.resetSubscription();
              },
              label: 'Topic',
              initialText: child.topic,
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

                child.period = newPeriod;
                child.resetSubscription();
              },
              formatter: Constants.decimalTextFormatter(),
              label: 'Period',
              initialText: child.period.toString(),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  List<ContextMenuEntry> getContextMenuItems() {
    List<ContextMenuEntry> widgetTypes = [];
    for (String type in child.getAvailableDisplayTypes()) {
      widgetTypes.add(
        MenuItem(
          label: type,
          icon: (child.type == type) ? Icons.check : null,
          onSelected: () {
            if (child.type != type) {
              changeChildToType(type);
            }
          },
          value: child.type != type,
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
      opacity: 0.80,
      child: ChangeNotifierProvider<NTWidgetModel>.value(
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

    if (type == child.type) {
      return;
    }

    NTWidget? newWidget = NTWidgetBuilder.buildNTWidgetFromType(
      type,
      child.topic,
      dataType: child.dataType,
      period: (type != 'Graph') ? child.period : Settings.defaultGraphPeriod,
    );

    if (newWidget == null) {
      return;
    }

    child.dispose(deleting: true);
    child.unSubscribe();
    childModel.forceDispose();

    child = newWidget;
    childModel = NTWidgetModel();

    minWidth = NTWidgetBuilder.getMinimumWidth(child);
    minHeight = NTWidgetBuilder.getMinimumHeight(child);

    notifyListeners();
  }

  void updateMinimumSize() {
    minWidth = NTWidgetBuilder.getMinimumWidth(child);
    minHeight = NTWidgetBuilder.getMinimumHeight(child);

    notifyListeners();
  }
}
