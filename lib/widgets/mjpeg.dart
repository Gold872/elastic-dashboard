import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Notifier class to manage the state of the MJPEG widget.
class _MjpegStateNotifier extends ChangeNotifier {
  bool _mounted = true;
  bool _visible = true;

  _MjpegStateNotifier() : super();

  /// Getter for mounted state.
  bool get mounted => _mounted;

  /// Getter for visibility state.
  bool get visible => _visible;

  /// Setter for visibility state.
  set visible(bool value) {
    _visible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _mounted = false;
    notifyListeners();
    super.dispose();
  }
}

/// A preprocessor for each JPEG frame from an MJPEG stream.
class MjpegPreprocessor {
  /// Processes a JPEG frame.
  List<int>? process(List<int> frame) => frame;
}

/// Widget to display an MJPEG stream.
class Mjpeg extends HookWidget {
  final streamKey = UniqueKey();
  final MjpegStreamState mjpegStream;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final WidgetBuilder? loading;
  final bool showBandwidthUsage;

  final Widget Function(BuildContext context, dynamic error, dynamic stack)?
      error;

  /// Constructor for the Mjpeg widget.
  Mjpeg({
    required this.mjpegStream,
    this.width,
    this.height,
    this.fit,
    this.error,
    this.loading,
    required this.showBandwidthUsage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final image = useState<MemoryImage?>(null);
    final state = useMemoized(() => _MjpegStateNotifier());
    final visible = useListenable(state);
    final errorState = useState<List<dynamic>?>(null);

    bool isMounted() => context.mounted;

    final manager = useMemoized(
      () => _StreamManager(
        mjpegStream: mjpegStream,
        mounted: isMounted,
        visible: () => visible.visible,
      ),
      [
        visible.visible,
        isMounted(),
        mjpegStream,
      ],
    );

    final key = useMemoized(() => UniqueKey(), [manager]);

    useEffect(() {
      errorState.value = null;
      manager.updateStream(streamKey, image, errorState);
      return () {
        if (visible.visible && isMounted()) {
          return;
        }
        mjpegStream.cancelSubscription(streamKey);
      };
    }, [manager]);

    if (errorState.value != null && kDebugMode) {
      return SizedBox(
        width: width,
        height: height,
        child: error == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${errorState.value}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : error!(context, errorState.value!.first, errorState.value!.last),
      );
    }

    if ((image.value == null && mjpegStream.previousImage == null) ||
        errorState.value != null) {
      return SizedBox(
          width: width,
          height: height,
          child: loading == null
              ? const Center(child: CircularProgressIndicator())
              : loading!(context));
    }
    double bandwidth = mjpegStream.bandwidth;

    return Column(
      children: [
        VisibilityDetector(
          key: key,
          child: Image(
            image: image.value ?? mjpegStream.previousImage!,
            width: width,
            height: height,
            gaplessPlayback: true,
            fit: fit,
          ),
          onVisibilityChanged: (VisibilityInfo info) {
            if (visible.mounted) {
              visible.visible = info.visibleFraction != 0;
            }
          },
        ),
        showBandwidthUsage
            ? Text('Bandwidth usage: ${bandwidth.toStringAsFixed(2)} KB/s',
                style: const TextStyle(fontSize: 13))
            : const SizedBox(height: 5),
      ],
    );
  }
}

/// State management for MJPEG stream.
class MjpegStreamState {
  static const _trigger = 0xFF;
  static const _soi = 0xD8;
  static const _eoi = 0xD9;
  final String stream;
  final bool isLive;
  final Duration timeout;
  final Map<String, String> headers;
  Client httpClient = Client();
  Stream<List<int>>? byteStream;

  final MjpegPreprocessor? preprocessor;

  MemoryImage? previousImage;

  final Map<Key, StreamSubscription> _subscriptions = {};

  StreamSubscription? _bitSubscription;
  int bitCount = 0;
  double bandwidth = 0.0;

  late final Timer bandwidthTimer;

