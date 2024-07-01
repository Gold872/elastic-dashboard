import 'dart:io';
import 'package:flutter/material.dart';

/// A custom loading indicator widget that conditionally shows a progress indicator.
///
/// This widget extends [CircularProgressIndicator] and sets its value to 0 when running in a test environment.
/// Otherwise, the progress indicator value is null, indicating an indeterminate progress indicator.
class CustomLoadingIndicator extends CircularProgressIndicator {
  /// Creates a custom loading indicator.
  ///
  /// The [key] parameter can be used to identify this widget in the widget tree.
  CustomLoadingIndicator({super.key})
      : super(
            value:
                (Platform.environment.containsKey('FLUTTER_TEST') ? 0 : null));
}
