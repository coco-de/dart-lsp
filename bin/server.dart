import 'dart:io';
import 'package:lsp_server/lsp_server.dart';
import 'package:dart_lsp/dart_lsp.dart';

/// Dart LSP for Claude Code
///
/// Provides enhanced Dart analysis with Serverpod, Jaspr, and Flutter support.
void main(List<String> args) async {
  // Create a connection using stdio
  final connection = Connection(stdin, stdout);

  // Initialize the Dart analyzer service
  final analyzerService = DartAnalyzerService();

  // Document manager for tracking open files
  final documentManager = DocumentManager();

  // Handle initialization
  connection.onInitialize((params) async {
    // Initialize analyzer with workspace folders
    try {
      if (params.workspaceFolders != null) {
        for (final folder in params.workspaceFolders!) {
          await analyzerService
              .addWorkspace(Uri.parse(folder.uri.toString()).toFilePath());
        }
      } else if (params.rootUri != null) {
        await analyzerService
            .addWorkspace(Uri.parse(params.rootUri.toString()).toFilePath());
      }
    } catch (e) {
      stderr.writeln('[Dart LSP] Workspace initialization error: $e');
    }

    return InitializeResult(
      capabilities: ServerCapabilities(
        // Document sync - Full sync mode
        textDocumentSync: const Either2.t1(TextDocumentSyncKind.Full),

        // Completion support
        completionProvider: CompletionOptions(
          triggerCharacters: ['.', ':', '@', '/', '<'],
          resolveProvider: true,
        ),

        // Hover support
        hoverProvider: const Either2.t1(true),

        // Go to definition
        definitionProvider: const Either2.t1(true),

        // Find references
        referencesProvider: const Either2.t1(true),

        // Document symbols (outline)
        documentSymbolProvider: const Either2.t1(true),

        // Code actions (quick fixes, refactoring)
        codeActionProvider: Either2.t2(CodeActionOptions(
          codeActionKinds: [
            CodeActionKind.QuickFix,
            CodeActionKind.Refactor,
            CodeActionKind.RefactorExtract,
            CodeActionKind.RefactorInline,
            CodeActionKind.Source,
            CodeActionKind.SourceOrganizeImports,
          ],
        )),

        // Document formatting
        documentFormattingProvider: const Either2.t1(true),

        // Semantic tokens for syntax highlighting
        semanticTokensProvider: Either2.t1(SemanticTokensOptions(
          legend: SemanticTokensLegend(
            tokenTypes: [
              'namespace',
              'type',
              'class',
              'enum',
              'interface',
              'struct',
              'typeParameter',
              'parameter',
              'variable',
              'property',
              'enumMember',
              'event',
              'function',
              'method',
              'macro',
              'keyword',
              'modifier',
              'comment',
              'string',
              'number',
              'regexp',
              'operator',
              'decorator',
            ],
            tokenModifiers: [
              'declaration',
              'definition',
              'readonly',
              'static',
              'deprecated',
              'abstract',
              'async',
              'modification',
              'documentation',
              'defaultLibrary',
            ],
          ),
          full: const Either2.t1(true),
          range: const Either2.t1(true),
        )),

        // Rename support
        renameProvider: Either2.t2(RenameOptions(prepareProvider: true)),
      ),
      serverInfo: InitializeResultServerInfo(
        name: 'Dart LSP Server for Claude Code',
        version: '0.1.0',
      ),
    );
  });

  // Handle initialized notification
  connection.onInitialized((params) async {
    // Server is now initialized
    stderr.writeln('[Dart LSP] Server initialized');
  });

  // Handle document open
  connection.onDidOpenTextDocument((params) async {
    final uri = params.textDocument.uri.toString();
    final content = params.textDocument.text;

    documentManager.openDocument(uri, content);

    // Analyze and send diagnostics
    final diagnostics = await analyzerService.analyze(uri, content);
    connection.sendDiagnostics(PublishDiagnosticsParams(
      uri: params.textDocument.uri,
      diagnostics: diagnostics,
    ));
  });

  // Handle document change
  connection.onDidChangeTextDocument((params) async {
    final uri = params.textDocument.uri.toString();
    final changes = params.contentChanges;

    if (changes.isNotEmpty) {
      final content = changes.first.map(
        (full) => full.text,
        (incremental) => documentManager.getDocument(uri) ?? '',
      );

      documentManager.updateDocument(uri, content);

      // Re-analyze and send diagnostics
      final diagnostics = await analyzerService.analyze(uri, content);
      connection.sendDiagnostics(PublishDiagnosticsParams(
        uri: params.textDocument.uri,
        diagnostics: diagnostics,
      ));
    }
  });

  // Handle document close
  connection.onDidCloseTextDocument((params) async {
    documentManager.closeDocument(params.textDocument.uri.toString());
  });

  // Handle document save
  connection.onDidSaveTextDocument((params) async {
    final uri = params.textDocument.uri.toString();
    final content = documentManager.getDocument(uri);

    if (content != null) {
      final diagnostics = await analyzerService.analyze(uri, content);
      connection.sendDiagnostics(PublishDiagnosticsParams(
        uri: params.textDocument.uri,
        diagnostics: diagnostics,
      ));
    }
  });

  // Handle completion request
  connection.onCompletion((params) async {
    final uri = params.textDocument.uri.toString();
    final position = params.position;
    final content = documentManager.getDocument(uri);

    if (content == null) return CompletionList(isIncomplete: false, items: []);

    final completions = await analyzerService.getCompletions(
      uri,
      content,
      position.line,
      position.character,
    );

    return CompletionList(isIncomplete: false, items: completions);
  });

  // Handle hover request
  connection.onHover((params) async {
    final uri = params.textDocument.uri.toString();
    final position = params.position;
    final content = documentManager.getDocument(uri);

    if (content == null) {
      return Hover(contents: const Either2.t2(''));
    }

    final hover = await analyzerService.getHover(
      uri,
      content,
      position.line,
      position.character,
    );

    return hover ?? Hover(contents: const Either2.t2(''));
  });

  // Handle go to definition
  connection.onDefinition((params) async {
    final uri = params.textDocument.uri.toString();
    final position = params.position;
    final content = documentManager.getDocument(uri);

    if (content == null) return Either3.t2(<Location>[]);

    final definition = await analyzerService.getDefinition(
      uri,
      content,
      position.line,
      position.character,
    );

    if (definition != null) {
      return Either3.t2([definition]);
    }

    return Either3.t2(<Location>[]);
  });

  // Handle find references
  connection.onReferences((params) async {
    final uri = params.textDocument.uri.toString();
    final position = params.position;
    final content = documentManager.getDocument(uri);

    if (content == null) return [];

    return analyzerService.getReferences(
      uri,
      content,
      position.line,
      position.character,
    );
  });

  // Handle document symbols
  connection.onDocumentSymbol((params) async {
    final uri = params.textDocument.uri.toString();
    final content = documentManager.getDocument(uri);

    if (content == null) return [];

    final symbols = await analyzerService.getDocumentSymbols(uri, content);

    // Convert DocumentSymbol list to SymbolInformation list for compatibility
    return _convertToSymbolInformation(symbols, uri);
  });

  // Handle code actions
  connection.onCodeAction((params) async {
    final uri = params.textDocument.uri.toString();
    final range = params.range;
    final diagnostics = params.context.diagnostics;
    final content = documentManager.getDocument(uri);

    if (content == null) return [];

    final actions = await analyzerService.getCodeActions(
      uri,
      content,
      range,
      diagnostics,
    );

    return actions;
  });

  // Handle document formatting
  connection.onDocumentFormatting((params) async {
    final uri = params.textDocument.uri.toString();
    final content = documentManager.getDocument(uri);

    if (content == null) return [];

    return analyzerService.formatDocument(uri, content);
  });

  // Handle prepare rename
  connection.onPrepareRename((params) async {
    final uri = params.textDocument.uri.toString();
    final position = params.position;
    final content = documentManager.getDocument(uri);

    if (content == null) {
      return Either2.t1(Range(
        start: Position(line: 0, character: 0),
        end: Position(line: 0, character: 0),
      ));
    }

    final result = await analyzerService.prepareRename(
      uri,
      content,
      position.line,
      position.character,
    );

    return result ??
        Either2.t1(Range(
          start: Position(line: 0, character: 0),
          end: Position(line: 0, character: 0),
        ));
  });

  // Handle shutdown
  connection.onShutdown(() async {
    await analyzerService.dispose();
    return null;
  });

  // Handle exit
  connection.onExit(() async {
    exit(0);
  });

  // Start listening
  stderr.writeln('[Dart LSP] Starting server...');
  await connection.listen();
}

/// Convert DocumentSymbol list to SymbolInformation list
List<SymbolInformation> _convertToSymbolInformation(
  List<DocumentSymbol> symbols,
  String uri,
) {
  final result = <SymbolInformation>[];
  final docUri = Uri.parse(uri);

  void processSymbol(DocumentSymbol symbol, String? containerName) {
    result.add(SymbolInformation(
      name: symbol.name,
      kind: symbol.kind,
      location: Location(
        uri: docUri,
        range: symbol.range,
      ),
      containerName: containerName,
    ));

    // Process children recursively
    if (symbol.children != null) {
      for (final child in symbol.children!) {
        processSymbol(child, symbol.name);
      }
    }
  }

  for (final symbol in symbols) {
    processSymbol(symbol, null);
  }

  return result;
}
