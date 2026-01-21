import 'dart:io';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Flutter-specific analyzer for widgets and state management
class FlutterAnalyzer {
  bool _isFlutterProject = false;
  
  /// Initialize the Flutter analyzer for a workspace
  Future<void> initialize(String workspacePath) async {
    // Check if this is a Flutter project
    final pubspecFile = File(path.join(workspacePath, 'pubspec.yaml'));
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final pubspec = loadYaml(content) as YamlMap?;
      
      if (pubspec != null) {
        final dependencies = pubspec['dependencies'] as YamlMap?;
        if (dependencies != null && dependencies.containsKey('flutter')) {
          _isFlutterProject = true;
        }
      }
    }
  }
  
  /// Check if file is a Flutter file
  bool isFlutterFile(String filePath) {
    if (!_isFlutterProject) return false;
    
    return filePath.contains('_app') ||
           filePath.contains('lib') ||
           filePath.endsWith('_widget.dart') ||
           filePath.endsWith('_screen.dart') ||
           filePath.endsWith('_page.dart');
  }
  
  /// Analyze Flutter-specific code
  Future<List<Diagnostic>> analyze(
    String filePath,
    String content,
    ResolvedUnitResult result,
  ) async {
    final diagnostics = <Diagnostic>[];
    
    if (!_isFlutterProject) return diagnostics;
    
    // Check for common Flutter issues
    
    // 1. Check widget structure
    diagnostics.addAll(_checkWidgetStructure(content, result));
    
    // 2. Check const usage
    diagnostics.addAll(_checkConstUsage(content, result));
    
    // 3. Check dispose methods
    diagnostics.addAll(_checkDisposeMethod(content, result));
    
    // 4. Check BuildContext usage
    diagnostics.addAll(_checkBuildContextUsage(content, result));
    
    return diagnostics;
  }
  
  /// Get Flutter-specific completions
  Future<List<CompletionItem>> getCompletions(
    String filePath,
    int offset,
    ResolvedUnitResult result,
  ) async {
    final completions = <CompletionItem>[];
    
    if (!_isFlutterProject) return completions;
    
    // Add Flutter-specific completions
    
    // 1. StatelessWidget template
    completions.add(CompletionItem(
      label: 'stless',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
class \${1:MyWidget} extends StatelessWidget {
  const \${1:MyWidget}({super.key});
  
  @override
  Widget build(BuildContext context) {
    return \${2:Container}(
      \${0}
    );
  }
}''',
      detail: 'Flutter StatelessWidget',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Flutter StatelessWidget.',
      )),
    ));
    
    // 2. StatefulWidget template
    completions.add(CompletionItem(
      label: 'stful',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
class \${1:MyWidget} extends StatefulWidget {
  const \${1:MyWidget}({super.key});
  
  @override
  State<\${1:MyWidget}> createState() => _\${1:MyWidget}State();
}

class _\${1:MyWidget}State extends State<\${1:MyWidget}> {
  @override
  Widget build(BuildContext context) {
    return \${2:Container}(
      \${0}
    );
  }
}''',
      detail: 'Flutter StatefulWidget',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Flutter StatefulWidget with State class.',
      )),
    ));
    
    // 3. HookWidget template (flutter_hooks)
    completions.add(CompletionItem(
      label: 'hookwidget',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
class \${1:MyWidget} extends HookWidget {
  const \${1:MyWidget}({super.key});
  
  @override
  Widget build(BuildContext context) {
    final \${2:state} = useState(\${3:initialValue});
    
    return \${4:Container}(
      \${0}
    );
  }
}''',
      detail: 'Flutter HookWidget',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Flutter HookWidget (requires flutter_hooks).',
      )),
    ));
    
    // 4. ConsumerWidget template (Riverpod)
    completions.add(CompletionItem(
      label: 'consumer',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
class \${1:MyWidget} extends ConsumerWidget {
  const \${1:MyWidget}({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final \${2:state} = ref.watch(\${3:provider});
    
    return \${4:Container}(
      \${0}
    );
  }
}''',
      detail: 'Riverpod ConsumerWidget',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Riverpod ConsumerWidget.',
      )),
    ));
    
    // 5. Provider definition
    completions.add(CompletionItem(
      label: 'provider',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
final \${1:myProvider} = Provider<\${2:Type}>((ref) {
  return \${3:value};
});''',
      detail: 'Riverpod Provider',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Riverpod Provider.',
      )),
    ));
    
    // 6. FutureProvider
    completions.add(CompletionItem(
      label: 'futureprovider',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
final \${1:myProvider} = FutureProvider<\${2:Type}>((ref) async {
  return \${3:await fetchData()};
});''',
      detail: 'Riverpod FutureProvider',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Creates a new Riverpod FutureProvider for async data.',
      )),
    ));
    
    // 7. Common widgets
    final commonWidgets = [
      ('Container', 'Container widget with decoration'),
      ('Column', 'Vertical layout'),
      ('Row', 'Horizontal layout'),
      ('Stack', 'Overlapping widgets'),
      ('ListView', 'Scrollable list'),
      ('GridView', 'Grid layout'),
      ('Card', 'Material card'),
      ('Scaffold', 'Basic material design layout'),
      ('AppBar', 'Material app bar'),
      ('FloatingActionButton', 'FAB button'),
      ('ElevatedButton', 'Elevated button'),
      ('TextButton', 'Text button'),
      ('IconButton', 'Icon button'),
      ('TextField', 'Text input field'),
      ('Text', 'Text display'),
      ('Image', 'Image display'),
      ('Icon', 'Icon display'),
      ('Padding', 'Padding wrapper'),
      ('Center', 'Center alignment'),
      ('Expanded', 'Flexible expansion'),
      ('SizedBox', 'Fixed size box'),
    ];
    
    for (final (widget, description) in commonWidgets) {
      completions.add(CompletionItem(
        label: widget,
        kind: CompletionItemKind.Class,
        detail: 'Flutter Widget: $description',
      ));
    }
    
    // 8. initState
    completions.add(CompletionItem(
      label: 'initstate',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
@override
void initState() {
  super.initState();
  \${0}
}''',
      detail: 'Flutter initState override',
    ));
    
    // 9. dispose
    completions.add(CompletionItem(
      label: 'dispose',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
@override
void dispose() {
  \${1:// Cleanup}
  super.dispose();
}''',
      detail: 'Flutter dispose override',
    ));
    
    // 10. setState
    completions.add(CompletionItem(
      label: 'setstate',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
setState(() {
  \${0}
});''',
      detail: 'Flutter setState',
    ));
    
    // 11. MediaQuery
    completions.add(CompletionItem(
      label: 'mediaquery',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: 'final size = MediaQuery.of(context).size;',
      detail: 'Get MediaQuery size',
    ));
    
    // 12. Theme
    completions.add(CompletionItem(
      label: 'theme',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: 'final theme = Theme.of(context);',
      detail: 'Get Theme data',
    ));
    
    return completions;
  }
  
  // Helper methods
  
  List<Diagnostic> _checkWidgetStructure(String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];
    
    // Check for large build methods (more than 100 lines)
    final buildMethodRegex = RegExp(
      r'Widget\s+build\s*\(BuildContext\s+context\)\s*\{',
      multiLine: true,
    );
    
    for (final match in buildMethodRegex.allMatches(content)) {
      final startOffset = match.start;
      // Find matching closing brace (simplified check)
      var braceCount = 0;
      var endOffset = match.end;
      var foundStart = false;
      
      for (var i = match.end; i < content.length; i++) {
        if (content[i] == '{') {
          braceCount++;
          foundStart = true;
        } else if (content[i] == '}') {
          if (braceCount == 0 && foundStart) {
            endOffset = i;
            break;
          }
          braceCount--;
        }
      }
      
      final methodContent = content.substring(startOffset, endOffset);
      final lineCount = methodContent.split('\n').length;
      
      if (lineCount > 100) {
        diagnostics.add(Diagnostic(
          range: Range(
            start: Position(line: _getLineNumber(content, startOffset), character: 0),
            end: Position(line: _getLineNumber(content, startOffset), character: 50),
          ),
          message: 'Build method is too long ($lineCount lines). Consider extracting widgets.',
          severity: DiagnosticSeverity.Information,
          source: 'flutter',
          code: 'large_build_method',
        ));
      }
    }
    
    return diagnostics;
  }
  
  List<Diagnostic> _checkConstUsage(String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];
    
    // Check for missing const on StatelessWidget constructors
    if (content.contains('extends StatelessWidget')) {
      final constructorRegex = RegExp(r'(\w+)\s*\(\{super\.key\}\)');
      for (final match in constructorRegex.allMatches(content)) {
        final beforeMatch = content.substring(
          match.start > 10 ? match.start - 10 : 0,
          match.start,
        );
        
        if (!beforeMatch.contains('const')) {
          diagnostics.add(Diagnostic(
            range: Range(
              start: Position(line: _getLineNumber(content, match.start), character: 0),
              end: Position(line: _getLineNumber(content, match.start), character: 50),
            ),
            message: 'Consider using const constructor for StatelessWidget',
            severity: DiagnosticSeverity.Information,
            source: 'flutter',
            code: 'prefer_const_constructor',
          ));
        }
      }
    }
    
    return diagnostics;
  }
  
  List<Diagnostic> _checkDisposeMethod(String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];
    
    // Check for controllers without dispose
    final controllerPatterns = [
      'TextEditingController',
      'AnimationController',
      'ScrollController',
      'PageController',
      'TabController',
    ];
    
    for (final controller in controllerPatterns) {
      if (content.contains(controller) && !content.contains('void dispose()')) {
        final match = RegExp(controller).firstMatch(content);
        if (match != null) {
          diagnostics.add(Diagnostic(
            range: Range(
              start: Position(line: _getLineNumber(content, match.start), character: 0),
              end: Position(line: _getLineNumber(content, match.start), character: 50),
            ),
            message: '$controller should be disposed in dispose() method',
            severity: DiagnosticSeverity.Warning,
            source: 'flutter',
            code: 'missing_dispose',
          ));
        }
      }
    }
    
    return diagnostics;
  }
  
  List<Diagnostic> _checkBuildContextUsage(String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];
    
    // Check for BuildContext stored in instance variables
    if (RegExp(r'BuildContext\s+\w+;').hasMatch(content) ||
        RegExp(r'late\s+BuildContext\s+\w+;').hasMatch(content)) {
      final match = RegExp(r'(late\s+)?BuildContext\s+\w+;').firstMatch(content);
      if (match != null) {
        diagnostics.add(Diagnostic(
          range: Range(
            start: Position(line: _getLineNumber(content, match.start), character: 0),
            end: Position(line: _getLineNumber(content, match.start), character: 50),
          ),
          message: 'Avoid storing BuildContext in instance variables. It may lead to memory leaks.',
          severity: DiagnosticSeverity.Warning,
          source: 'flutter',
          code: 'stored_build_context',
        ));
      }
    }
    
    return diagnostics;
  }
  
  int _getLineNumber(String content, int offset) {
    return content.substring(0, offset).split('\n').length - 1;
  }
}
