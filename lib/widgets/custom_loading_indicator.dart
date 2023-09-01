import 'dart:io';

import 'package:flutter/material.dart';

class CustomLoadingIndicator extends CircularProgressIndicator {
  CustomLoadingIndicator({super.key})
      : super(
            value:
                (Platform.environment.containsKey('FLUTTER_TEST') ? 0 : null));
}
