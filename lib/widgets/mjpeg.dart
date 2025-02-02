import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';

/// A preprocessor for each JPEG frame from an MJPEG stream.
class MjpegPreprocessor {
  List<int>? process(List<int> frame) => frame;
}

/// An Mjpeg.
class Mjpeg extends StatefulWidget {
  final MjpegController controller;
  final BoxFit? fit;
  final bool expandToFit;
  final int quarterTurns;
  final double? width;
  final double? height;
  final WidgetBuilder? loading;
  final Widget Function(BuildContext contet, dynamic error, dynamic stack)?
      error;

  const Mjpeg({
    required this.controller,
    this.width,
    this.height,
    this.fit,
    this.expandToFit = false,
    this.quarterTurns = 0,
    this.error,
    this.loading,
    super.key,
  });

  @override
  State<Mjpeg> createState() => _MjpegState();
}

class _MjpegState extends State<Mjpeg> {
  final streamKey = UniqueKey();

  late void Function() listener;

  @override
  void initState() {
    listener = () => setState(() {});
    widget.controller.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(listener);

    widget.controller.setMounted(streamKey, false);
    widget.controller.setVisible(streamKey, false);

    super.dispose();
  }

  @override
  void didUpdateWidget(Mjpeg oldWidget) {
    final controller = widget.controller;
    final oldController = oldWidget.controller;

    if (oldController != controller) {
      oldController.removeListener(listener);
      controller.addListener(listener);

      controller.setMounted(streamKey, oldController.isMounted(streamKey));
      controller.setVisible(streamKey, oldController.isVisible(streamKey));
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    controller.setMounted(streamKey, context.mounted);

    if (controller.isVisible(streamKey)) {
      controller.startStream();
    }

    if (controller.errorState.value != null) {
      String errorText = controller.errorState.value!.first.toString();
      if (kDebugMode) {
        errorText += '\n${controller.errorState.value!.last.toString()}';
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.error == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : widget.error!(context, controller.errorState.value!.first,
                controller.errorState.value!.last),
      );
    }

    return VisibilityDetector(
      key: streamKey,
      child: StreamBuilder<List<int>?>(
          stream: controller.imageStream.stream,
          builder: (context, snapshot) {
            if (!controller.isStreaming) {
              // Request has been sent but no status received yet
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomLoadingIndicator(),
                  const SizedBox(height: 10),
                  const Text('Attempting to establish HTTP connection.'),
                ],
              );
            }
            if (snapshot.data == null && controller.previousImage == null) {
              return SizedBox(
                width: widget.width,
                height: widget.height,
                child: widget.loading?.call(context) ??
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CustomLoadingIndicator(),
                        const SizedBox(height: 10),
                        const Text(
                          'Connection established but no data received.\nCamera may be disconnected from device.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
              );
            }

            return RotatedBox(
              quarterTurns: widget.quarterTurns,
              child: Image.memory(
                Uint8List.fromList(snapshot.data ?? controller.previousImage!),
                width: widget.width,
                height: widget.height,
                gaplessPlayback: true,
                fit: widget.fit,
                scale: (widget.expandToFit) ? 1e-6 : 1.0,
              ),
            );
          }),
      onVisibilityChanged: (VisibilityInfo info) {
        if (controller.isMounted(streamKey)) {
          controller.setVisible(streamKey, info.visibleFraction != 0);
        }
      },
    );
  }
}

class MjpegController extends ChangeNotifier {
  static const _trigger = 0xFF;
  static const _soi = 0xD8;
  static const _eoi = 0xD9;

  final String stream;
  final bool isLive;
  final Duration timeout;
  final Map<String, String> headers;
  Client httpClient = Client();

  StreamSubscription<List<int>>? _rawSubscription;

  ValueNotifier<double> bandwidth = ValueNotifier(0);
  ValueNotifier<int> framesPerSecond = ValueNotifier(0);

  Timer? _metricsTimer;

  final List<int> _buffer = [];

  int _bitCount = 0;
  int _frameCount = 0;

  ValueNotifier<List<dynamic>?> errorState = ValueNotifier(null);
  StreamController<List<int>?> imageStream = StreamController.broadcast();
  List<int>? previousImage;

  final MjpegPreprocessor? preprocessor;

  final Set<Key> _mountedKeys = {};
  final Set<Key> _visibleKeys = {};

  bool isVisible(Key key) => _visibleKeys.contains(key);

  void setVisible(Key key, bool value) {
    logger.trace('Setting visibility to $value for $stream');
    if (value) {
      bool hasChanged = !_visibleKeys.contains(key);
      _visibleKeys.add(key);

      if (hasChanged) {
        logger.trace(
            'Visibility changed to true, notifying listeners for mjpeg stream');
        notifyListeners();
      }
    } else {
      _visibleKeys.remove(key);

      if (_visibleKeys.isEmpty) {
        stopStream();
      }
    }
  }

