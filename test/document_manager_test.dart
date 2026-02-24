import 'package:dart_lsp/dart_lsp.dart';
import 'package:test/test.dart';

void main() {
  late DocumentManager manager;

  setUp(() {
    manager = DocumentManager();
  });

  group('DocumentManager', () {
    test('openDocument stores and getDocument retrieves content', () {
      manager.openDocument('file:///a.dart', 'void main() {}');
      expect(manager.getDocument('file:///a.dart'), 'void main() {}');
    });

    test('getDocument returns null for unknown uri', () {
      expect(manager.getDocument('file:///unknown.dart'), isNull);
    });

    test('updateDocument replaces content', () {
      manager.openDocument('file:///a.dart', 'old');
      manager.updateDocument('file:///a.dart', 'new');
      expect(manager.getDocument('file:///a.dart'), 'new');
    });

    test('closeDocument removes document', () {
      manager.openDocument('file:///a.dart', 'content');
      manager.closeDocument('file:///a.dart');
      expect(manager.getDocument('file:///a.dart'), isNull);
    });

    test('isOpen returns true for open documents', () {
      manager.openDocument('file:///a.dart', 'content');
      expect(manager.isOpen('file:///a.dart'), isTrue);
      expect(manager.isOpen('file:///b.dart'), isFalse);
    });

    test('openDocuments lists all open document URIs', () {
      manager.openDocument('file:///a.dart', 'a');
      manager.openDocument('file:///b.dart', 'b');
      expect(
        manager.openDocuments.toSet(),
        {'file:///a.dart', 'file:///b.dart'},
      );
    });

    test('openDocuments is empty initially', () {
      expect(manager.openDocuments, isEmpty);
    });
  });
}
