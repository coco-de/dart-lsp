import 'package:dart_lsp/dart_lsp.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    group('fromString', () {
      test('parses valid level names', () {
        expect(LogLevel.fromString('debug'), LogLevel.debug);
        expect(LogLevel.fromString('info'), LogLevel.info);
        expect(LogLevel.fromString('warning'), LogLevel.warning);
        expect(LogLevel.fromString('error'), LogLevel.error);
      });

      test('is case-insensitive', () {
        expect(LogLevel.fromString('DEBUG'), LogLevel.debug);
        expect(LogLevel.fromString('Error'), LogLevel.error);
        expect(LogLevel.fromString('WARNING'), LogLevel.warning);
      });

      test('returns info for invalid values', () {
        expect(LogLevel.fromString('unknown'), LogLevel.info);
        expect(LogLevel.fromString(''), LogLevel.info);
      });
    });

    group('isAtLeast', () {
      test('respects severity ordering', () {
        expect(LogLevel.debug.isAtLeast(LogLevel.debug), isTrue);
        expect(LogLevel.info.isAtLeast(LogLevel.debug), isTrue);
        expect(LogLevel.warning.isAtLeast(LogLevel.info), isTrue);
        expect(LogLevel.error.isAtLeast(LogLevel.warning), isTrue);
      });

      test('lower levels are not at least higher levels', () {
        expect(LogLevel.debug.isAtLeast(LogLevel.info), isFalse);
        expect(LogLevel.info.isAtLeast(LogLevel.warning), isFalse);
        expect(LogLevel.warning.isAtLeast(LogLevel.error), isFalse);
      });
    });
  });

  group('LogEntry', () {
    test('format() produces correct output', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 15, 9, 5, 3),
        level: LogLevel.info,
        source: 'MCP',
        message: 'Server started',
      );

      final formatted = entry.format();
      expect(formatted, contains('09:05:03'));
      expect(formatted, contains('[MCP]'));
      expect(formatted, contains('Server started'));
      expect(formatted, contains(LogLevel.info.displayName));
    });

    test('format() includes stack trace when present', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 15, 9, 5, 3),
        level: LogLevel.error,
        source: 'LSP',
        message: 'Failed',
        stackTrace: 'stack line 1\nstack line 2',
      );

      final formatted = entry.format();
      expect(formatted, contains('stack line 1'));
      expect(formatted, contains('stack line 2'));
    });

    test('format() omits stack trace when null', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 15, 9, 5, 3),
        level: LogLevel.info,
        source: 'MCP',
        message: 'OK',
      );

      final formatted = entry.format();
      // Should not have trailing newline from stacktrace
      expect(formatted.endsWith('OK'), isTrue);
    });
  });

  group('LogStore', () {
    late LogStore store;

    setUp(() {
      store = LogStore(maxEntries: 5);
    });

    LogEntry makeEntry({
      LogLevel level = LogLevel.info,
      String source = 'TEST',
      String message = 'msg',
      DateTime? timestamp,
    }) {
      return LogEntry(
        timestamp: timestamp ?? DateTime.now(),
        level: level,
        source: source,
        message: message,
      );
    }

    test('ring buffer evicts oldest entries when exceeding maxEntries', () {
      for (var i = 0; i < 7; i++) {
        store.add(makeEntry(message: 'msg$i'));
      }
      expect(store.length, 5);
      // Oldest (msg0, msg1) should be gone
      final messages = store.all.map((e) => e.message).toList();
      expect(messages, ['msg2', 'msg3', 'msg4', 'msg5', 'msg6']);
    });

    group('query()', () {
      test('filters by minLevel', () {
        store.add(makeEntry(level: LogLevel.debug, message: 'dbg'));
        store.add(makeEntry(level: LogLevel.info, message: 'inf'));
        store.add(makeEntry(level: LogLevel.error, message: 'err'));

        final results = store.query(minLevel: LogLevel.info);
        expect(results.map((e) => e.message), ['inf', 'err']);
      });

      test('filters by source (case-insensitive)', () {
        store.add(makeEntry(source: 'MCP', message: 'a'));
        store.add(makeEntry(source: 'LSP', message: 'b'));
        store.add(makeEntry(source: 'mcp', message: 'c'));

        final results = store.query(source: 'mcp');
        expect(results.map((e) => e.message), ['a', 'c']);
      });

      test('applies limit returning most recent entries', () {
        for (var i = 0; i < 5; i++) {
          store.add(makeEntry(message: 'msg$i'));
        }
        final results = store.query(limit: 2);
        expect(results.map((e) => e.message), ['msg3', 'msg4']);
      });

      test('filters by since duration', () {
        store.add(makeEntry(
          message: 'old',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        ));
        store.add(makeEntry(
          message: 'recent',
          timestamp: DateTime.now(),
        ));

        final results =
            store.query(since: const Duration(minutes: 5));
        expect(results.map((e) => e.message), ['recent']);
      });

      test('filters by search term (case-insensitive)', () {
        store.add(makeEntry(message: 'Server started'));
        store.add(makeEntry(message: 'Connection lost'));
        store.add(makeEntry(message: 'server stopped'));

        final results = store.query(search: 'server');
        expect(results.length, 2);
      });

      test('combines multiple filters', () {
        store.add(makeEntry(
          level: LogLevel.error,
          source: 'MCP',
          message: 'critical error',
        ));
        store.add(makeEntry(
          level: LogLevel.info,
          source: 'MCP',
          message: 'normal info',
        ));
        store.add(makeEntry(
          level: LogLevel.error,
          source: 'LSP',
          message: 'lsp error',
        ));

        final results = store.query(
          minLevel: LogLevel.error,
          source: 'MCP',
        );
        expect(results.length, 1);
        expect(results.first.message, 'critical error');
      });
    });
  });
}
