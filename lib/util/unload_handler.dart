import 'dart:js_interop';

import 'package:web/web.dart';

void setupUnloadHandler(bool Function() shouldShowWarning) {
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
