import 'package:flutter/material.dart';
import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

// Constants for better maintainability
class ReefConstants {
  static const String widgetType = 'Reef';
  static const int totalButtons = 42;
  static const int faceButtons = 36;
  static const int edgeButtons = 6;
  static const int buttonsPerFace = 6;
  static const int facesCount = 6;
  static const double globalRotation = pi / 6;

  // Color scheme
  static const Color hexagonColor = Color.fromARGB(255, 100, 2, 93);
  static const double hexagonStrokeWidth = 5.0;
}

// Button status enum for better type safety
enum ButtonStatus {
  normal(0),
  active(1),
  warning(2),
  success(3);

  const ButtonStatus(this.value);
  final int value;

  static ButtonStatus fromInt(int value) {
    return ButtonStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ButtonStatus.normal,
    );
  }

  ButtonStatus getNextStatus() {
    switch (this) {
      case ButtonStatus.active:
        return ButtonStatus.normal;
      case ButtonStatus.normal:
      case ButtonStatus.warning:
      case ButtonStatus.success:
        return ButtonStatus.active;
    }
  }
}

// Immutable color configuration
@immutable
class ButtonColorScheme {
  final Color? background;
  final Color? text;
  final Color? border;

  const ButtonColorScheme({
    this.background,
    this.text,
    this.border,
  });

  // Face button color schemes
  static const Map<ButtonStatus, ButtonColorScheme> faceColors = {
    ButtonStatus.normal: ButtonColorScheme(),
    ButtonStatus.active: ButtonColorScheme(
      background: Colors.white,
      text: Colors.black,
    ),
    ButtonStatus.warning: ButtonColorScheme(
      background: Colors.purple,
      text: Colors.white,
    ),
    ButtonStatus.success: ButtonColorScheme(
      background: Colors.green,
      text: Colors.white,
    ),
  };

  // Edge button color schemes
  static final Map<ButtonStatus, ButtonColorScheme> edgeColors = {
    ButtonStatus.normal: ButtonColorScheme(
      background: Colors.transparent,
      text: Colors.black,
      border: Colors.tealAccent[400],
    ),
    ButtonStatus.active: ButtonColorScheme(
      background: Colors.tealAccent[400],
      text: Colors.black,
      border: Colors.tealAccent[400],
    ),
    ButtonStatus.warning: ButtonColorScheme(
      background: Colors.yellow,
      text: Colors.black,
      border: Colors.yellow,
    ),
    ButtonStatus.success: ButtonColorScheme(
      background: Colors.lime,
      text: Colors.black,
      border: Colors.lime,
    ),
  };
}

class ReefModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefConstants.widgetType;

  // Topic names - computed properties for cleaner access
  String get branchsTopicName => '/reeftalbe/branchs';
  String get optionsTopicName => '$topic/options';
  String get selectedTopicName => '$topic/selected';
  String get activeTopicName => '$topic/active';
  String get defaultTopicName => '$topic/default';

  // Subscriptions
  late NT4Subscription branchesSub;
  late NT4Subscription optionsSubscription;
  late NT4Subscription selectedSubscription;
  late NT4Subscription activeSubscription;
  late NT4Subscription defaultSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        branchesSub,
        optionsSubscription,
        selectedSubscription,
        activeSubscription,
        defaultSubscription,
      ];

  late Listenable chooserStateListenable;
  final TextEditingController _searchController = TextEditingController();

  // State variables
  String? _previousDefault;
  String? _previousSelected;
  String? _previousActive;
  List<String>? _previousOptions;
  int _currentOptionIndex = 0;
  final Set<int> _selectedButtonIndices = <int>{};
  NT4Topic? _selectedTopic;
  bool _sortOptions = false;

  // Getters for encapsulation
  String? get previousDefault => _previousDefault;
  String? get previousSelected => _previousSelected;
  String? get previousActive => _previousActive;
  List<String>? get previousOptions => _previousOptions;
  Set<int> get selectedButtonIndices => Set.from(_selectedButtonIndices);
  TextEditingController get searchController => _searchController;

  bool get sortOptions => _sortOptions;
  set sortOptions(bool value) {
    if (_sortOptions != value) {
      _sortOptions = value;
      _previousOptions?.sort();
      refresh();
    }
  }

  // Enhanced button status retrieval with better error handling
  ButtonStatus getButtonStatus(int buttonIndex) {
    if (buttonIndex < 0 || buttonIndex >= ReefConstants.totalButtons) {
      return ButtonStatus.normal;
    }

    final branchData = branchesSub.value;
    if (branchData is! List || buttonIndex >= branchData.length) {
      return ButtonStatus.normal;
    }

    final value = branchData[buttonIndex];
    final intValue = switch (value) {
      int v => v,
      String v => int.tryParse(v) ?? 0,
      double v => v.toInt(),
      _ => 0,
    };

    return ButtonStatus.fromInt(intValue);
  }

  // Legacy support method
  bool isButtonPressed(int buttonIndex) {
    return _selectedButtonIndices.contains(buttonIndex) ||
        getButtonStatus(buttonIndex) == ButtonStatus.active;
  }

  // Constructors
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
    // Initialize all subscriptions
    branchesSub = ntConnection.subscribe(branchsTopicName, super.period);
    optionsSubscription =
        ntConnection.subscribe(optionsTopicName, super.period);
    selectedSubscription =
        ntConnection.subscribe(selectedTopicName, super.period);
    activeSubscription = ntConnection.subscribe(activeTopicName, super.period);
    defaultSubscription =
        ntConnection.subscribe(defaultTopicName, super.period);

    chooserStateListenable = Listenable.merge(subscriptions);
    chooserStateListenable.addListener(_onChooserStateUpdate);

    // Reset state
    _resetState();
    _onChooserStateUpdate();
  }

  @override
  void resetSubscription() {
    _selectedTopic = null;
    chooserStateListenable.removeListener(_onChooserStateUpdate);
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
        onToggle: (value) => sortOptions = value,
      ),
    ];
  }

  // Private helper methods
  void _resetState() {
    _previousOptions = null;
    _previousActive = null;
    _previousDefault = null;
    _previousSelected = null;
    _selectedButtonIndices.clear();
  }

  void _onChooserStateUpdate() {
    // Process options
    final rawOptions = optionsSubscription.value?.tryCast<List<Object?>>();
    List<String>? currentOptions = rawOptions?.whereType<String>().toList();

    if (sortOptions && currentOptions != null) {
      currentOptions.sort();
    }

    // Process other values with null safety
    final currentActive = _processStringValue(activeSubscription.value);
    final currentSelected = _processStringValue(selectedSubscription.value);
    final currentDefault = _processStringValue(defaultSubscription.value);

    final hasValue = currentOptions != null ||
        currentActive != null ||
        currentDefault != null;

    final shouldPublishCurrent =
        hasValue && _previousSelected != null && currentSelected == null;

    if (hasValue) {
      _publishSelectedTopic();
    }

    // Update state
    _updateState(
        currentOptions, currentSelected, currentActive, currentDefault);

    if (shouldPublishCurrent) {
      _publishSelectedValue(_previousSelected, true);
    }

    notifyListeners();
  }

  String? _processStringValue(dynamic value) {
    final stringValue = tryCast<String>(value);
    return (stringValue?.isEmpty ?? true) ? null : stringValue;
  }

  void _updateState(
    List<String>? options,
    String? selected,
    String? active,
    String? defaultValue,
  ) {
    if (options != null) _previousOptions = options;
    if (selected != null) _previousSelected = selected;
    if (active != null) _previousActive = active;
    if (defaultValue != null) _previousDefault = defaultValue;
  }

  void _publishSelectedTopic() {
    if (_selectedTopic != null) return;

    final existing = ntConnection.getTopicFromName(selectedTopicName);

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

  void _publishSelectedValue(String? selected, [bool initial = false]) {
    if (selected == null || !ntConnection.isNT4Connected) return;

    _selectedTopic ??= _createSelectedTopic();

    ntConnection.updateDataFromTopic(
      _selectedTopic!,
      selected,
      initial ? 0 : null,
    );
  }

  NT4Topic _createSelectedTopic() {
    _publishSelectedTopic();
    return _selectedTopic!;
  }

  // Public methods
  void selectOptionByIndex(int index) {
    if (!_isValidButtonIndex(index)) return;

    final currentStatus = getButtonStatus(index);
    final newStatus = currentStatus.getNextStatus();

    _updateButtonStatus(index, newStatus.value);
    _currentOptionIndex = index;

    // Publish value if within options range
    if (_previousOptions != null && index < _previousOptions!.length) {
      _publishSelectedValue(_previousOptions![index]);
    }

    notifyListeners();
  }

  bool _isValidButtonIndex(int index) {
    return index >= 0 && index < ReefConstants.totalButtons;
  }

  void _updateButtonStatus(int buttonIndex, int newStatus) {
    final currentBranchData = branchesSub.value;
    List<dynamic> branchList;

    if (currentBranchData is List) {
      branchList = List.from(currentBranchData);
    } else {
      branchList = List.filled(ReefConstants.totalButtons, 0);
    }

    // Ensure array is large enough
    while (branchList.length <= buttonIndex) {
      branchList.add(0);
    }

    branchList[buttonIndex] = newStatus;

    if (ntConnection.isNT4Connected) {
      _publishBranchStatus(branchList);
      debugPrint('Updated button $buttonIndex to status $newStatus');
    }
  }

  void _publishBranchStatus(List<dynamic> branchList) {
    NT4Topic? branchTopic = ntConnection.getTopicFromName(branchsTopicName);

    branchTopic ??= ntConnection.publishNewTopic(
      branchsTopicName,
      NT4TypeStr.kIntArr,
    );

    ntConnection.updateDataFromTopic(branchTopic, branchList);
  }
}

