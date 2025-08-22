import 'dart:js_interop';

import 'package:web/web.dart';

void setupUnloadHandler(bool Function() shouldShowWarning) {
  window.onbeforeunload = (event) {
    event as BeforeUnloadEvent;
    if (shouldShowWarning()) {
      return true;
    }
  }.toJSCaptureThis;
}

void removeUnloadHandler() {
  window.onbeforeunload = null;
}
