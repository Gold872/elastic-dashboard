import 'package:flutter/material.dart';
import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ReefModel extends MultiTopicNTWidgetModel {
  @override
  String type = Reef.widgetType;

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

  ReefModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool sortOptions = false,
    super.dataType,
    super.period,
  })  : _sortOptions = sortOptions,
        super();

  ReefModel.fromJson({
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

class Reef extends NTWidget {
  static const String widgetType = 'Reef';

  const Reef({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    ReefModel model = cast(context.watch<NTWidgetModel>());

    String? preview = model.previousSelected ?? model.previousDefault;

    bool showWarning = model.previousActive != preview;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hexagon at 20% of widget size
        _RotatingHexagon(),
        const SizedBox(height: 10),
        // Original Reef Controls
        Row(
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
        ),
      ],
    );
  }
}

class _RotatingHexagon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 20% of the available space from the parent widget
        double availableSize = min(constraints.maxWidth, constraints.maxHeight);
        double hexagonSize = availableSize * 0.2; // 20% of widget size

        return CustomPaint(
          size: Size(hexagonSize, hexagonSize),
          painter: HexagonPainter(),
        );
      },
    );
  }
}

class HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    // Use the full available space minus a small margin
    final radius = min(size.width, size.height) / 2 - 10;

    // Save the canvas state
    canvas.save();

    // Move to center for rotation
    canvas.translate(center.dx, center.dy);

    // Define ONE side of the hexagon (from one vertex to the next)
    final sideLength = radius;

    // Start at the top vertex and draw to the next vertex
    final path = Path();
    path.moveTo(0, -radius);  // Top vertex
    path.lineTo(sideLength * cos(pi/6), -radius + sideLength * sin(pi/6)); // Next vertex
    canvas.rotate(pi / 2); // Rotate 60 degrees (π/3 radians)

    // Draw the same side 6 times, rotating 60 degrees each time
    for (int i = 0; i < 6; i++) {
      canvas.drawPath(path, paint);
      canvas.rotate(pi / 3); // Rotate 60 degrees (π/3 radians)
    }

    // Restore canvas state
    canvas.restore();

    // Add center dot (scale with size)
    final centerPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    final dotSize = min(size.width, size.height) * 0.05; // 5% of the smallest dimension
    canvas.drawCircle(center, dotSize, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
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
    return Tooltip(
      message: selected ?? '',
      waitDuration: const Duration(milliseconds: 250),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: Icons.remove,
            color: Colors.red,
            onPressed: () => onValueChanged(-1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "L${selected ?? ''}",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _buildControlButton(
            icon: Icons.add,
            color: Colors.green,
            onPressed: () => onValueChanged(1),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Position //IconButton(

      // icon: Icon(icon, size: 16.0, color: color),
      // padding: const EdgeInsets.all(4),
      // constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      // splashRadius: 18,
      // onPressed: onPressedת
    // );
  }
}