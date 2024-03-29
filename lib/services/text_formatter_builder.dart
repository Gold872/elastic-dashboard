import 'package:flutter/services.dart';

class TextFormatterBuilder {
  static FilteringTextInputFormatter decimalTextFormatter(
      {bool allowNegative = false}) {
    if (allowNegative) {
      return FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'));
    } else {
      return FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
    }
  }
}
