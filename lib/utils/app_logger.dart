import 'dart:io';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Custom file output for logger with rotation support
class RotatingFileOutput extends LogOutput {
  final int maxFileSizeInBytes;
  final Duration rotationDuration;
  final String logDirectory;

  File? _currentLogFile;
  DateTime? _fileCreationTime;
  int _currentFileSize = 0;

  RotatingFileOutput({
    this.maxFileSizeInBytes = 20 * 1024 * 1024, // 20 MB default
    this.rotationDuration = const Duration(hours: 24),
    this.logDirectory = 'logs',
  });

  Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/$logDirectory');

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    // Check if we need to rotate based on time or size
    if (_currentLogFile == null || _shouldRotate()) {
      await _rotateLogFile(logDir);
    }

    return _currentLogFile!;
  }

  bool _shouldRotate() {
    if (_currentLogFile == null || !_currentLogFile!.existsSync()) {
      return true;
    }

    // Check file size
    if (_currentFileSize >= maxFileSizeInBytes) {
      return true;
    }

    // Check time-based rotation
    if (_fileCreationTime != null) {
      final timeSinceCreation = DateTime.now().difference(_fileCreationTime!);
      if (timeSinceCreation >= rotationDuration) {
        return true;
      }
    }

    return false;
  }

  Future<void> _rotateLogFile(Directory logDir) async {
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = 'app_log_$timestamp.log';

    _currentLogFile = File('${logDir.path}/$fileName');
    _fileCreationTime = DateTime.now();
    _currentFileSize = 0;

    // Clean up old log files (keep only last 10)
    await _cleanupOldLogs(logDir);
  }

  Future<void> _cleanupOldLogs(Directory logDir) async {
    try {
      final files = logDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();

      if (files.length > 10) {
        // Sort by modification time
        files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );

        // Delete oldest files, keeping only last 10
        for (var i = 0; i < files.length - 10; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      // Silent fail - don't log errors in logger cleanup to avoid recursion
    }
  }

  @override
  void output(OutputEvent event) async {
    try {
      final file = await _getLogFile();
      final logLines = event.lines.join('\n') + '\n';

      await file.writeAsString(logLines, mode: FileMode.append);
      _currentFileSize += logLines.length;
    } catch (e) {
      // Silent fail - don't log errors in logger output to avoid recursion
    }
  }
}

/// Custom log printer with timestamp and enhanced formatting
class CustomLogPrinter extends PrettyPrinter {
  CustomLogPrinter()
    : super(
        methodCount: 0,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      );

  @override
  List<String> log(LogEvent event) {
    final color = PrettyPrinter.defaultLevelColors[event.level];
    final emoji = PrettyPrinter.defaultLevelEmojis[event.level];
    final timestamp = DateFormat(
      'yyyy-MM-dd HH:mm:ss.SSS',
    ).format(DateTime.now());

    final List<String> output = [];

    // Add timestamp and level
    output.add(
      color!('$emoji [$timestamp] [${event.level.name.toUpperCase()}]'),
    );

    // Add message
    if (event.message != null) {
      output.add(color(event.message.toString()));
    }

    // Add error if present
    if (event.error != null) {
      output.add(color('Error: ${event.error}'));
    }

    // Add stack trace if present
    if (event.stackTrace != null) {
      output.add(color('Stack trace:'));
      final stackLines = event.stackTrace.toString().split('\n');
      for (var line in stackLines) {
        output.add(color(line));
      }
    }

    output.add(color('─' * 120));

    return output;
  }
}

/// Main Logger class - Singleton instance
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  late Logger _logger;

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal() {
    _initLogger();
  }

  void _initLogger() {
    _logger = Logger(
      printer: CustomLogPrinter(),
      output: MultiOutput([
        ConsoleOutput(), // Console output
        RotatingFileOutput(), // File output with rotation
      ]),
      level: Level.debug, // Set minimum log level
    );
  }

  /// Info level log
  void info(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning level log
  void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error level log
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Debug level log
  void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Verbose level log
  void verbose(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Get log file directory path
  Future<String> getLogDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/logs';
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    final logPath = await getLogDirectory();
    final logDir = Directory(logPath);

    if (!await logDir.exists()) {
      return [];
    }

    return logDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList();
  }

  /// Clear all log files
  Future<void> clearLogs() async {
    final files = await getLogFiles();
    for (var file in files) {
      await file.delete();
    }
  }
}

/// Global logger instance for easy access
final logger = AppLogger();
