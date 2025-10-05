import 'dart:ui';

class Display {
  const Display({
    required this.id,
    this.name,
    required this.size,
    this.visiblePosition,
    this.visibleSize,
    this.scaleFactor,
  });

  /// Unique identifier associated with the display.
  final String id;

  /// The name of the display.
  final String? name;

  /// The size of the display in logical pixels.
  final Size size;

  /// The position of the display in logical pixels.
  final Offset? visiblePosition;

  /// The size of the display in logical pixels.
  final Size? visibleSize;

  /// The scale factor of the display.
  final num? scaleFactor;
}

class ScreenRetriever {
  ScreenRetriever._();

  /// The shared instance of [ScreenRetriever].
  static final ScreenRetriever instance = ScreenRetriever._();

  Future<Offset> getCursorScreenPoint() async => const Offset(0, 0);

  Future<Display> getPrimaryDisplay() async =>
      Display(id: '', size: Size(0, 0));

  Future<List<Display>> getAllDisplays() async =>
      List.filled(1, Display(id: '', size: Size(0, 0)));
}

final screenRetriever = ScreenRetriever._();
