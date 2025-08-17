import 'package:flutter/material.dart';

// Button states for the reef interface
enum ButtonStatus {
  Empty(0),
  Placed(1),
  Aimming(2),
  Closest(3);

  const ButtonStatus(this.value);
  final int value;

  static ButtonStatus fromInt(int value) {
    return ButtonStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ButtonStatus.Empty,
    );
  }

  ButtonStatus getNextStatus() {
    switch (this) {
      case ButtonStatus.Placed:
        return ButtonStatus.Empty;
      case ButtonStatus.Empty:
      case ButtonStatus.Aimming:
      case ButtonStatus.Closest:
        return ButtonStatus.Placed;
    }
  }
}

// Color schemes for different button types and states
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

  // Color schemes for face buttons (inner hexagon buttons)
  static const Map<ButtonStatus, ButtonColorScheme> faceColors = {
    ButtonStatus.Empty: ButtonColorScheme(),
    ButtonStatus.Placed: ButtonColorScheme(
      background: Colors.white,
      text: Colors.black,
    ),
    ButtonStatus.Aimming: ButtonColorScheme(
      background: Colors.purple,
      text: Colors.white,
    ),
    ButtonStatus.Closest: ButtonColorScheme(
      background: Colors.green,
      text: Colors.white,
    ),
  };

  // Color schemes for edge buttons (outer hexagon vertices)
  static final Map<ButtonStatus, ButtonColorScheme> edgeColors = {
    ButtonStatus.Empty: ButtonColorScheme(
      background: Colors.transparent,
      text: Colors.black,
      border: Colors.tealAccent[400],
    ),
    ButtonStatus.Placed: ButtonColorScheme(
      background: Colors.tealAccent[400],
      text: Colors.black,
      border: Colors.tealAccent[400],
    ),
    ButtonStatus.Aimming: ButtonColorScheme(
      background: Colors.yellow,
      text: Colors.black,
      border: Colors.yellow,
    ),
    ButtonStatus.Closest: ButtonColorScheme(
      background: Colors.lime,
      text: Colors.black,
      border: Colors.lime,
    ),
  };
}
