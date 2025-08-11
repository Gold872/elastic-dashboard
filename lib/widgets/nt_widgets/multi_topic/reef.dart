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
  int indexCurrentOption = 0;

  // Track which buttons are currently selected
  Set<int> selectedButtonIndices = {};

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
    selectedButtonIndices.clear();

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
    if (_selectedTopic != null) return;

    NT4Topic? existing = ntConnection.getTopicFromName(selectedTopicName);

    if (existing != null) {
      existing.properties.addAll({'retained': true});
      ntConnection.publishTopic(existing);
      _selectedTopic = existing;
    } else {
      _selectedTopic = ntConnection.publishNewTopic(
        selectedTopicName,
        NT4TypeStr.kString,
        properties: {'retained': true},
      );
    }
  }

  void publishSelectedValue(String? selected, [bool initial = false]) {
    if (selected == null || !ntConnection.isNT4Connected) return;

    if (_selectedTopic == null) publishSelectedTopic();

    ntConnection.updateDataFromTopic(
      _selectedTopic!,
      selected,
      initial ? 0 : null,
    );
  }

  void selectOptionByIndex(int index) {
    // Allow any button index from 0 to 35 (36 total buttons)
    if (index < 0 || index >= 36) {
      return;
    }

    // Toggle the button selection
    if (selectedButtonIndices.contains(index)) {
      selectedButtonIndices.remove(index);
    } else {
      selectedButtonIndices.add(index);
    }

    indexCurrentOption = index;

    // Only publish value if we have actual options and index is within options range
    if (previousOptions != null && index < previousOptions!.length) {
      String selectedOption = previousOptions![index];
      publishSelectedValue(selectedOption);
    }

    notifyListeners();
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
        SizedBox(
          width: 450,
          height: 450,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating hexagon is now a child of the Stack
              _RotatingHexagon(),
              // CoralLevel buttons are also a child of the Stack
              _CoralLevel(
                selected: preview,
                options: model.previousOptions ?? [],
                selectedButtonIndices: model.selectedButtonIndices,
                textController: model._searchController,
                onOptionSelected: (int index) {
                  model.selectOptionByIndex(index);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "L${preview ?? ''}",
              style: Theme.of(context).textTheme.bodyMedium,
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
        final side = min(constraints.maxWidth, constraints.maxHeight) * 0.5;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              size: Size(side, side),
              painter: HexagonPainter(),
            ),
          ),
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
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final path = Path()..moveTo(radius * cos(-pi / 6), radius * sin(-pi / 6));
    canvas.rotate(pi / 2);
    for (int i = 0; i < 6; i++) {
      path.lineTo(radius * cos(i * pi / 3 + -pi / 6),
          radius * sin(i * pi / 3 + -pi / 6));
    }

    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();

    final centerPaint = Paint()..color = Colors.cyan;
    final dotSize = min(size.width, size.height) * 0.05;
    canvas.drawCircle(center, dotSize, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoralLevel extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Set<int> selectedButtonIndices;
  final Function(int index) onOptionSelected;
  final TextEditingController textController;

  const _CoralLevel({
    required this.options,
    required this.onOptionSelected,
    required this.textController,
    this.selected,
    required this.selectedButtonIndices,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildControlButton(constraints);
      },
    );
  }

  Widget _buildControlButton(BoxConstraints constraints) {
    final double widgetSize = min(constraints.maxWidth, constraints.maxHeight);
    final double buttonSize =
        widgetSize * 0.08; // Smaller buttons for better fit
    final double offsetFromCenter =
        widgetSize * 0.38; // Increased offset now that we have more space
    const double globalRotation = pi / 6;

    // Generate all 36 buttons (6 faces × 6 buttons per face)
    List<String> allButtons = List.generate(36, (index) {
      if (index < options.length) {
        return options[index];
      } else {
        return 'Button ${index + 1}'; // Default text for buttons without options
      }
    });

    Widget buildSquare(int faceIndex, double iconCounterRotate) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int row = 0; row < 2; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int col = 0; col < 3; col++)
                  () {
                    final int buttonIndex = faceIndex * 6 + row * 3 + col;
                    final String buttonText = allButtons[buttonIndex];

                    // Check if this button is selected
                    final bool isSelected =
                        selectedButtonIndices.contains(buttonIndex);

                    return Container(
                      padding: EdgeInsets.all(buttonSize * 0.1),
                      child: SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(buttonSize, buttonSize),
                            maximumSize: Size(buttonSize, buttonSize),
                            backgroundColor: isSelected ? Colors.blue : null,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            print('Button $buttonIndex pressed'); // Debug print
                            onOptionSelected(buttonIndex);
                          },
                          child: Transform.rotate(
                            angle: -iconCounterRotate,
                            child: Text(
                              buttonText.length <= 2
                                  ? buttonText
                                  : buttonText.substring(0, 2),
                              style: TextStyle(
                                fontSize: buttonSize * 0.25,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
        ],
      );
    }

    return Container(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (int face = 0; face < 6; face++)
            () {
              final double midAngle =
                  -pi / 2 + face * (pi / 3) + pi / 6 + globalRotation;

              final Offset basePos = Offset(
                offsetFromCenter * cos(midAngle),
                offsetFromCenter * sin(midAngle),
              );

              final double rotation = midAngle;

              return Transform.translate(
                offset: basePos,
                child: Transform.rotate(
                  angle: rotation,
                  child: buildSquare(face, rotation),
                ),
              );
            }(),
        ],
      ),
    );
  }
}
