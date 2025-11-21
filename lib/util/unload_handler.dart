import 'dart:js_interop';

import 'package:web/web.dart';

void setupUnloadHandler(bool Function() shouldShowWarning) {
  // Using `toJSCaptureThis` requires a function to have a specific return type
  bool? unloadHandler(BeforeUnloadEvent event) {
    if (shouldShowWarning()) {
      return true;
    }
    return null;
  }

  window.onbeforeunload = unloadHandler.toJSCaptureThis;
}

void removeUnloadHandler() {
  window.onbeforeunload = null;
}
