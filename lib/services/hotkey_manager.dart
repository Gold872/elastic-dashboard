import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

class HotKey {
  final LogicalKeyboardKey logicalKey;
  final List<ModifierKey>? modifiers;
  String identifier = const Uuid().v4();

  HotKey(this.logicalKey, {this.modifiers, String? identifier}) {
    if (identifier != null) {
      this.identifier = identifier;
    }
  }
}

typedef HotKeyCallback = void Function();

class HotKeyManager {
  HotKeyManager._();

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  bool _initialized = false;
  final List<HotKey> _hotKeyList = [];
  final Map<String, HotKeyCallback> _callbackMap = {};

  void _init() {
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
    _initialized = true;
  }

  _handleRawKeyEvent(RawKeyEvent value) {
    if (value is RawKeyDownEvent) {
      if (value.repeat) return;
      HotKey? hotKey = _hotKeyList.firstWhereOrNull(
        (e) {
          return value.isKeyPressed(e.logicalKey) &&
              value.data.modifiersPressed.keys.length ==
                  (e.modifiers ?? []).length &&
              (e.modifiers ?? []).every(
                (m) => value.data.isModifierPressed(m),
              );
        },
      );

      if (hotKey != null) {
        HotKeyCallback? callback = _callbackMap[hotKey.identifier];
        if (callback != null) callback();
      }
    }
  }

  List<HotKey> get registeredHotKeyList => _hotKeyList;

  void register(
    HotKey shortcut, {
    HotKeyCallback? callback,
  }) {
    if (!_initialized) _init();

    if (callback != null) {
      _callbackMap.update(
        shortcut.identifier,
        (_) => callback,
        ifAbsent: () => callback,
      );
    }

    _hotKeyList.add(shortcut);
  }

  void unregister(HotKey hotKey) {
    if (!_initialized) _init();

    if (_callbackMap.containsKey(hotKey.identifier)) {
      _callbackMap.remove(hotKey.identifier);
    }

    _hotKeyList.removeWhere((e) => e.identifier == hotKey.identifier);
  }

  void unregisterAll() {
    if (!_initialized) _init();

    _callbackMap.clear();
    _hotKeyList.clear();
  }

  void resetKeysPressed() {
    // ignore: invalid_use_of_visible_for_testing_member
    RawKeyboard.instance.clearKeysPressed();
  }
}

final hotKeyManager = HotKeyManager.instance;
