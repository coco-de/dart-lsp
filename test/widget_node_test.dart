import 'package:dart_lsp/dart_lsp.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetNode', () {
    test('stores name, line, and column', () {
      final node = WidgetNode(name: 'Container', line: 10, column: 5);
      expect(node.name, 'Container');
      expect(node.line, 10);
      expect(node.column, 5);
    });

    test('children defaults to empty list', () {
      final node = WidgetNode(name: 'Text', line: 1, column: 1);
      expect(node.children, isEmpty);
    });

    test('accepts explicit children', () {
      final child1 = WidgetNode(name: 'Text', line: 3, column: 5);
      final child2 = WidgetNode(name: 'Icon', line: 4, column: 5);
      final parent = WidgetNode(
        name: 'Row',
        line: 2,
        column: 3,
        children: [child1, child2],
      );
      expect(parent.children, hasLength(2));
      expect(parent.children[0].name, 'Text');
      expect(parent.children[1].name, 'Icon');
    });

    test('supports nested tree structure', () {
      final tree = WidgetNode(
        name: 'Scaffold',
        line: 1,
        column: 1,
        children: [
          WidgetNode(
            name: 'AppBar',
            line: 2,
            column: 3,
            children: [
              WidgetNode(name: 'Text', line: 3, column: 5),
            ],
          ),
          WidgetNode(
            name: 'Column',
            line: 5,
            column: 3,
            children: [
              WidgetNode(name: 'Text', line: 6, column: 5),
              WidgetNode(name: 'ElevatedButton', line: 7, column: 5),
            ],
          ),
        ],
      );

      expect(tree.children, hasLength(2));
      expect(tree.children[0].children, hasLength(1));
      expect(tree.children[1].children, hasLength(2));
      expect(tree.children[1].children[1].name, 'ElevatedButton');
    });
  });
}