class Reef extends NTWidget {
  static const String widgetType = ReefConstants.widgetType;

  const Reef({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NTWidgetModel>() as ReefModel;
    final preview = model.previousSelected ?? model.previousDefault;

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.branchesSub,
        model.chooserStateListenable,
      ]),
      builder: (context, child) => Transform.scale(scale: 1, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 450,
            height: 450,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _HexagonWidget(),
                _ButtonGridWidget(
                  model: model,
                  preview: preview,
                  onOptionSelected: model.selectOptionByIndex,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _HexagonWidget extends StatelessWidget {
  const _HexagonWidget();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) * 0.5;
        return Center(
          child: CustomPaint(
            size: Size(size, size),
            painter: _HexagonPainter(),
          ),
        );
      },
    );
  }
}

class _HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ReefConstants.hexagonColor
      ..strokeWidth = ReefConstants.hexagonStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    _drawHexagon(canvas, paint, center, radius);
    _drawCenterDot(canvas, center, size);
  }

  void _drawHexagon(Canvas canvas, Paint paint, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pi / 2);

    final path = Path()..moveTo(radius * cos(-pi / 6), radius * sin(-pi / 6));

    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 + -pi / 6;
      path.lineTo(radius * cos(angle), radius * sin(angle));
    }

    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawCenterDot(Canvas canvas, Offset center, Size size) {
    final centerPaint = Paint()..color = ReefConstants.hexagonColor;
    final dotRadius = min(size.width, size.height) * 0.025;
    canvas.drawCircle(center, dotRadius, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ButtonGridWidget extends StatelessWidget {
  final ReefModel model;
  final String? preview;
  final Function(int) onOptionSelected;

  const _ButtonGridWidget({
    required this.model,
    required this.preview,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _ButtonLayout(
          model: model,
          constraints: constraints,
          onOptionSelected: onOptionSelected,
        );
      },
    );
  }
}

class _ButtonLayout extends StatelessWidget {
  final ReefModel model;
  final BoxConstraints constraints;
  final Function(int) onOptionSelected;

  const _ButtonLayout({
    required this.model,
    required this.constraints,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final config = _LayoutConfig(constraints);

    return SizedBox.fromSize(
      size: Size(constraints.maxWidth, constraints.maxHeight),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ..._buildFaceButtons(config),
          ..._buildEdgeButtons(config),
        ],
      ),
    );
  }

  List<Widget> _buildFaceButtons(_LayoutConfig config) {
    return List.generate(ReefConstants.facesCount, (face) {
      final angle =
          -pi / 2 + face * (pi / 3) + pi / 6 + ReefConstants.globalRotation;
      final position = Offset(
        config.offsetFromCenter * cos(angle),
        config.offsetFromCenter * sin(angle),
      );

      return Transform.translate(
        offset: position,
        child: Transform.rotate(
          angle: angle,
          child: _FaceButtonGrid(
            faceIndex: face,
            config: config,
            model: model,
            rotationAngle: angle,
            onPressed: onOptionSelected,
          ),
        ),
      );
    });
  }

  List<Widget> _buildEdgeButtons(_LayoutConfig config) {
    return List.generate(ReefConstants.edgeButtons, (edgeButton) {
      final angle = (edgeButton * pi / 3) + ReefConstants.globalRotation;
      final position = Offset(
        config.hexagonRadius * cos(angle),
        config.hexagonRadius * sin(angle),
      );
      final buttonIndex = ReefConstants.faceButtons + edgeButton;

      return Transform.translate(
        offset: position,
        child: _EdgeButton(
          buttonIndex: buttonIndex,
          config: config,
          model: model,
          onPressed: onOptionSelected,
        ),
      );
    });
  }
}

