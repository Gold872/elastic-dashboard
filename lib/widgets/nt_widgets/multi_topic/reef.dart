import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'reef_buttons_states.dart';

// Constants for the hexagonal button layout
class ReefConstants {
  static const String widgetType = 'Reef';
  static const int totalButtons = 42;
  static const int faceButtons = 36;
  static const int edgeButtons = 6;
  static const int hexagonSides =
      6; // New: sides of the hexagon for aiming modes
  static const int totalArraySize = totalButtons + hexagonSides; // 48 total
  static const int buttonsPerFace = 6;
  static const int facesCount = 6;
  static const double globalRotation = math.pi / 6;

  // Visual styling
  static const Color hexagonColor = Color.fromARGB(255, 100, 2, 93);
  static const Color hexagonAimingColor = Colors.blue; // New: blue for aiming
  static const double hexagonStrokeWidth = 5.0;
}

class ReefModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefConstants.widgetType;

  // NetworkTables topic paths
  String get branchsTopicName => '/reef/branchs';
  String topicName = '/reef/dashboardbranchs';

  // NT4 subscriptions
  late NT4Subscription branchesSub;
  late Listenable branchesUpdates;

  @override
  List<NT4Subscription> get subscriptions => [branchesSub];

  // State management
  final Map<String, NT4Topic> _publishedTopics = {};

  // Get button status from NetworkTables data
  ButtonStatus getButtonStatus(int buttonIndex) {
    if (buttonIndex < 0 || buttonIndex >= ReefConstants.totalButtons) {
      return ButtonStatus.Empty;
    }

    final branchData = branchesSub.value;
    if (branchData is! List || buttonIndex >= branchData.length) {
      return ButtonStatus.Empty;
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

  // New: Get hexagon side aiming status (0 = normal/purple, 1 = aiming/blue)
  // Sequential mapping: side 0 -> index 42, side 1 -> index 43, side 2 -> index 44,
  // side 3 -> index 45, side 4 -> index 46, side 5 -> index 47
  bool getHexagonSideAiming(int sideIndex) {
    if (sideIndex < 0 || sideIndex >= ReefConstants.hexagonSides) {
      return false;
    }

    final branchData = branchesSub.value;
    if (branchData is! List) {
      return false;
    }

    // Sequential mapping: side 0->42, side 1->43, side 2->44, side 3->45, side 4->46, side 5->47
    final arrayIndex = 42 + sideIndex;

    if (arrayIndex >= branchData.length) {
      return false;
    }

    final value = branchData[arrayIndex];
    final intValue = switch (value) {
      int v => v,
      String v => int.tryParse(v) ?? 0,
      double v => v.toInt(),
      _ => 0,
    };

    return intValue == 1;
  }

  // Get or create NetworkTables topics with caching
  NT4Topic _getOrCreateTopic(String topicName, String dataType,
      {Map<String, dynamic>? properties}) {
    // Check cache first
    if (_publishedTopics.containsKey(topicName)) {
      return _publishedTopics[topicName]!;
    }

    // Check existing topics in NT4
    NT4Topic? existingTopic = ntConnection.getTopicFromName(topicName);

    if (existingTopic != null) {
      if (properties != null) {
        existingTopic.properties.addAll(properties);
        ntConnection.publishTopic(existingTopic);
      }

      _publishedTopics[topicName] = existingTopic;
      return existingTopic;
    }

    // Create new topic
    final newTopic = ntConnection.publishNewTopic(
      topicName,
      dataType,
      properties: properties ??
          {'retained': false}, // NT client cann't create a retained topic
    );

    _publishedTopics[topicName] = newTopic;
    return newTopic;
  }

  // Send current button states to dashboard topic
  void sendButtonsModesArray() {
    if (!ntConnection.isNT4Connected) {
      return;
    }

    try {
      // Create array with button modes + hexagon side aiming states
      final List<dynamic> allModes = List<int>.generate(
        ReefConstants.totalArraySize,
        (index) {
          if (index < ReefConstants.totalButtons) {
            return getButtonStatus(index).value;
          } else {
            // Hexagon side aiming states with sequential mapping
            // Index 42->side 0, 43->side 1, 44->side 2, 45->side 3, 46->side 4, 47->side 5
            final sideIndex = index - ReefConstants.totalButtons;
            return getHexagonSideAiming(sideIndex) ? 1 : 0;
          }
        },
      );

      final topic = _getOrCreateTopic(topicName, NT4TypeStr.kIntArr);
      ntConnection.updateDataFromTopic(topic, allModes);
    } catch (e) {
      debugPrint('Error sending button modes array: $e');
    }
  }

  // Publish branch status array to NetworkTables
  void _publishBranchStatus(List<dynamic> branchList) {
    if (!ntConnection.isNT4Connected) {
      return;
    }

    try {
      final topic = _getOrCreateTopic(branchsTopicName, NT4TypeStr.kIntArr);
      ntConnection.updateDataFromTopic(topic, branchList);
    } catch (e) {
      debugPrint('Error publishing branch status: $e');
    }
  }

  // Constructors
  ReefModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ReefModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  void initializeSubscriptions() {
    branchesSub = ntConnection.subscribe(branchsTopicName, super.period);
    branchesUpdates = Listenable.merge(subscriptions);
    branchesUpdates.addListener(_onStateUpdate);
    _onStateUpdate();
  }

  @override
  void resetSubscription() {
    _publishedTopics.clear(); // Clear the topic cache
    branchesUpdates.removeListener(_onStateUpdate);
    super.resetSubscription();
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [];
  }

  // Handle state updates from NetworkTables
  void _onStateUpdate() {
    notifyListeners();
  }

  // Handle button press - cycle through states
  void selectOptionByIndex(int index) {
    if (!_isValidButtonIndex(index)) return;

    final currentStatus = getButtonStatus(index);
    final newStatus = currentStatus.getNextStatus();

    _updateButtonStatus(index, newStatus.value);
    notifyListeners();
  }

  bool _isValidButtonIndex(int index) {
    return index >= 0 && index < ReefConstants.totalButtons;
  }

  // Update individual button status
  void _updateButtonStatus(int buttonIndex, int newStatus) {
    final currentBranchData = branchesSub.value;
    List<dynamic> branchList;

    if (currentBranchData is List) {
      branchList = List.from(currentBranchData);
    } else {
      branchList = List.filled(ReefConstants.totalArraySize, 0);
    }

    // Ensure array is large enough for all elements (buttons + hexagon sides)
    while (branchList.length < ReefConstants.totalArraySize) {
      branchList.add(0);
    }

    branchList[buttonIndex] = newStatus;

    if (ntConnection.isNT4Connected) {
      try {
        _publishBranchStatus(branchList);
        Future.microtask(() => sendButtonsModesArray());
      } catch (e) {
        debugPrint('Error updating button status: $e');
      }
    }
  }
}

class Reef extends NTWidget {
  static const String widgetType = ReefConstants.widgetType;

  const Reef({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NTWidgetModel>() as ReefModel;

    return ListenableBuilder(
      listenable: model.branchesSub,
      builder: (context, child) => child!,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 450,
            height: 450,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _HexagonWidget(model: model), // Pass model to hexagon
                _ButtonGridWidget(
                  model: model,
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

// Draws the central hexagon outline with dynamic side coloring
class _HexagonWidget extends StatelessWidget {
  final ReefModel model;

  const _HexagonWidget({required this.model});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.5;
        return Center(
          child: CustomPaint(
            size: Size(size, size),
            painter: _HexagonPainter(model: model),
          ),
        );
      },
    );
  }
}

// Custom painter for hexagon with center dot and dynamic side coloring
class _HexagonPainter extends CustomPainter {
  final ReefModel model;

  _HexagonPainter({required this.model});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 2);

    _drawHexagonWithColoredSides(canvas, radius);
    canvas.restore();

    _drawCenterDot(canvas, center, size);
  }

  void _drawHexagonWithColoredSides(Canvas canvas, double radius) {
    // First pass: Draw all non-glowing sides (purple)
    for (int i = 0; i < 6; i++) {
      final isAiming = model.getHexagonSideAiming(i);

      if (!isAiming) {
        final startAngle = i * math.pi / 3 + -math.pi / 6;
        final endAngle = (i + 1) * math.pi / 3 + -math.pi / 6;

        final startPoint = Offset(
          radius * math.cos(startAngle),
          radius * math.sin(startAngle),
        );
        final endPoint = Offset(
          radius * math.cos(endAngle),
          radius * math.sin(endAngle),
        );

        final paint = Paint()
          ..color = ReefConstants.hexagonColor
          ..strokeWidth = ReefConstants.hexagonStrokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(startPoint, endPoint, paint);
      }
    }

    // Second pass: Draw all glowing sides (blue) on top
    for (int i = 0; i < 6; i++) {
      final isAiming = model.getHexagonSideAiming(i);

      if (isAiming) {
        final startAngle = i * math.pi / 3 + -math.pi / 6;
        final endAngle = (i + 1) * math.pi / 3 + -math.pi / 6;

        final startPoint = Offset(
          radius * math.cos(startAngle),
          radius * math.sin(startAngle),
        );
        final endPoint = Offset(
          radius * math.cos(endAngle),
          radius * math.sin(endAngle),
        );

        // Draw glow effect for aiming sides (blue)
        final glowPaint = Paint()
          ..color = ReefConstants.hexagonAimingColor.withOpacity(0.3)
          ..strokeWidth = ReefConstants.hexagonStrokeWidth * 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

        canvas.drawLine(startPoint, endPoint, glowPaint);

        // Draw inner glow
        final innerGlowPaint = Paint()
          ..color = ReefConstants.hexagonAimingColor.withOpacity(0.6)
          ..strokeWidth = ReefConstants.hexagonStrokeWidth * 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

        canvas.drawLine(startPoint, endPoint, innerGlowPaint);

        // Draw the main blue line on top
        final paint = Paint()
          ..color = ReefConstants.hexagonAimingColor
          ..strokeWidth = ReefConstants.hexagonStrokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(startPoint, endPoint, paint);
      }
    }
  }

  void _drawCenterDot(Canvas canvas, Offset center, Size size) {
    final centerPaint = Paint()..color = ReefConstants.hexagonColor;
    final dotRadius = math.min(size.width, size.height) * 0.025;
    canvas.drawCircle(center, dotRadius, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _HexagonPainter || oldDelegate.model != model;
  }
}

// Container for all buttons in the hexagonal layout
class _ButtonGridWidget extends StatelessWidget {
  final ReefModel model;
  final Function(int) onOptionSelected;

  const _ButtonGridWidget({
    required this.model,
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

// Manages the positioning of face and edge buttons
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

  // Create 6 faces of buttons around the hexagon
  List<Widget> _buildFaceButtons(_LayoutConfig config) {
    return List.generate(ReefConstants.facesCount, (face) {
      final angle = -math.pi / 2 +
          face * (math.pi / 3) +
          math.pi / 6 +
          ReefConstants.globalRotation;
      final position = Offset(
        config.offsetFromCenter * math.cos(angle),
        config.offsetFromCenter * math.sin(angle),
      );

      return Transform.translate(
        offset: position,
        child: Transform.rotate(
          angle: angle,
          child: _CoralButtonGrid(
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

  // Create 6 edge buttons at hexagon vertices
  List<Widget> _buildEdgeButtons(_LayoutConfig config) {
    return List.generate(ReefConstants.edgeButtons, (edgeButton) {
      final angle = (edgeButton * math.pi / 3) + ReefConstants.globalRotation;
      final position = Offset(
        config.hexagonRadius * math.cos(angle),
        config.hexagonRadius * math.sin(angle),
      );
      final buttonIndex = ReefConstants.faceButtons + edgeButton;

      return Transform.translate(
        offset: position,
        child: _AlgaeButton(
          buttonIndex: buttonIndex,
          config: config,
          model: model,
          onPressed: onOptionSelected,
        ),
      );
    });
  }
}

// Layout configuration for button positioning and sizing
class _LayoutConfig {
  final double widgetSize;
  final double buttonSize;
  final double offsetFromCenter;
  final double hexagonRadius;

  _LayoutConfig(BoxConstraints constraints)
      : widgetSize = math.min(constraints.maxWidth, constraints.maxHeight),
        buttonSize =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.08,
        offsetFromCenter =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.38,
        hexagonRadius =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.15;
}

// 2x3 grid of buttons for each hexagon face
class _CoralButtonGrid extends StatelessWidget {
  final int faceIndex;
  final _LayoutConfig config;
  final ReefModel model;
  final double rotationAngle;
  final Function(int) onPressed;

  const _CoralButtonGrid({
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
            return _CoralButton(
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

// Individual button on a hexagon face
class _CoralButton extends StatelessWidget {
  final int buttonIndex;
  final _LayoutConfig config;
  final ReefModel model;
  final double rotationAngle;
  final Function(int) onPressed;

  const _CoralButton({
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

// Button positioned at hexagon vertex
class _AlgaeButton extends StatelessWidget {
  final int buttonIndex;
  final _LayoutConfig config;
  final ReefModel model;
  final Function(int) onPressed;

  const _AlgaeButton({
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
