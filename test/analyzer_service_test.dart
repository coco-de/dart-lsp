import 'package:dart_lsp/dart_lsp.dart';
import 'package:test/test.dart';

void main() {
  late DartAnalyzerService service;

  setUp(() {
    service = DartAnalyzerService();
  });

  group('DartAnalyzerService', () {
    group('formatDocument', () {
      test('returns empty list for already formatted code', () async {
        const code = 'void main() {\n  print(\'hello\');\n}\n';
        final edits = await service.formatDocument('file:///test.dart', code);
        expect(edits, isEmpty);
      });

      test('returns edits for poorly formatted code', () async {
        const code = 'void main(){print(\'hello\');}';
        final edits = await service.formatDocument('file:///test.dart', code);
        expect(edits, isNotEmpty);
        // The formatted version should be valid Dart
        expect(edits.first.newText, contains('void main()'));
      });

      test('returns empty list for code with syntax errors', () async {
        const code = 'void main( { print }';
        final edits = await service.formatDocument('file:///test.dart', code);
        // dart_style throws on syntax errors, so we expect empty edits
        expect(edits, isEmpty);
      });
    });
  });
}