  bool isMounted(Key key) => _mountedKeys.contains(key);

  void setMounted(Key key, bool value) {
    logger.trace('Setting mounted to $value for $stream');
    if (value) {
      _mountedKeys.add(key);
    } else {
      _mountedKeys.remove(key);
    }
  }

  bool get isStreaming => _rawSubscription != null;

  MjpegController({
    required this.stream,
    this.isLive = true,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.preprocessor,
  }) {
    errorState.addListener(_onError);
  }

  @visibleForTesting
  MjpegController.withMockClient({
    required this.stream,
    this.isLive = true,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.preprocessor,
    required this.httpClient,
  }) {
    errorState.addListener(_onError);
  }

  void _onError() {
    if (errorState.value != null) {
      logger.error(
        'Error on Mjpeg stream for URL $stream',
        errorState.value?.firstOrNull,
        errorState.value?.lastOrNull,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    errorState.removeListener(_onError);
    stopStream();
    imageStream.close();
    super.dispose();
  }

  void startStream() async {
    if (isStreaming) {
      return;
    }
    logger.info('Starting camera stream on URL $stream');
    ByteStream? byteStream;
    try {
      final request = Request('GET', Uri.parse(stream));
      request.headers.addAll(headers);
      final response = await httpClient.send(request).timeout(
          timeout); //timeout is to prevent process to hang forever in some case

      if (response.statusCode >= 200 && response.statusCode < 300) {
        byteStream = response.stream;
      } else {
        if (_mountedKeys.isNotEmpty) {
          errorState.value = [
            HttpException(
                'Stream returned status code ${response.statusCode}: "${response.reasonPhrase}"'),
            StackTrace.current,
          ];
          imageStream.add(null);
        }
        stopStream();
      }
    } catch (error, stack) {
      // Timed out
      if (error.toString().contains('Connection attempt cancelled')) {
        errorState.value = [
          HttpException('Connection timed out', uri: Uri.tryParse(stream)),
          stack,
        ];
      } else if (!error // we ignore those errors in case play/pause is triggers
          .toString()
          .contains('Connection closed before full header was received')) {
        if (_mountedKeys.isNotEmpty) {
          errorState.value = [error, stack];
          imageStream.add(null);
        }
      }
    }

    if (byteStream == null) {
      return;
    }

    previousImage = null;
    _buffer.clear();

    _rawSubscription = byteStream.listen(
      (data) {
        _bitCount += data.length * Uint8List.bytesPerElement * 8;
        _handleData(data);
      },
      onDone: () {
        stopStream();
        notifyListeners();
      },
    );

    _metricsTimer ??=
        Timer.periodic(const Duration(seconds: 1), _updateMetrics);

    notifyListeners();
  }

  void _updateMetrics(_) {
    bandwidth.value = _bitCount / 1e6;
    framesPerSecond.value = _frameCount;

    _bitCount = 0;
    _frameCount = 0;
  }

  void stopStream() async {
    logger.info('Stopping camera stream on URL $stream');
    _metricsTimer?.cancel();
    _metricsTimer = null;
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _buffer.clear();
    _bitCount = 0;
    _frameCount = 0;
    httpClient.close();
    httpClient = Client();
  }

  void _handleNewPacket() {
    logger.trace('Handling a ${_buffer.length} byte packet');
    List<int> imageData = preprocessor?.process(_buffer) ?? List.from(_buffer);
    previousImage = imageData;
    imageStream.add(imageData);
    _frameCount++;
    _buffer.clear();
    errorState.value = null;
  }

  void _handleData(List<int> data) {
    if (_buffer.isNotEmpty && _buffer.last == _trigger) {
      if (data.first == _eoi) {
        _buffer.add(data.first);
        _handleNewPacket();
        if (!isLive) {
          dispose();
        }
      }
    }
    for (var i = 0; i < data.length - 1; i++) {
      final d = data[i];
      final d1 = data[i + 1];

      if (d == _trigger && d1 == _soi) {
        _buffer.clear();
        _buffer.add(d);
      } else if (d == _trigger && d1 == _eoi && _buffer.isNotEmpty) {
        _buffer.add(d);
        _buffer.add(d1);

        _handleNewPacket();
        if (!isLive) {
          dispose();
        }
      } else if (_buffer.isNotEmpty) {
        _buffer.add(d);
        if (i == data.length - 2) {
          _buffer.add(d1);
        }
      }
    }
  }
}
