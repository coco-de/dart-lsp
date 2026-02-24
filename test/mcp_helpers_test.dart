import 'dart:convert';
import 'dart:io';

import 'package:dart_lsp/dart_lsp.dart';
import 'package:test/test.dart';

void main() {
  group('parseJsonTestResults', () {
    test('returns no-tests message for empty input', () {
      final result = parseJsonTestResults('');
      expect(result['formatted'], contains('No tests found'));
    });

    test('parses all-passing results', () {
      final lines = [
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 1, 'name': 'test one'},
        }),
        jsonEncode({
          'type': 'testDone',
          'testID': 1,
          'result': 'success',
          'skipped': false,
        }),
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 2, 'name': 'test two'},
        }),
        jsonEncode({
          'type': 'testDone',
          'testID': 2,
          'result': 'success',
          'skipped': false,
        }),
      ].join('\n');

      final result = parseJsonTestResults(lines);
      expect(result['passed'], 2);
      expect(result['failed'], 0);
      expect(result['skipped'], 0);
      expect(result['formatted'], contains('Passed: 2'));
    });

    test('parses mixed pass/fail/skip results', () {
      final lines = [
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 1, 'name': 'passes'},
        }),
        jsonEncode({
          'type': 'testDone',
          'testID': 1,
          'result': 'success',
          'skipped': false,
        }),
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 2, 'name': 'fails'},
        }),
        jsonEncode({
          'type': 'testDone',
          'testID': 2,
          'result': 'failure',
          'skipped': false,
        }),
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 3, 'name': 'skipped'},
        }),
        jsonEncode({
          'type': 'testDone',
          'testID': 3,
          'result': 'success',
          'skipped': true,
        }),
      ].join('\n');

      final result = parseJsonTestResults(lines);
      expect(result['passed'], 1);
      expect(result['failed'], 1);
      expect(result['skipped'], 1);
    });

    test('captures error events with test names', () {
      final lines = [
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 1, 'name': 'broken test'},
        }),
        jsonEncode({
          'type': 'error',
          'testID': 1,
          'error': 'Expected: true\n  Actual: false',
        }),
        jsonEncode({
          'type': 'testDone',
          'testID': 1,
          'result': 'failure',
          'skipped': false,
        }),
      ].join('\n');

      final result = parseJsonTestResults(lines);
      expect(result['failures'], isNotNull);
      final failures = result['failures'] as List;
      expect(failures.first, contains('broken test'));
    });

    test('skips non-JSON lines gracefully', () {
      final lines = [
        'not json at all',
        '{"type": "testStart", "test": {"id": 1, "name": "t"}}',
        'another bad line',
        '{"type": "testDone", "testID": 1, "result": "success", "skipped": false}',
      ].join('\n');

      final result = parseJsonTestResults(lines);
      expect(result['passed'], 1);
    });
  });

  group('formatWidgetTree', () {
    test('returns empty string for empty list', () {
      expect(formatWidgetTree([], 0), '');
    });

    test('formats single root node without prefix', () {
      final nodes = [
        WidgetNode(name: 'Scaffold', line: 10, column: 5),
      ];
      final result = formatWidgetTree(nodes, 0);
      expect(result, 'Scaffold (line 10)\n');
    });

    test('formats sibling nodes with correct connectors', () {
      final nodes = [
        WidgetNode(name: 'Row', line: 1, column: 1),
        WidgetNode(name: 'Column', line: 5, column: 1),
      ];
      final result = formatWidgetTree(nodes, 1);
      expect(result, contains('├─ Row'));
      expect(result, contains('└─ Column'));
    });

    test('formats nested tree with 3+ levels', () {
      final nodes = [
        WidgetNode(
          name: 'Scaffold',
          line: 1,
          column: 1,
          children: [
            WidgetNode(
              name: 'Column',
              line: 2,
              column: 3,
              children: [
                WidgetNode(name: 'Text', line: 3, column: 5),
              ],
            ),
          ],
        ),
      ];
      final result = formatWidgetTree(nodes, 0);
      expect(result, contains('Scaffold (line 1)'));
      expect(result, contains('└─ Column (line 2)'));
      expect(result, contains('└─ Text (line 3)'));
    });
  });

  group('formatDiagnostics', () {
    Map<String, dynamic> makeDiag(String severity, String msg, int line, int col) {
      return {
        'severity': severity,
        'message': msg,
        'range': {
          'start': {'line': line, 'character': col},
        },
      };
    }

    test('maps error severity to cross icon', () {
      final result = formatDiagnostics([makeDiag('error', 'bad', 0, 0)]);
      expect(result, contains('\u274c'));
    });

    test('maps warning severity to warning icon', () {
      final result = formatDiagnostics([makeDiag('warning', 'warn', 0, 0)]);
      expect(result, contains('\u26a0'));
    });

    test('maps info severity to info icon', () {
      final result = formatDiagnostics([makeDiag('info', 'note', 0, 0)]);
      expect(result, contains('\u2139'));
    });

    test('converts 0-indexed line/col to 1-indexed', () {
      final result = formatDiagnostics([makeDiag('error', 'msg', 4, 9)]);
      expect(result, contains('Line 5:10'));
    });
  });

  group('severityToString', () {
    test('returns error for error-containing strings', () {
      expect(severityToString('DiagnosticSeverity.Error'), 'error');
    });

    test('returns warning for warning-containing strings', () {
      expect(severityToString('DiagnosticSeverity.Warning'), 'warning');
    });

    test('returns info for info-containing strings', () {
      expect(severityToString('DiagnosticSeverity.Information'), 'info');
    });

    test('returns hint for anything else', () {
      expect(severityToString('DiagnosticSeverity.Hint'), 'hint');
      expect(severityToString('unknown'), 'hint');
    });
  });

  group('completionKindToString', () {
    test('returns text for null', () {
      expect(completionKindToString(null), 'text');
    });

    test('returns class for class-containing strings', () {
      expect(completionKindToString('CompletionItemKind.Class'), 'class');
    });

    test('returns function for function/method strings', () {
      expect(completionKindToString('CompletionItemKind.Function'), 'function');
      expect(completionKindToString('CompletionItemKind.Method'), 'function');
    });

    test('returns variable for variable/field strings', () {
      expect(completionKindToString('CompletionItemKind.Variable'), 'variable');
      expect(completionKindToString('CompletionItemKind.Field'), 'variable');
    });

    test('returns property for property strings', () {
      expect(completionKindToString('CompletionItemKind.Property'), 'property');
    });

    test('returns snippet for snippet strings', () {
      expect(completionKindToString('CompletionItemKind.Snippet'), 'snippet');
    });

    test('returns text for unknown strings', () {
      expect(completionKindToString('CompletionItemKind.Keyword'), 'text');
    });
  });

  group('getOffset', () {
    test('returns 0 for line 0, character 0', () {
      expect(getOffset('hello\nworld', 0, 0), 0);
    });

    test('computes offset for multiline content', () {
      const content = 'abc\ndef\nghi';
      // line 0 = "abc" (len 3 + 1 newline = 4)
      // line 1, char 0 => offset 4
      expect(getOffset(content, 1, 0), 4);
      // line 1, char 2 => offset 6 (pointing at 'f')
      expect(getOffset(content, 1, 2), 6);
      // line 2, char 1 => offset 8 + 1 = 9 (pointing at 'h' + 1 = 'i')
      expect(getOffset(content, 2, 1), 9);
    });

    test('clamps to content length when out of range', () {
      const content = 'short';
      // Requesting way beyond content length
      expect(getOffset(content, 100, 100), content.length);
    });
  });

  group('findProjectRoot', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dart_lsp_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('finds pubspec.yaml in the given directory', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: test_pkg');
      expect(findProjectRoot(tempDir.path), tempDir.path);
    });

    test('finds pubspec.yaml in parent directory', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('name: test_pkg');
      final subDir = Directory('${tempDir.path}/lib/src')
        ..createSync(recursive: true);
      expect(findProjectRoot(subDir.path), tempDir.path);
    });

    test('returns null when no pubspec.yaml exists', () {
      final subDir = Directory('${tempDir.path}/no_project')
        ..createSync(recursive: true);
      expect(findProjectRoot(subDir.path), isNull);
    });
  });

  group('isFlutterProject', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dart_lsp_flutter_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns true when flutter dependency exists', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');
      expect(isFlutterProject(tempDir.path), isTrue);
    });

    test('returns false when flutter dependency is absent', () {
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
dependencies:
  http: ^1.0.0
''');
      expect(isFlutterProject(tempDir.path), isFalse);
    });

    test('returns false for malformed yaml', () {
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync(': : : bad yaml {{');
      expect(isFlutterProject(tempDir.path), isFalse);
    });

    test('returns false when pubspec.yaml does not exist', () {
      expect(isFlutterProject(tempDir.path), isFalse);
    });
  });
}
