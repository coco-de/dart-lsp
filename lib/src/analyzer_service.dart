import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:dart_style/dart_style.dart';

import 'serverpod/serverpod_analyzer.dart';
import 'jaspr/jaspr_analyzer.dart';
import 'flutter/flutter_analyzer.dart';
import 'dcm/dcm_analyzer.dart';
import 'logger.dart';

/// Main analyzer service that coordinates all analysis features
class DartAnalyzerService {
  AnalysisContextCollection? _collection;
  final List<String> _workspaces = [];

  final ServerpodAnalyzer _serverpodAnalyzer = ServerpodAnalyzer();
  final JasprAnalyzer _jasprAnalyzer = JasprAnalyzer();
  final FlutterAnalyzer _flutterAnalyzer = FlutterAnalyzer();
  final DcmAnalyzer _dcmAnalyzer = DcmAnalyzer();
  final DartFormatter _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  /// Get Dart SDK path
  String? get _dartSdkPath {
    // Try DART_SDK environment variable first
    final dartSdk = Platform.environment['DART_SDK'];
    if (dartSdk != null && Directory(dartSdk).existsSync()) {
      return dartSdk;
    }

    // Try to find from `which dart` command
    try {
      final result = Process.runSync('which', ['dart']);
      if (result.exitCode == 0) {
        final dartPath = (result.stdout as String).trim();
        if (dartPath.isNotEmpty) {
          // Resolve symlinks to get actual path
          final resolved = File(dartPath).resolveSymbolicLinksSync();
          // dart executable is typically at <sdk>/bin/dart
          final sdkPath = File(resolved).parent.parent.path;
          if (Directory('$sdkPath/lib').existsSync()) {
            return sdkPath;
          }
        }
      }
    } catch (e) {
      Logger.instance.warn('LSP', 'Could not find dart via which: $e');
    }

    // Try common SDK locations
    final home = Platform.environment['HOME'] ?? '';
    final commonPaths = [
      '$home/fvm/default/bin/cache/dart-sdk', // FVM (Flutter)
      '/usr/local/opt/dart/libexec', // Homebrew Intel
      '/opt/homebrew/opt/dart/libexec', // Homebrew ARM
      '/opt/homebrew/Cellar/dart/3.7.2/libexec', // Homebrew specific version
      '$home/.asdf/installs/dart/latest', // asdf
    ];

    for (final path in commonPaths) {
      if (Directory('$path/lib').existsSync()) {
        return path;
      }
    }

    return null;
  }

  /// Add a workspace folder for analysis
  Future<void> addWorkspace(String workspacePath) async {
    _workspaces.add(workspacePath);
    await _initializeCollection();
  }

  /// Initialize the analysis context collection
  Future<void> _initializeCollection() async {
    if (_workspaces.isEmpty) return;

    try {
      final sdkPath = _dartSdkPath;
      Logger.instance.info('LSP', 'Using SDK path: $sdkPath');

      _collection = AnalysisContextCollection(
        includedPaths: _workspaces,
        resourceProvider: PhysicalResourceProvider.INSTANCE,
        sdkPath: sdkPath,
      );
    } catch (e, stackTrace) {
      Logger.instance
          .error('LSP', 'Failed to initialize analyzer: $e', stackTrace);
      Logger.instance
          .warn('LSP', 'Continuing without full analysis support...');
      _collection = null;
    }

    // Initialize framework-specific analyzers
    for (final workspace in _workspaces) {
      try {
        await _serverpodAnalyzer.initialize(workspace);
        await _jasprAnalyzer.initialize(workspace);
        await _flutterAnalyzer.initialize(workspace);
        await _dcmAnalyzer.initialize(workspace);
      } catch (e) {
        Logger.instance
            .error('LSP', 'Failed to initialize framework analyzers: $e');
      }
    }
  }

