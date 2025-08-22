import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CoralLevelChooserModel extends MultiTopicNTWidgetModel {
  @override
  String type = CoralLevelChooser.widgetType;

  String get optionsTopicName => '$topic/options';
  String get selectedTopicName => '$topic/selected';
  String get activeTopicName => '$topic/active';
  String get defaultTopicName => '$topic/default';

  late NT4Subscription optionsSubscription;
  late NT4Subscription selectedSubscription;
  late NT4Subscription activeSubscription;
  late NT4Subscription defaultSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        optionsSubscription,
        selectedSubscription,
        activeSubscription,
        defaultSubscription,
      ];

  late Listenable chooserStateListenable;

  final TextEditingController _searchController = TextEditingController();

  String? previousDefault;
  String? previousSelected;
  String? previousActive;
  List<String>? previousOptions;
  int indexCurrnetOption = 0;

  NT4Topic? _selectedTopic;

  bool _sortOptions = false;

  bool get sortOptions => _sortOptions;

  set sortOptions(bool value) {
    _sortOptions = value;
    previousOptions?.sort();
    refresh();
  }

  CoralLevelChooserModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool sortOptions = false,
    super.dataType,
    super.period,
  })  : _sortOptions = sortOptions,
        super();

  CoralLevelChooserModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _sortOptions = tryCast(jsonData['sort_options']) ?? _sortOptions;
  }

  @override
  void initializeSubscriptions() {
    optionsSubscription =
        ntConnection.subscribe(optionsTopicName, super.period);
    selectedSubscription =
        ntConnection.subscribe(selectedTopicName, super.period);
    activeSubscription = ntConnection.subscribe(activeTopicName, super.period);
    defaultSubscription =
        ntConnection.subscribe(defaultTopicName, super.period);
    chooserStateListenable = Listenable.merge(subscriptions);
    chooserStateListenable.addListener(onChooserStateUpdate);

    previousOptions = null;
    previousActive = null;
    previousDefault = null;
    previousSelected = null;

    // Initial caching of the chooser state, when switching
    // topics the listener won't be called, so we have to call it manually
    onChooserStateUpdate();
  }

  @override
  void resetSubscription() {
    _selectedTopic = null;
    chooserStateListenable.removeListener(onChooserStateUpdate);

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'sort_options': _sortOptions,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      DialogToggleSwitch(
        label: 'Sort Options Alphabetically',
        initialValue: _sortOptions,
        onToggle: (value) {
          sortOptions = value;
        },
      ),
    ];
  }

  void onChooserStateUpdate() {
    List<Object?>? rawOptions =
        optionsSubscription.value?.tryCast<List<Object?>>();

    List<String>? currentOptions = rawOptions?.whereType<String>().toList();

    if (sortOptions) {
      currentOptions?.sort();
    }

    String? currentActive = tryCast(activeSubscription.value);
    if (currentActive != null && currentActive.isEmpty) {
      currentActive = null;
    }

    String? currentSelected = tryCast(selectedSubscription.value);
    if (currentSelected != null && currentSelected.isEmpty) {
      currentSelected = null;
    }

    String? currentDefault = tryCast(defaultSubscription.value);
    if (currentDefault != null && currentDefault.isEmpty) {
      currentDefault = null;
    }

    bool hasValue = currentOptions != null ||
        currentActive != null ||
        currentDefault != null;

    bool publishCurrent =
        hasValue && previousSelected != null && currentSelected == null;

    // We only want to publish the selected topic if we're getting values
    // from the others, since it means the chooser is published on network tables
    if (hasValue) {
      publishSelectedTopic();
    }

    if (currentOptions != null) {
      previousOptions = currentOptions;
    }
    if (currentSelected != null) {
      previousSelected = currentSelected;
    }
    if (currentActive != null) {
      previousActive = currentActive;
    }
    if (currentDefault != null) {
      previousDefault = currentDefault;
    }

    if (publishCurrent) {
      publishSelectedValue(previousSelected, true);
    }

    notifyListeners();
  }

  void publishSelectedTopic() {
    if (_selectedTopic != null) {
      return;
    }

    NT4Topic? existing = ntConnection.getTopicFromName(selectedTopicName);

    if (existing != null) {
      existing.properties.addAll({
        'retained': true,
      });
      ntConnection.publishTopic(existing);
      _selectedTopic = existing;
    } else {
      _selectedTopic = ntConnection.publishNewTopic(
        selectedTopicName,
        NT4TypeStr.kString,
        properties: {
          'retained': true,
        },
      );
    }
  }

  void publishSelectedValue(String? selected, [bool initial = false]) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    if (_selectedTopic == null) {
      publishSelectedTopic();
    }

    ntConnection.updateDataFromTopic(
      _selectedTopic!,
      selected,
      initial ? 0 : null,
    );
  }
}

class CoralLevelChooser extends NTWidget {
  static const String widgetType = 'CoralLevel Chooser';

  const CoralLevelChooser({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CoralLevelChooserModel model = cast(context.watch<NTWidgetModel>());

    String? preview = model.previousSelected ?? model.previousDefault;

    bool showWarning = model.previousActive != preview;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 36.0,
            ),
            child: _CoralLevel(
              selected: preview,
              options: model.previousOptions ?? [preview ?? ''],
              textController: model._searchController,
              onValueChanged: (int value) {
                model.indexCurrnetOption += value;
                if (model.indexCurrnetOption < 0) {
                  model.indexCurrnetOption = 0;
                } else if (model.indexCurrnetOption >=
                    model.previousOptions!.length) {
                  model.indexCurrnetOption = model.previousOptions!.length - 1;
                }
                model.publishSelectedValue(
                    model.previousOptions?.elementAt(model.indexCurrnetOption));
              },
            ),
          ),
        ),
        const SizedBox(width: 5),
        (showWarning)
            ? const Tooltip(
                message:
                    'Selected value has not been published to Network Tables.\nRobot code will not be receiving the correct value.',
                child: Icon(Icons.priority_high, color: Colors.red),
              )
            : const Icon(Icons.check, color: Colors.green),
      ],
    );
  }
}

class _CoralLevel extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(int value) onValueChanged;
  final TextEditingController textController;

  const _CoralLevel({
    required this.options,
    required this.onValueChanged,
    required this.textController,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Tooltip(
        message: selected ?? '',
        waitDuration: const Duration(microseconds: 250),
        child: Row(
          children: [
            _createIncrementDicrementButton(
                Icons.remove, Colors.red, () => onValueChanged(-1)),
            Text("L" + (selected ?? ''), textScaleFactor: 3),
            _createIncrementDicrementButton(
                Icons.add, Colors.green, () => onValueChanged(1))
          ],
        ),
      ),
    );
  }

  Widget _createIncrementDicrementButton(
      IconData icon, Color color, VoidCallback? onPressed) {
    return RawMaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      constraints: BoxConstraints(minWidth: 20.0, minHeight: 20.0),
      onPressed: onPressed,
      elevation: 2.0,
      child: Icon(
        icon,
        color: color,
        size: 40.0,
      ),
      shape: CircleBorder(),
    );
  }
}