class _LayoutConfig {
  final double widgetSize;
  final double buttonSize;
  final double offsetFromCenter;
  final double hexagonRadius;

  _LayoutConfig(BoxConstraints constraints)
      : widgetSize = min(constraints.maxWidth, constraints.maxHeight),
        buttonSize = min(constraints.maxWidth, constraints.maxHeight) * 0.08,
        offsetFromCenter =
            min(constraints.maxWidth, constraints.maxHeight) * 0.38,
        hexagonRadius = min(constraints.maxWidth, constraints.maxHeight) * 0.15;
}

class _FaceButtonGrid extends StatelessWidget {
  final int faceIndex;
  final _LayoutConfig config;
  final ReefModel model;
  final double rotationAngle;
  final Function(int) onPressed;

  const _FaceButtonGrid({
    required this.faceIndex,
    required this.config,
    required this.model,
    required this.rotationAngle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        2,
        (row) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (col) {
            final buttonIndex =
                faceIndex * ReefConstants.buttonsPerFace + row * 3 + col;
            return _FaceButton(
              buttonIndex: buttonIndex,
              config: config,
              model: model,
              rotationAngle: rotationAngle,
              onPressed: onPressed,
            );
          }),
        ),
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  final int buttonIndex;
  final _LayoutConfig config;
  final ReefModel model;
  final double rotationAngle;
  final Function(int) onPressed;

  const _FaceButton({
    required this.buttonIndex,
    required this.config,
    required this.model,
    required this.rotationAngle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final status = model.getButtonStatus(buttonIndex);
    final colors = ButtonColorScheme.faceColors[status]!;

    return Container(
      padding: EdgeInsets.all(config.buttonSize * 0.1),
      child: SizedBox(
        width: config.buttonSize,
        height: config.buttonSize,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: colors.background,
            minimumSize: Size(config.buttonSize, config.buttonSize),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => onPressed(buttonIndex),
          child: Transform.rotate(angle: -rotationAngle),
        ),
      ),
    );
  }
}

class _EdgeButton extends StatelessWidget {
  final int buttonIndex;
  final _LayoutConfig config;
  final ReefModel model;
  final Function(int) onPressed;

  const _EdgeButton({
    required this.buttonIndex,
    required this.config,
    required this.model,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final status = model.getButtonStatus(buttonIndex);
    final colors = ButtonColorScheme.edgeColors[status]!;

    return SizedBox(
      width: config.buttonSize,
      height: config.buttonSize,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: colors.background,
          side: BorderSide(
            color: colors.border ?? colors.text ?? Colors.orange,
            width: 2.0,
          ),
          minimumSize: Size(config.buttonSize, config.buttonSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onPressed(buttonIndex),
        child: const SizedBox.shrink(),
      ),
    );
  }
}