  /// Analyze a document and return diagnostics
  Future<List<Diagnostic>> analyze(String uri, String content) async {
    final diagnostics = <Diagnostic>[];
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return diagnostics;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        // Add analyzer errors
        for (final error in result.errors) {
          diagnostics.add(Diagnostic(
            range: _offsetToRange(error.offset, error.length, result.lineInfo),
            message: error.message,
            severity: _convertSeverity(error.severity),
            source: 'dart',
            code: error.errorCode.name,
          ));
        }

        // Add Serverpod-specific diagnostics
        if (_serverpodAnalyzer.isServerpodFile(filePath)) {
          diagnostics.addAll(
              await _serverpodAnalyzer.analyze(filePath, content, result));
        }

        // Add Jaspr-specific diagnostics
        if (_jasprAnalyzer.isJasprFile(filePath)) {
          diagnostics
              .addAll(await _jasprAnalyzer.analyze(filePath, content, result));
        }

        // Add Flutter-specific diagnostics
        if (_flutterAnalyzer.isFlutterFile(filePath)) {
          diagnostics.addAll(
              await _flutterAnalyzer.analyze(filePath, content, result));
        }

        // Add DCM diagnostics
        diagnostics
            .addAll(await _dcmAnalyzer.analyze(filePath, content, result));
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Analysis error: $e');
    }

