import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class for logging messages to console and optionally to a file.
///
/// Inspired by the logging feature of 3015 PathPlanner:
/// [PathPlanner Logging Feature](https://github.com/mjansen4857/pathplanner/blob/main/lib/services/log.dart)
///
/// Uses [Logger] from the `logger` package for logging functionalities.
class Log {
  static final DateFormat _dateFormat = DateFormat('HH:mm:ss.S');

  /// Singleton instance of the Log class.
  static Log instance = Log._internal();

  Log._internal();

  Logger? _logger;

  /// Initializes the logger, setting up logging configurations.
  ///
  /// Retrieves the application support directory and sets up log file output.
  Future<void> initialize() async {
    Directory logPath = await getApplicationSupportDirectory();
    File logFile = File(join(logPath.path, 'elastic-log.txt'));

    _logger = Logger(
      printer: HybridPrinter(
        SimplePrinter(colors: kDebugMode),
        error: PrettyPrinter(methodCount: 5, colors: kDebugMode),
        warning: PrettyPrinter(methodCount: 5, colors: kDebugMode),
      ),
      output: MultiOutput([
        ConsoleOutput(),
        if (kReleaseMode) FileOutput(file: logFile),
      ]),
      level: kDebugMode ? Level.debug : Level.info,
      filter: ProductionFilter(),
    );
  }

  /// Logs a message at the specified [level].
  ///
  /// Optionally includes [error] and [trace] information.
  void log(Level level, dynamic message, [dynamic error, StackTrace? trace]) {
    _logger?.log(
      level,
      '[${_dateFormat.format(DateTime.now())}]:  $message',
      error: error,
      stackTrace: trace,
    );
  }

  /// Logs an information message.
  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.info, message, error, stackTrace);
  }

  /// Logs an error message.
  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.error, message, error, stackTrace);
  }

  /// Logs a warning message.
  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.warning, message, error, stackTrace);
  }

  /// Logs a debug message.
  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.debug, message, error, stackTrace);
  }
}

/// Retrieves the singleton instance of [Log].
Log get logger => Log.instance;
