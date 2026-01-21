import 'dart:io';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Serverpod-specific analyzer for endpoints, protocols, and migrations
class ServerpodAnalyzer {
  bool _isServerpodProject = false;
  final Map<String, dynamic> _protocols = {};

  /// Initialize the Serverpod analyzer for a workspace
  Future<void> initialize(String workspacePath) async {
    // Check if this is a Serverpod project
    final pubspecFile = File(path.join(workspacePath, 'pubspec.yaml'));
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final pubspec = loadYaml(content) as YamlMap?;

      if (pubspec != null) {
        final dependencies = pubspec['dependencies'] as YamlMap?;
        if (dependencies != null && dependencies.containsKey('serverpod')) {
          _isServerpodProject = true;
          await _loadProtocols(workspacePath);
        }
      }
    }
  }

  /// Load protocol definitions
  Future<void> _loadProtocols(String workspacePath) async {
    final protocolDir =
        Directory(path.join(workspacePath, 'lib', 'src', 'protocol'));
    if (await protocolDir.exists()) {
      await for (final file in protocolDir.list(recursive: true)) {
        if (file is File && file.path.endsWith('.yaml')) {
          try {
            final content = await file.readAsString();
            final yaml = loadYaml(content) as YamlMap?;
            if (yaml != null && yaml.containsKey('class')) {
              _protocols[yaml['class'] as String] = yaml;
            }
          } catch (e) {
            stderr.writeln('[Serverpod] Error loading protocol: $e');
          }
        }
      }
    }
  }

  /// Check if file is a Serverpod file
  bool isServerpodFile(String filePath) {
    if (!_isServerpodProject) return false;

    final fileName = path.basename(filePath);
    final dirName = path.basename(path.dirname(filePath));

    return filePath.contains('_server') ||
        dirName == 'endpoints' ||
        dirName == 'protocol' ||
        fileName.endsWith('_endpoint.dart');
  }

  /// Analyze Serverpod-specific code
  Future<List<Diagnostic>> analyze(
    String filePath,
    String content,
    ResolvedUnitResult result,
  ) async {
    final diagnostics = <Diagnostic>[];

    if (!_isServerpodProject) return diagnostics;

    // Check for common Serverpod issues

    // 1. Check endpoint method signatures
    if (filePath.contains('endpoint')) {
      diagnostics.addAll(_checkEndpointMethods(content, result));
    }

    // 2. Check Session usage
    diagnostics.addAll(_checkSessionUsage(content, result));

    // 3. Check protocol references
    diagnostics.addAll(_checkProtocolReferences(content, result));

    return diagnostics;
  }

  /// Get Serverpod-specific completions
  Future<List<CompletionItem>> getCompletions(
    String filePath,
    int offset,
    ResolvedUnitResult result,
  ) async {
    final completions = <CompletionItem>[];

    if (!_isServerpodProject) return completions;

    // Add Serverpod-specific completions

    // 1. Endpoint method template
    completions.add(CompletionItem(
      label: 'endpoint-method',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
Future<\${1:ReturnType}> \${2:methodName}(Session session\${3:, \${4:params}}) async {
  \${5:// TODO: Implement}
  \${0}
}''',
      detail: 'Serverpod endpoint method',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value:
            'Creates a new Serverpod endpoint method with Session parameter.',
      )),
    ));

    // 2. Database query
    completions.add(CompletionItem(
      label: 'db-find',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
final result = await \${1:Model}.db.find(
  session,
  where: (t) => t.\${2:field}.equals(\${3:value}),
);''',
      detail: 'Serverpod database find',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Query database using Serverpod ORM.',
      )),
    ));

    // 3. Database insert
    completions.add(CompletionItem(
      label: 'db-insert',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
final result = await \${1:Model}.db.insertRow(session, \${2:model});''',
      detail: 'Serverpod database insert',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Insert a row into database using Serverpod ORM.',
      )),
    ));

    // 4. Transaction
    completions.add(CompletionItem(
      label: 'db-transaction',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
await session.db.transaction((transaction) async {
  \${1:// Database operations}
  \${0}
});''',
      detail: 'Serverpod database transaction',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Wrap multiple database operations in a transaction.',
      )),
    ));

    // 5. Authentication check
    completions.add(CompletionItem(
      label: 'auth-check',
      kind: CompletionItemKind.Snippet,
      insertTextFormat: InsertTextFormat.Snippet,
      insertText: '''
final userId = await session.auth.authenticatedUserId;
if (userId == null) {
  throw AuthenticationException('\${1:Authentication required}');
}''',
      detail: 'Serverpod authentication check',
      documentation: Either2.t1(MarkupContent(
        kind: MarkupKind.Markdown,
        value: 'Check if user is authenticated.',
      )),
    ));

    // 6. Protocol classes
    for (final entry in _protocols.entries) {
      completions.add(CompletionItem(
        label: entry.key,
        kind: CompletionItemKind.Class,
        detail: 'Serverpod Protocol',
        documentation: Either2.t1(MarkupContent(
          kind: MarkupKind.Markdown,
          value: _formatProtocolDoc(entry.value),
        )),
      ));
    }

    return completions;
  }

  // Helper methods

  List<Diagnostic> _checkEndpointMethods(
      String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];

    // Check that endpoint methods have Session as first parameter
    final methodRegex = RegExp(r'Future<[^>]+>\s+(\w+)\s*\(([^)]*)\)');
    for (final match in methodRegex.allMatches(content)) {
      final params = match.group(2) ?? '';
      if (!params.trim().startsWith('Session')) {
        diagnostics.add(Diagnostic(
          range: Range(
            start:
                Position(line: _getLineNumber(content, match.start), character: 0),
            end:
                Position(line: _getLineNumber(content, match.start), character: 100),
          ),
          message: 'Endpoint methods should have Session as first parameter',
          severity: DiagnosticSeverity.Warning,
          source: 'serverpod',
          code: 'missing_session_param',
        ));
      }
    }

    return diagnostics;
  }

  List<Diagnostic> _checkSessionUsage(
      String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];

    // Check for deprecated session.db usage (Serverpod 3.0+)
    if (content.contains('session.db.') &&
        !content.contains('session.dbNext')) {
      // This is informational - session.db is still valid but session.dbNext is preferred
    }

    return diagnostics;
  }

  List<Diagnostic> _checkProtocolReferences(
      String content, ResolvedUnitResult result) {
    final diagnostics = <Diagnostic>[];
    // Check protocol references are valid
    return diagnostics;
  }

  String _formatProtocolDoc(dynamic protocol) {
    final buffer = StringBuffer();

    if (protocol is Map) {
      buffer.writeln('### ${protocol['class']}');

      if (protocol.containsKey('table')) {
        buffer.writeln('\nTable: `${protocol['table']}`');
      }

      if (protocol.containsKey('fields')) {
        buffer.writeln('\n**Fields:**');
        final fields = protocol['fields'] as Map?;
        if (fields != null) {
          for (final entry in fields.entries) {
            buffer.writeln('- `${entry.key}`: ${entry.value}');
          }
        }
      }
    }

    return buffer.toString();
  }

  int _getLineNumber(String content, int offset) {
    return content.substring(0, offset).split('\n').length - 1;
  }
}
