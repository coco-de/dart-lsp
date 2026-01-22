import 'dart:collection';
import 'dart:io';

/// Log level enumeration
enum LogLevel {
  debug,
  info,
  warning,
  error;

  /// Check if this level is at least as severe as [other]
  bool isAtLeast(LogLevel other) => index >= other.index;

  /// Get display name with emoji
  String get displayName => switch (this) {
        LogLevel.debug => '🔍',
        LogLevel.info => 'ℹ️',
        LogLevel.warning => '⚠️',
        LogLevel.error => '❌',
      };

  /// Parse log level from string
  static LogLevel fromString(String value) {
    return LogLevel.values.firstWhere(
      (l) => l.name.toLowerCase() == value.toLowerCase(),
      orElse: () => LogLevel.info,
    );
  }
}

/// A single log entry
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final String? stackTrace;

  /// Format the log entry for display
  String format() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final trace = stackTrace != null ? '\n$stackTrace' : '';
    return '${level.displayName} [$time] [$source] $message$trace';
  }

  /// Convert to Map for JSON serialization
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'source': source,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}

/// Ring buffer storage for log entries
class LogStore {
  LogStore({this.maxEntries = 1000});

  final int maxEntries;
  final Queue<LogEntry> _entries = Queue<LogEntry>();

  /// Add a log entry to the store
  void add(LogEntry entry) {
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  /// Query log entries with optional filters
  List<LogEntry> query({
    LogLevel? minLevel,
    String? source,
    int? limit,
    Duration? since,
    String? search,
  }) {
    var results = _entries.toList();

    // Filter by minimum level
    if (minLevel != null) {
      results = results.where((e) => e.level.isAtLeast(minLevel)).toList();
    }

    // Filter by source
    if (source != null && source.isNotEmpty) {
      final lowerSource = source.toLowerCase();
      results =
          results.where((e) => e.source.toLowerCase() == lowerSource).toList();
    }

    // Filter by time
    if (since != null) {
      final cutoff = DateTime.now().subtract(since);
      results = results.where((e) => e.timestamp.isAfter(cutoff)).toList();
    }

    // Filter by search term
    if (search != null && search.isNotEmpty) {
      final lowerSearch = search.toLowerCase();
      results = results
          .where((e) => e.message.toLowerCase().contains(lowerSearch))
          .toList();
    }

    // Apply limit (take most recent)
    if (limit != null && results.length > limit) {
      results = results.sublist(results.length - limit);
    }

    return results;
  }

  /// Get all entries
  List<LogEntry> get all => _entries.toList();

  /// Get entry count
  int get length => _entries.length;

  /// Clear all entries
  void clear() => _entries.clear();
}

/// Singleton logger that writes to stderr and stores entries
class Logger {
  Logger._();

  static final Logger instance = Logger._();

  final LogStore _store = LogStore();

  /// Get the log store for querying
  LogStore get store => _store;

  /// Log a debug message
  void debug(String source, String message) {
    _log(LogLevel.debug, source, message);
  }

  /// Log an info message
  void info(String source, String message) {
    _log(LogLevel.info, source, message);
  }

  /// Log a warning message
  void warn(String source, String message) {
    _log(LogLevel.warning, source, message);
  }

  /// Log an error message with optional stack trace
  void error(String source, String message, [StackTrace? stackTrace]) {
    _log(LogLevel.error, source, message, stackTrace);
  }

  void _log(
    LogLevel level,
    String source,
    String message, [
    StackTrace? stackTrace,
  ]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      stackTrace: stackTrace?.toString(),
    );

    // Store the entry
    _store.add(entry);

    // Write to stderr for MCP protocol compliance
    stderr.writeln('[Dart $source] $message');
    if (stackTrace != null) {
      stderr.writeln(stackTrace);
    }
  }
}