    return diagnostics;
  }

  /// Get completions at a position
  Future<List<CompletionItem>> getCompletions(
    String uri,
    String content,
    int line,
    int character,
  ) async {
    final completions = <CompletionItem>[];
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return completions;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        final offset = result.lineInfo.getOffsetOfLine(line) + character;

        // Get standard Dart completions
        completions.addAll(await _getDartCompletions(result, offset));

        // Add Serverpod-specific completions
        if (_serverpodAnalyzer.isServerpodFile(filePath)) {
          completions.addAll(await _serverpodAnalyzer.getCompletions(
              filePath, offset, result));
        }

        // Add Jaspr-specific completions
        if (_jasprAnalyzer.isJasprFile(filePath)) {
          completions.addAll(
              await _jasprAnalyzer.getCompletions(filePath, offset, result));
        }

        // Add Flutter-specific completions
        if (_flutterAnalyzer.isFlutterFile(filePath)) {
          completions.addAll(
              await _flutterAnalyzer.getCompletions(filePath, offset, result));
        }
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Completion error: $e');
    }

    return completions;
  }

  /// Get hover information
  Future<Hover?> getHover(
    String uri,
    String content,
    int line,
    int character,
  ) async {
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return null;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        final offset = result.lineInfo.getOffsetOfLine(line) + character;
        final node = _findNodeAtOffset(result.unit, offset);

        if (node != null) {
          final element = _getElementForNode(node);
          if (element != null) {
            return Hover(
              contents: Either2.t1(MarkupContent(
                kind: MarkupKind.Markdown,
                value: _formatElementDocumentation(element),
              )),
              range: _offsetToRange(node.offset, node.length, result.lineInfo),
            );
          }
        }
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Hover error: $e');
    }

    return null;
  }

  /// Get definition location
  Future<Location?> getDefinition(
    String uri,
    String content,
    int line,
    int character,
  ) async {
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return null;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        final offset = result.lineInfo.getOffsetOfLine(line) + character;
        final node = _findNodeAtOffset(result.unit, offset);

        if (node != null) {
          final element = _getElementForNode(node);
          if (element != null) {
            final fragment = element.firstFragment;
            final sourceFile = fragment.libraryFragment?.source.fullName;
            if (sourceFile != null) {
              final elementResult =
                  await context.currentSession.getResolvedUnit(sourceFile);

              if (elementResult is ResolvedUnitResult) {
                return Location(
                  uri: Uri.file(sourceFile),
                  range: _offsetToRange(
                    fragment.nameOffset2 ?? 0,
                    element.name3?.length ?? 0,
                    elementResult.lineInfo,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Definition error: $e');
    }

    return null;
  }

  /// Get references
  Future<List<Location>> getReferences(
    String uri,
    String content,
    int line,
    int character,
  ) async {
    final references = <Location>[];
    // Implementation would require a full index of the workspace
    // This is a simplified version
    return references;
  }

  /// Get document symbols
  Future<List<DocumentSymbol>> getDocumentSymbols(
    String uri,
    String content,
  ) async {
    final symbols = <DocumentSymbol>[];
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return symbols;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        for (final declaration in result.unit.declarations) {
          final symbol = _declarationToSymbol(declaration, result.lineInfo);
          if (symbol != null) {
            symbols.add(symbol);
          }
        }
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Document symbols error: $e');
    }

    return symbols;
  }

  /// Get code actions
  Future<List<CodeAction>> getCodeActions(
    String uri,
    String content,
    Range range,
    List<Diagnostic> diagnostics,
  ) async {
    final actions = <CodeAction>[];
    final filePath = Uri.parse(uri).toFilePath();

    // Add quick fixes for diagnostics
    for (final diagnostic in diagnostics) {
      final fixes = await _getQuickFixes(filePath, content, diagnostic);
      actions.addAll(fixes);
    }

    // Add DCM code actions
    final dcmActions = await _dcmAnalyzer.getCodeActions(
        filePath, content, range, diagnostics);
    actions.addAll(dcmActions);

    // Add organize imports action
    actions.add(CodeAction(
      title: 'Organize Imports',
      kind: CodeActionKind.SourceOrganizeImports,
      edit: WorkspaceEdit(
        changes: {
          Uri.parse(uri): [
            TextEdit(
              range: Range(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 0),
              ),
              newText: '',
            ),
          ],
        },
      ),
    ));

    return actions;
  }

  /// Format document
  Future<List<TextEdit>> formatDocument(String uri, String content) async {
    try {
      final formatted = _formatter.format(content);

      if (formatted != content) {
        final lines = content.split('\n');
        final lastLineIndex = lines.length - 1;
        final lastLineLength = lines.isNotEmpty ? lines.last.length : 0;
        return [
          TextEdit(
            range: Range(
              start: Position(line: 0, character: 0),
              end: Position(line: lastLineIndex, character: lastLineLength),
            ),
            newText: formatted,
          ),
        ];
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Format error: $e');
    }

    return [];
  }

  /// Search workspace symbols
  Future<List<SymbolInformation>> searchWorkspaceSymbols(
    String query,
  ) async {
    final symbols = <SymbolInformation>[];
    // Implementation would search through all workspace files
    return symbols;
  }

  /// Get folding ranges
  Future<List<FoldingRange>> getFoldingRanges(
      String uri, String content) async {
    final ranges = <FoldingRange>[];
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return ranges;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        // Add folding ranges for classes, methods, etc.
        for (final declaration in result.unit.declarations) {
          final range = _getFoldingRange(declaration, result.lineInfo);
          if (range != null) {
            ranges.add(range);
          }
        }
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Folding ranges error: $e');
    }

    return ranges;
  }

  /// Rename symbol
  Future<WorkspaceEdit?> rename(
    String uri,
    String content,
    int line,
    int character,
    String newName,
  ) async {
    // Simplified implementation - full implementation would track all references
    return null;
  }

  /// Prepare rename
  Future<Either2<Range, PrepareRenameResult>?> prepareRename(
    String uri,
    String content,
    int line,
    int character,
  ) async {
    final filePath = Uri.parse(uri).toFilePath();

    if (_collection == null) return null;

    try {
      final context = _collection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        final offset = result.lineInfo.getOffsetOfLine(line) + character;
        final node = _findNodeAtOffset(result.unit, offset);

        if (node is ast.SimpleIdentifier) {
          return Either2.t1(
              _offsetToRange(node.offset, node.length, result.lineInfo));
        }
      }
    } catch (e) {
      Logger.instance.error('LSP', 'Prepare rename error: $e');
    }

    return null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    _collection = null;
  }

  // Helper methods

  Range _offsetToRange(int offset, int length, LineInfo lineInfo) {
    final start = lineInfo.getLocation(offset);
    final end = lineInfo.getLocation(offset + length);

    return Range(
      start: Position(
        line: start.lineNumber - 1,
        character: start.columnNumber - 1,
      ),
      end: Position(
        line: end.lineNumber - 1,
        character: end.columnNumber - 1,
      ),
    );
  }

  DiagnosticSeverity _convertSeverity(dynamic severity) {
    // Convert analyzer severity to LSP severity
    final severityName = severity.toString().toLowerCase();
    if (severityName.contains('error')) {
      return DiagnosticSeverity.Error;
    } else if (severityName.contains('warning')) {
      return DiagnosticSeverity.Warning;
    } else if (severityName.contains('info')) {
      return DiagnosticSeverity.Information;
    }
    return DiagnosticSeverity.Hint;
  }

  ast.AstNode? _findNodeAtOffset(ast.CompilationUnit unit, int offset) {
    ast.AstNode? found;
    unit.accept(_NodeFinder(offset, (node) => found = node));
    return found;
  }

  Element2? _getElementForNode(ast.AstNode node) {
    if (node is ast.SimpleIdentifier) {
      return node.element;
    }
    return null;
  }

  String _formatElementDocumentation(Element2 element) {
    final buffer = StringBuffer();

    // Add element type and name
    buffer.writeln('```dart');
    buffer.writeln(_getElementSignature(element));
    buffer.writeln('```');

    return buffer.toString();
  }

  String _getElementSignature(Element2 element) {
    if (element is TopLevelFunctionElement) {
      return element.displayName;
    } else if (element is ClassElement2) {
      return 'class ${element.name3}';
    } else if (element is TopLevelVariableElement2) {
      return '${element.type} ${element.name3}';
    }
    return element.displayName;
  }

  Future<List<CompletionItem>> _getDartCompletions(
    ResolvedUnitResult result,
    int offset,
  ) async {
    final completions = <CompletionItem>[];

    // Add basic completions based on context
    // This is a simplified implementation

    return completions;
  }

  Future<List<CodeAction>> _getQuickFixes(
    String filePath,
    String content,
    Diagnostic diagnostic,
  ) async {
    final fixes = <CodeAction>[];

    // Add quick fixes based on diagnostic code
    // This is a simplified implementation

    return fixes;
  }

  DocumentSymbol? _declarationToSymbol(
    ast.Declaration declaration,
    LineInfo lineInfo,
  ) {
    if (declaration is ast.ClassDeclaration) {
      return DocumentSymbol(
        name: declaration.name.lexeme,
        kind: SymbolKind.Class,
        range: _offsetToRange(declaration.offset, declaration.length, lineInfo),
        selectionRange: _offsetToRange(
          declaration.name.offset,
          declaration.name.length,
          lineInfo,
        ),
        children: declaration.members
            .map((m) => _memberToSymbol(m, lineInfo))
            .whereType<DocumentSymbol>()
            .toList(),
      );
    } else if (declaration is ast.FunctionDeclaration) {
      return DocumentSymbol(
        name: declaration.name.lexeme,
        kind: SymbolKind.Function,
        range: _offsetToRange(declaration.offset, declaration.length, lineInfo),
        selectionRange: _offsetToRange(
          declaration.name.offset,
          declaration.name.length,
          lineInfo,
        ),
      );
    } else if (declaration is ast.TopLevelVariableDeclaration) {
      final variables = declaration.variables.variables;
      if (variables.isNotEmpty) {
        return DocumentSymbol(
          name: variables.first.name.lexeme,
          kind: SymbolKind.Variable,
          range:
              _offsetToRange(declaration.offset, declaration.length, lineInfo),
          selectionRange: _offsetToRange(
            variables.first.name.offset,
            variables.first.name.length,
            lineInfo,
          ),
        );
      }
    }
    return null;
  }

  DocumentSymbol? _memberToSymbol(ast.ClassMember member, LineInfo lineInfo) {
    if (member is ast.MethodDeclaration) {
      return DocumentSymbol(
        name: member.name.lexeme,
        kind: SymbolKind.Method,
        range: _offsetToRange(member.offset, member.length, lineInfo),
        selectionRange: _offsetToRange(
          member.name.offset,
          member.name.length,
          lineInfo,
        ),
      );
    } else if (member is ast.FieldDeclaration) {
      final fields = member.fields.variables;
      if (fields.isNotEmpty) {
        return DocumentSymbol(
          name: fields.first.name.lexeme,
          kind: SymbolKind.Field,
          range: _offsetToRange(member.offset, member.length, lineInfo),
          selectionRange: _offsetToRange(
            fields.first.name.offset,
            fields.first.name.length,
            lineInfo,
          ),
        );
      }
    }
    return null;
  }

  FoldingRange? _getFoldingRange(
      ast.Declaration declaration, LineInfo lineInfo) {
    if (declaration is ast.ClassDeclaration ||
        declaration is ast.FunctionDeclaration) {
      final startLine = lineInfo.getLocation(declaration.offset).lineNumber - 1;
      final endLine = lineInfo.getLocation(declaration.end).lineNumber - 1;

      if (endLine > startLine) {
        return FoldingRange(
          startLine: startLine,
          endLine: endLine,
          kind: FoldingRangeKind.Region,
        );
      }
    }
    return null;
  }
}

/// Visitor to find AST node at offset
class _NodeFinder extends GeneralizingAstVisitor<void> {
  _NodeFinder(this.offset, this.onFound);

  final int offset;
  final void Function(ast.AstNode) onFound;

  @override
  void visitNode(ast.AstNode node) {
    if (node.offset <= offset && offset <= node.end) {
      onFound(node);
      super.visitNode(node);
    }
  }
}
