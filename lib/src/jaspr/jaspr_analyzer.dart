import 'dart:io';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Jaspr-specific analyzer for web components and SSR
class JasprAnalyzer {
  bool _isJasprProject = false;

  /// Initialize the Jaspr analyzer for a workspace
  Future<void> initialize(String workspacePath) async {
    // Check if this is a Jaspr project
    final pubspecFile = File(path.join(workspacePath, 'pubspec.yaml'));
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final pubspec = loadYaml(content) as YamlMap?;

      if (pubspec != null) {
        final dependencies = pubspec['dependencies'] as YamlMap?;
        if (dependencies != null && dependencies.containsKey('jaspr')) {
          _isJasprProject = true;
        }
      }
    }
  }

  /// Check if file is a Jaspr file
  bool isJasprFile(String filePath) {
    if (!_isJasprProject) return false;

    return filePath.contains('_web') ||
        filePath.contains('components') ||
        filePath.contains('pages');
  }

  /// Analyze Jaspr-specific code
  Future<List<Diagnostic>> analyze(
    String filePath,
    String content,
    ResolvedUnitResult result,
  ) async {
    final diagnostics = <Diagnostic>[];

    if (!_isJasprProject) return diagnostics;

    // Check for common Jaspr issues

    // 1. Check component structure
    diagnostics.addAll(_checkComponentStructure(content, result));

    // 2. Check build method
    diagnostics.addAll(_checkBuildMethod(content, result));

    // 3. Check state management
    diagnostics.addAll(_checkStateManagement(content, result));

    return diagnostics;
  }

  /// Get Jaspr-specific completions
  Future<List<CompletionItem>> getCompletions(
    String filePath,
    int offset,
    ResolvedUnitResult result,
  ) async {
    final completions = <CompletionItem>[];

    if (!_isJasprProject) return completions;

    // Add Jaspr-specific completions

    // 1. StatelessComponent template
    completions.add(CompletionItem(
      label: 'jaspr-stateless',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
class \${1:MyComponent} extends StatelessComponent {
  const \${1:MyComponent}({super.key});
  
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(classes: '\${2:container}', [
      \${0}
    ]);
  }
}''',
      detail: 'Jaspr StatelessComponent',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Jaspr StatelessComponent.',
      )),
    ));

    // 2. StatefulComponent template
    completions.add(CompletionItem(
      label: 'jaspr-stateful',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
class \${1:MyComponent} extends StatefulComponent {
  const \${1:MyComponent}({super.key});
  
  @override
  State<\${1:MyComponent}> createState() => \${1:MyComponent}State();
}

class \${1:MyComponent}State extends State<\${1:MyComponent}> {
  \${2:// State variables}
  
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(classes: '\${3:container}', [
      \${0}
    ]);
  }
}''',
      detail: 'Jaspr StatefulComponent',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Jaspr StatefulComponent with State class.',
      )),
    ));

    // 3. HTML elements
    final htmlElements = [
      ('div', 'Division element'),
      ('span', 'Span element'),
      ('p', 'Paragraph element'),
      ('h1', 'Heading 1'),
      ('h2', 'Heading 2'),
      ('h3', 'Heading 3'),
      ('a', 'Anchor/link element'),
      ('button', 'Button element'),
      ('input', 'Input element'),
      ('form', 'Form element'),
      ('img', 'Image element'),
      ('ul', 'Unordered list'),
      ('ol', 'Ordered list'),
      ('li', 'List item'),
      ('table', 'Table element'),
      ('tr', 'Table row'),
      ('td', 'Table cell'),
      ('th', 'Table header cell'),
    ];

    for (final (element, description) in htmlElements) {
      completions.add(CompletionItem(
        label: element,
        kind: CompletionItemKind.Function,
        insertTextFormat: InsertTextFormat.Snippet,
        insertText: '$element(classes: \'\${1:class}\', [\n  \${0}\n])',
        detail: 'Jaspr HTML: $description',
        documentation: Either2.t1(MarkupContent(
          kind: MarkupKind.Markdown,
          value: 'Creates a `<$element>` HTML element.',
        )),
      ));
    }

    // 4. Event handlers
    completions.add(CompletionItem(
      label: 'onClick',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: 'onClick: () {\n  \${1:// Handle click}\n  \${0}\n}',
      detail: 'Jaspr onClick handler',
    ));

    completions.add(CompletionItem(
      label: 'onInput',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: 'onInput: (value) {\n  \${1:// Handle input}\n  \${0}\n}',
      detail: 'Jaspr onInput handler',
    ));

    // 5. CSS styling
    completions.add(CompletionItem(
      label: 'jaspr-css',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
@css
final styles = [
  css('.\${1:class-name}')
    .box(padding: EdgeInsets.all(\${2:16}.px))
    .background(color: \${3:Colors.white})
    \${0}
];''',
      detail: 'Jaspr CSS styles',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates Jaspr CSS styles using the @css annotation.',
      )),
    ));

    // 6. Route definition
    completions.add(CompletionItem(
      label: 'jaspr-route',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
@Route('\${1:/path}')
class \${2:PageName}Page extends StatelessComponent {
  const \${2:PageName}Page({super.key});
  
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div([
      \${0}
    ]);
  }
}''',
      detail: 'Jaspr route page',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Jaspr page with route annotation.',
      )),
    ));

    // 7. Text element
    completions.add(CompletionItem(
      label: 'text',
      kind: CompletionItemKind.Function,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: 'text(\'\${1:content}\')',
      detail: 'Jaspr text content',
    ));

    return completions;
  }

  // Helper methods

  List<Diagnostic> _checkComponentStructure(
      String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];

    // Check that StatelessComponent has const constructor
    if (content.contains('extends StatelessComponent') &&
        !content.contains('const ')) {
      // Find the class declaration
      final classMatch = RegExp(r'class\s+(\w+)\s+extends\s+StatelessComponent')
          .firstMatch(content);
      if (classMatch != null) {
        final offset = classMatch.start;
        diagnostics.add(Diagnostic(
          range: Range(
            start:
                Position(line: _getLineNumber(content, offset), character: 0),
            end:
                Position(line: _getLineNumber(content, offset), character: 100),
          ),
          message: 'Consider using const constructor for StatelessComponent',
          severity: DiagnosticSeverity.Information,
          source: 'jaspr',
          code: 'prefer_const_constructor',
        ));
      }
    }

    return diagnostics;
  }

  List<Diagnostic> _checkBuildMethod(
      String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];

    // Check that build method uses sync*
    if (content.contains('extends StatelessComponent') ||
        content.contains('extends State<')) {
      if (content.contains('Iterable<Component> build') &&
          !content.contains('sync*')) {
        final buildMatch =
            RegExp(r'Iterable<Component>\s+build').firstMatch(content);
        if (buildMatch != null) {
          final offset = buildMatch.start;
          diagnostics.add(Diagnostic(
            range: Range(
              start:
                  Position(line: _getLineNumber(content, offset), character: 0),
              end: Position(
                  line: _getLineNumber(content, offset), character: 100),
            ),
            message: 'Build method should use sync* for generator syntax',
            severity: DiagnosticSeverity.Warning,
            source: 'jaspr',
            code: 'missing_sync_star',
          ));
        }
      }
    }

    return diagnostics;
  }

  List<Diagnostic> _checkStateManagement(
      String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];

    // Check for setState usage in StatefulComponent
    if (content.contains('extends State<') && content.contains('setState')) {
      // This is fine, just checking the pattern
    }

    return diagnostics;
  }

  int _getLineNumber(String content, int offset) {
    return content.substring(0, offset).split('\n').length - 1;
  }
}