  /// Constructor for MjpegStreamState.
  MjpegStreamState({
    required this.stream,
    this.isLive = true,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.preprocessor,
  }) {
    bandwidthTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bandwidth = bitCount / 1e6;
      bitCount = 0;
    });
  }

  /// Disposes the resources.
  void dispose() {
    for (StreamSubscription subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _bitSubscription?.cancel();
    _bitSubscription = null;
    byteStream = null;
    httpClient.close();
    httpClient = Client();
    bitCount = 0;
  }

  /// Cancels the subscription for the given key.
  void cancelSubscription(Key key) {
    if (_subscriptions.containsKey(key)) {
      _subscriptions.remove(key)!.cancel();
      if (_subscriptions.isEmpty) {
        dispose();
      }
    }
  }

  /// Sends the image to the provided ValueNotifier.
  void sendImage(
    ValueNotifier<MemoryImage?> image,
    ValueNotifier<dynamic> errorState,
    List<int> chunks, {
    required bool Function() mounted,
  }) async {
    final List<int>? imageData = preprocessor?.process(chunks) ?? chunks;
    if (imageData == null) return;

    final imageMemory = MemoryImage(Uint8List.fromList(imageData));
    previousImage?.evict();
    previousImage = imageMemory;
    if (mounted()) {
      errorState.value = null;
      image.value = imageMemory;
    }
  }

  /// Handles data received from the stream.
  void _onDataReceived({
    required List<int> carry,
    required List<int> chunk,
    required ValueNotifier<MemoryImage?> image,
    required ValueNotifier<List<dynamic>?> errorState,
    required bool Function() mounted,
  }) async {
    if (carry.isNotEmpty && carry.last == _trigger && chunk.first == _eoi) {
      carry.add(chunk.first);
      sendImage(image, errorState, carry, mounted: mounted);
      carry.clear();
      if (!isLive) dispose();
    }

    for (var i = 0; i < chunk.length - 1; i++) {
      final d = chunk[i];
      final d1 = chunk[i + 1];

      if (d == _trigger && d1 == _soi) {
        carry.clear();
        carry.add(d);
      } else if (d == _trigger && d1 == _eoi && carry.isNotEmpty) {
        carry.add(d);
        carry.add(d1);
        sendImage(image, errorState, carry, mounted: mounted);
        carry.clear();
        if (!isLive) dispose();
      } else if (carry.isNotEmpty) {
        carry.add(d);
        if (i == chunk.length - 2) {
          carry.add(d1);
        }
      }
    }
  }

  /// Updates the stream with the given key and notifiers.
  void updateStream(
    Key key,
    ValueNotifier<MemoryImage?> image,
    ValueNotifier<List<dynamic>?> errorState, {
    required bool Function() visible,
    required bool Function() mounted,
  }) async {
    if (byteStream == null && visible() && mounted()) {
      try {
        final request = Request('GET', Uri.parse(stream));
        request.headers.addAll(headers);
        final response = await httpClient.send(request).timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          byteStream = response.stream.asBroadcastStream();
          _bitSubscription = byteStream!.listen((data) {
            bitCount += data.length * Uint8List.bytesPerElement * 8;
          });
        } else {
          if (mounted()) {
            errorState.value = [
              HttpException('Stream returned ${response.statusCode} status'),
              StackTrace.current
            ];
            image.value = null;
          }
          dispose();
        }
      } catch (error, stack) {
        if (!error
            .toString()
            .contains('Connection closed before full header was received')) {
          if (mounted()) {
            errorState.value = [error, stack];
            image.value = null;
          }
        }
      }
    }
    if (byteStream == null) return;

    var carry = <int>[];
    _subscriptions.putIfAbsent(
      key,
      () => byteStream!.listen((chunk) {
        if (!visible() || !mounted()) {
          carry.clear();
          return;
        }
        _onDataReceived(
          carry: carry,
          chunk: chunk,
          image: image,
          errorState: errorState,
          mounted: mounted,
        );
      }, onError: (error, stack) {
        if (mounted()) {
          errorState.value = [error, stack];
          image.value = null;
        }
        dispose();
      }),
    );
  }
}

/// Manages the MJPEG stream for the widget.
class _StreamManager {
  final MjpegStreamState mjpegStream;
  final bool Function() mounted;
  final bool Function() visible;

  _StreamManager({
    required this.mjpegStream,
    required this.mounted,
    required this.visible,
  });

  /// Updates the stream with the given key and notifiers.
  void updateStream(
    Key key,
    ValueNotifier<MemoryImage?> image,
    ValueNotifier<List<dynamic>?> errorState,
  ) =>
      mjpegStream.updateStream(
        key,
        image,
        errorState,
        visible: visible,
        mounted: mounted,
      );
}
