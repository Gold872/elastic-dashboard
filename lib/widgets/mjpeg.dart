import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _MjpegStateNotifier extends ChangeNotifier {
  bool _mounted = true;
  bool _visible = true;

  _MjpegStateNotifier() : super();

  bool get mounted => _mounted;

  bool get visible => _visible;

  set visible(value) {
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
  List<int>? process(List<int> frame) => frame;
}

/// An Mjpeg.
class Mjpeg extends HookWidget {
  final String stream;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool isLive;
  final Duration timeout;
  final WidgetBuilder? loading;
  final Client? httpClient;
  final Widget Function(BuildContext contet, dynamic error, dynamic stack)?
      error;
  final Map<String, String> headers;
  final MjpegPreprocessor? preprocessor;

  MemoryImage? previousImage;

  late _StreamManager _manager;

  Mjpeg({
    this.httpClient,
    this.isLive = false,
    this.width,
    this.timeout = const Duration(seconds: 5),
    this.height,
    this.fit,
    required this.stream,
    this.error,
    this.loading,
    this.headers = const {},
    this.preprocessor,
    super.key,
  });

  Future<void> cancelSubscription() async {
    await _manager.cancelSubscription();
  }

  Future<void> dispose() async {
    await _manager.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = useState<MemoryImage?>(null);
    final state = useMemoized(() => _MjpegStateNotifier());
    final visible = useListenable(state);
    final errorState = useState<List<dynamic>?>(null);
    // ignore: deprecated_member_use
    final isMounted = useIsMounted();

    final manager = useMemoized(
        () => _manager = _StreamManager(
              stream,
              isLive && visible.visible,
              headers,
              timeout,
              httpClient ?? Client(),
              preprocessor ?? MjpegPreprocessor(),
              isMounted,
              () => visible.visible,
            ),
        [
          stream,
          isLive,
          visible.visible,
          timeout,
          httpClient,
          preprocessor,
          isMounted
        ]);
    final key = useMemoized(() => UniqueKey(), [manager]);

    useEffect(() {
      errorState.value = null;
      manager.updateStream(image, errorState);
      return manager.dispose;
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

    if ((image.value == null && previousImage == null) ||
        errorState.value != null) {
      return SizedBox(
          width: width,
          height: height,
          child: loading == null
              ? const Center(child: CircularProgressIndicator())
              : loading!(context));
    }

    if (image.value != null) {
      previousImage?.evict();
      previousImage = image.value!;
    }

    return VisibilityDetector(
      key: key,
      child: Image(
        image: image.value ?? previousImage!,
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
    );
  }
}

class _StreamManager {
  static const _trigger = 0xFF;
  static const _soi = 0xD8;
  static const _eoi = 0xD9;

  final String stream;
  final bool isLive;
  final Duration _timeout;
  final Map<String, String> headers;
  final Client _httpClient;
  final MjpegPreprocessor _preprocessor;
  final bool Function() _mounted;
  final bool Function() _visible;
  StreamSubscription? _subscription;

  _StreamManager(this.stream, this.isLive, this.headers, this._timeout,
      this._httpClient, this._preprocessor, this._mounted, this._visible);

  Future<void> cancelSubscription() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
  }

  Future<void> dispose() async {
    try {
      _httpClient.close();
    } catch (e) {}
    await _subscription?.cancel();
    _subscription = null;
  }

  void _sendImage(ValueNotifier<MemoryImage?> image,
      ValueNotifier<dynamic> errorState, List<int> chunks) async {
    // pass image through preprocessor sending to [Image] for rendering
    final List<int>? imageData = _preprocessor.process(chunks);
    if (imageData == null) return;

    final imageMemory = MemoryImage(Uint8List.fromList(imageData));
    if (_mounted()) {
      errorState.value = null;
      image.value = imageMemory;
    }
  }

  void updateStream(ValueNotifier<MemoryImage?> image,
      ValueNotifier<List<dynamic>?> errorState) async {
    if (!_visible() || !_mounted()) {
      await dispose();
      return;
    }
    try {
      final request = Request('GET', Uri.parse(stream));
      request.headers.addAll(headers);
      final response = await _httpClient.send(request).timeout(
          _timeout); //timeout is to prevent process to hang forever in some case

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var carry = <int>[];
        _subscription = response.stream.listen((chunk) async {
          if (!_visible() || !_mounted()) {
            carry = [];
            return;
          }
          if (carry.isNotEmpty && carry.last == _trigger) {
            if (chunk.first == _eoi) {
              carry.add(chunk.first);
              _sendImage(image, errorState, carry);
              carry = [];
              if (!isLive) {
                await dispose();
              }
            }
          }

          for (var i = 0; i < chunk.length - 1; i++) {
            final d = chunk[i];
            final d1 = chunk[i + 1];

            if (d == _trigger && d1 == _soi) {
              carry = [];
              carry.add(d);
            } else if (d == _trigger && d1 == _eoi && carry.isNotEmpty) {
              carry.add(d);
              carry.add(d1);

              _sendImage(image, errorState, carry);
              carry = [];
              if (!isLive) {
                await dispose();
              }
            } else if (carry.isNotEmpty) {
              carry.add(d);
              if (i == chunk.length - 2) {
                carry.add(d1);
              }
            }
          }
        }, onError: (error, stack) {
          try {
            if (_mounted()) {
              errorState.value = [error, stack];
              image.value = null;
            }
          } catch (ex) {}
          dispose();
        }, cancelOnError: true);
      } else {
        if (_mounted()) {
          errorState.value = [
            HttpException('Stream returned ${response.statusCode} status'),
            StackTrace.current
          ];
          image.value = null;
        }
        dispose();
      }
    } catch (error, stack) {
      // we ignore those errors in case play/pause is triggers
      if (!error
          .toString()
          .contains('Connection closed before full header was received')) {
        if (_mounted()) {
          errorState.value = [error, stack];
          image.value = null;
        }
      }
    }
  }
}
