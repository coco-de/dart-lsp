import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_lsp/dart_lsp.dart';

/// Logger shorthand
final _log = Logger.instance;

/// MCP Server for Dart LSP Integration with Claude Code
///
/// This server wraps the Dart LSP functionality and exposes it
/// through the Model Context Protocol (MCP) for Claude Code integration.
void main(List<String> args) async {
  final server = DartMcpServer();
  await server.run();
}

/// MCP Server implementation
class DartMcpServer {
  final DartAnalyzerService _analyzerService = DartAnalyzerService();
  final DocumentManager _documentManager = DocumentManager();
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  final List<String> _workspaces = [];

  /// Run the MCP server
  Future<void> run() async {
    _log.info('MCP', 'Starting server...');

    // Read from stdin, write to stdout (MCP protocol)
    stdin.transform(utf8.decoder).transform(const LineSplitter()).listen(
          _handleInput,
          onError: (e) => _log.error('MCP', 'Input error: $e'),
          onDone: () => _log.info('MCP', 'Input closed'),
        );

    // Keep the server running
    await ProcessSignal.sigint.watch().first;
    _log.info('MCP', 'Shutting down...');
  }

  /// Handle incoming JSON-RPC messages
  void _handleInput(String line) async {
    if (line.isEmpty) return;

    try {
      final message = jsonDecode(line) as Map<String, dynamic>;

      if (message.containsKey('method')) {
        // It's a request or notification
        await _handleRequest(message);
      } else if (message.containsKey('result') ||
          message.containsKey('error')) {
        // It's a response
        _handleResponse(message);
      }
    } catch (e, st) {
      _log.error('MCP', 'Parse error: $e', st);
    }
  }

  /// Handle a JSON-RPC request
  Future<void> _handleRequest(Map<String, dynamic> message) async {
    final method = message['method'] as String;
    final id = message['id'];
    final params = message['params'] as Map<String, dynamic>? ?? {};

    try {
      final result = await _dispatch(method, params);

      if (id != null) {
        _sendResponse(id, result);
      }
    } catch (e, st) {
      _log.error('MCP', 'Error handling $method: $e', st);

      if (id != null) {
        _sendError(id, -32603, e.toString());
      }
    }
  }

  /// Handle a JSON-RPC response
  void _handleResponse(Map<String, dynamic> message) {
    final id = message['id']?.toString();
    if (id != null && _pendingRequests.containsKey(id)) {
      final completer = _pendingRequests.remove(id)!;

      if (message.containsKey('error')) {
        completer.completeError(message['error']);
      } else {
        completer.complete(message['result'] as Map<String, dynamic>? ?? {});
      }
    }
  }

  /// Dispatch method calls
  Future<dynamic> _dispatch(String method, Map<String, dynamic> params) async {
    switch (method) {
      // MCP Lifecycle
      case 'initialize':
        return _handleInitialize(params);
      case 'initialized':
        return _handleInitialized(params);
      case 'shutdown':
        return _handleShutdown();

      // MCP Tools
      case 'tools/list':
        return _listTools();
      case 'tools/call':
        return _callTool(params);

      // MCP Resources (for file watching)
      case 'resources/list':
        return _listResources();
      case 'resources/read':
        return _readResource(params);

      default:
        throw Exception('Unknown method: $method');
    }
  }

  /// Handle initialize request
  Future<Map<String, dynamic>> _handleInitialize(
      Map<String, dynamic> params) async {
    // capabilities can be used for future feature negotiation
    // final capabilities = params['capabilities'] as Map<String, dynamic>? ?? {};

    // Extract workspace folders if provided
    if (params.containsKey('workspaceFolders')) {
      final folders = params['workspaceFolders'] as List<dynamic>?;
      if (folders != null) {
        for (final folder in folders) {
          if (folder is Map && folder.containsKey('uri')) {
            final uri = folder['uri'] as String;
            final path = Uri.parse(uri).toFilePath();
            _workspaces.add(path);
            await _analyzerService.addWorkspace(path);
          }
        }
      }
    }

    // Or from rootUri
    if (_workspaces.isEmpty && params.containsKey('rootUri')) {
      final rootUri = params['rootUri'] as String;
      final path = Uri.parse(rootUri).toFilePath();
      _workspaces.add(path);
      await _analyzerService.addWorkspace(path);
    }

    return {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'tools': {
          'listChanged': true,
        },
        'resources': {
          'subscribe': true,
          'listChanged': true,
        },
      },
      'serverInfo': {
        'name': 'dart-lsp-mcp',
        'version': '0.1.0',
      },
    };
  }

  /// Handle initialized notification
  Future<void> _handleInitialized(Map<String, dynamic> params) async {
    // Server is now fully initialized
    _log.info('MCP', 'Server initialized with workspaces: $_workspaces');
  }

  /// Handle shutdown request
  Future<void> _handleShutdown() async {
    await _analyzerService.dispose();
    _log.info('MCP', 'Server shutdown');
  }

  /// List available tools
  Map<String, dynamic> _listTools() {
    return {
      'tools': [
        {
          'name': 'dart_analyze',
          'description':
              'Analyze Dart code and return diagnostics (errors, warnings, hints). '
                  'Use this before writing code to check for issues.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI (file:///path/to/file.dart)',
              },
              'content': {
                'type': 'string',
                'description': 'File content to analyze',
              },
            },
            'required': ['uri', 'content'],
          },
        },
        {
          'name': 'dart_complete',
          'description': 'Get code completions at a specific position. '
              'Returns suggestions for classes, methods, variables, etc.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI',
              },
              'content': {
                'type': 'string',
                'description': 'File content',
              },
              'line': {
                'type': 'integer',
                'description': 'Line number (0-indexed)',
              },
              'character': {
                'type': 'integer',
                'description': 'Character position (0-indexed)',
              },
            },
            'required': ['uri', 'content', 'line', 'character'],
          },
        },
        {
          'name': 'dart_hover',
          'description':
              'Get hover information (documentation, type info) at a position.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI',
              },
              'content': {
                'type': 'string',
                'description': 'File content',
              },
              'line': {
                'type': 'integer',
                'description': 'Line number (0-indexed)',
              },
              'character': {
                'type': 'integer',
                'description': 'Character position (0-indexed)',
              },
            },
            'required': ['uri', 'content', 'line', 'character'],
          },
        },
        {
          'name': 'dart_definition',
          'description': 'Get the definition location of a symbol.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI',
              },
              'content': {
                'type': 'string',
                'description': 'File content',
              },
              'line': {
                'type': 'integer',
                'description': 'Line number (0-indexed)',
              },
              'character': {
                'type': 'integer',
                'description': 'Character position (0-indexed)',
              },
            },
            'required': ['uri', 'content', 'line', 'character'],
          },
        },
        {
          'name': 'dart_format',
          'description':
              'Format Dart code according to the official style guide.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI',
              },
              'content': {
                'type': 'string',
                'description': 'File content to format',
              },
            },
            'required': ['uri', 'content'],
          },
        },
        {
          'name': 'dart_symbols',
          'description':
              'Get document symbols (classes, functions, variables) for outline.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI',
              },
              'content': {
                'type': 'string',
                'description': 'File content',
              },
            },
            'required': ['uri', 'content'],
          },
        },
        {
          'name': 'dart_code_actions',
          'description':
              'Get available code actions (quick fixes, refactorings) for a range.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI',
              },
              'content': {
                'type': 'string',
                'description': 'File content',
              },
              'startLine': {
                'type': 'integer',
                'description': 'Start line (0-indexed)',
              },
              'startCharacter': {
                'type': 'integer',
                'description': 'Start character (0-indexed)',
              },
              'endLine': {
                'type': 'integer',
                'description': 'End line (0-indexed)',
              },
              'endCharacter': {
                'type': 'integer',
                'description': 'End character (0-indexed)',
              },
            },
            'required': [
              'uri',
              'content',
              'startLine',
              'startCharacter',
              'endLine',
              'endCharacter'
            ],
          },
        },
        {
          'name': 'dart_add_workspace',
          'description': 'Add a workspace folder for analysis.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace path',
              },
            },
            'required': ['path'],
          },
        },
        {
          'name': 'dart_pub',
          'description': 'Run pub commands (get, upgrade, outdated, add, remove) '
              'for Dart/Flutter package management.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Project directory path',
              },
              'command': {
                'type': 'string',
                'description':
                    'Pub command to run (get, upgrade, outdated, add, remove)',
                'enum': ['get', 'upgrade', 'outdated', 'add', 'remove'],
              },
              'package': {
                'type': 'string',
                'description':
                    'Package name (required for add/remove commands)',
              },
              'dev': {
                'type': 'boolean',
                'description':
                    'Add as dev dependency (only for add command)',
                'default': false,
              },
            },
            'required': ['path', 'command'],
          },
        },
        {
          'name': 'dart_test',
          'description':
              'Run Dart/Flutter tests. Supports filtering by name, '
                  'file path, and coverage collection.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description':
                    'Project directory or test file path',
              },
              'name': {
                'type': 'string',
                'description':
                    'Test name filter (regex pattern for --name flag)',
              },
              'reporter': {
                'type': 'string',
                'description': 'Test output reporter format',
                'enum': ['json', 'compact', 'expanded'],
                'default': 'json',
              },
              'coverage': {
                'type': 'boolean',
                'description': 'Collect code coverage',
                'default': false,
              },
            },
            'required': ['path'],
          },
        },
        {
          'name': 'dart_flutter_outline',
          'description':
              'Get Flutter widget tree outline from a Dart file. '
                  'Shows hierarchical widget structure for understanding '
                  'and refactoring complex widget trees.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'uri': {
                'type': 'string',
                'description': 'File URI (file:///path/to/file.dart)',
              },
              'content': {
                'type': 'string',
                'description': 'File content to analyze',
              },
            },
            'required': ['uri', 'content'],
          },
        },
        {
          'name': 'dart_logs',
          'description': 'View server logs for debugging and monitoring. '
              'Filter by level, source, time range, or search term.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'level': {
                'type': 'string',
                'description':
                    'Minimum log level (debug, info, warning, error)',
                'default': 'info',
              },
              'source': {
                'type': 'string',
                'description': 'Filter by source (MCP, LSP, DCM, etc.)',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of logs to return',
                'default': 50,
              },
              'since_minutes': {
                'type': 'integer',
                'description': 'Only show logs from the last N minutes',
              },
              'search': {
                'type': 'string',
                'description': 'Search term to filter log messages',
              },
            },
          },
        },
      ],
    };
  }

  /// Call a tool
  Future<Map<String, dynamic>> _callTool(Map<String, dynamic> params) async {
    final name = params['name'] as String;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    switch (name) {
      case 'dart_analyze':
        return _toolAnalyze(arguments);
      case 'dart_complete':
        return _toolComplete(arguments);
      case 'dart_hover':
        return _toolHover(arguments);
      case 'dart_definition':
        return _toolDefinition(arguments);
      case 'dart_format':
        return _toolFormat(arguments);
      case 'dart_symbols':
        return _toolSymbols(arguments);
      case 'dart_code_actions':
        return _toolCodeActions(arguments);
      case 'dart_add_workspace':
        return _toolAddWorkspace(arguments);
      case 'dart_pub':
        return _toolPub(arguments);
      case 'dart_test':
        return _toolTest(arguments);
      case 'dart_flutter_outline':
        return _toolFlutterOutline(arguments);
      case 'dart_logs':
        return _toolLogs(arguments);
      default:
        throw Exception('Unknown tool: $name');
    }
  }

  /// Tool: Analyze code
  Future<Map<String, dynamic>> _toolAnalyze(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;

    _documentManager.openDocument(uri, content);
    final diagnostics = await _analyzerService.analyze(uri, content);

    final result = diagnostics.map((d) {
      // Extract code value from Either<int, String> or use toString
      final codeValue = d.code?.toString();
      return {
        'severity': severityToString(d.severity),
        'message': d.message,
        'range': {
          'start': {
            'line': d.range.start.line,
            'character': d.range.start.character
          },
          'end': {'line': d.range.end.line, 'character': d.range.end.character},
        },
        'code': codeValue,
        'source': d.source,
      };
    }).toList();

    return {
      'content': [
        {
          'type': 'text',
          'text': result.isEmpty
              ? '✅ No issues found'
              : '🔍 Found ${result.length} issue(s):\n\n${formatDiagnostics(result)}',
        },
      ],
      'isError': result.any((d) => d['severity'] == 'error'),
    };
  }

  /// Tool: Get completions
  Future<Map<String, dynamic>> _toolComplete(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;
    final line = args['line'] as int;
    final character = args['character'] as int;

    _documentManager.openDocument(uri, content);
    final completions =
        await _analyzerService.getCompletions(uri, content, line, character);

    final result = completions
        .take(20)
        .map((c) => {
              'label': c.label,
              'kind': completionKindToString(c.kind),
              'detail': c.detail,
              'insertText': c.insertText ?? c.label,
            })
        .toList();

    return {
      'content': [
        {
          'type': 'text',
          'text': result.isEmpty
              ? 'No completions available'
              : '💡 Completions:\n\n${formatCompletions(result)}',
        },
      ],
    };
  }

  /// Tool: Get hover info
  Future<Map<String, dynamic>> _toolHover(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;
    final line = args['line'] as int;
    final character = args['character'] as int;

    _documentManager.openDocument(uri, content);
    final hover =
        await _analyzerService.getHover(uri, content, line, character);

    if (hover == null) {
      return {
        'content': [
          {'type': 'text', 'text': 'No hover information available'},
        ],
      };
    }

    // Extract hover content - contents is Either<List<MarkedString>, MarkupContent>
    final hoverContent = hover.contents.toString();

    return {
      'content': [
        {'type': 'text', 'text': '📖 $hoverContent'},
      ],
    };
  }

  /// Tool: Get definition
  Future<Map<String, dynamic>> _toolDefinition(
      Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;
    final line = args['line'] as int;
    final character = args['character'] as int;

    _documentManager.openDocument(uri, content);
    final definition =
        await _analyzerService.getDefinition(uri, content, line, character);

    if (definition == null) {
      return {
        'content': [
          {'type': 'text', 'text': 'Definition not found'},
        ],
      };
    }

    return {
      'content': [
        {
          'type': 'text',
          'text': '📍 Definition:\n'
              '  File: ${definition.uri}\n'
              '  Line: ${definition.range.start.line + 1}\n'
              '  Column: ${definition.range.start.character + 1}',
        },
      ],
    };
  }

  /// Tool: Format code
  Future<Map<String, dynamic>> _toolFormat(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;

    _documentManager.openDocument(uri, content);
    final edits = await _analyzerService.formatDocument(uri, content);

    if (edits.isEmpty) {
      return {
        'content': [
          {'type': 'text', 'text': '✅ Code is already formatted'},
        ],
      };
    }

    // Apply edits to get formatted content
    String formattedContent = content;
    for (final edit in edits.reversed) {
      final startOffset = getOffset(
          content, edit.range.start.line, edit.range.start.character);
      final endOffset =
          getOffset(content, edit.range.end.line, edit.range.end.character);
      formattedContent = formattedContent.substring(0, startOffset) +
          edit.newText +
          formattedContent.substring(endOffset);
    }

    return {
      'content': [
        {
          'type': 'text',
          'text': '✨ Formatted code:\n\n```dart\n$formattedContent\n```'
        },
      ],
    };
  }

  /// Tool: Get symbols
  Future<Map<String, dynamic>> _toolSymbols(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;

    _documentManager.openDocument(uri, content);
    final symbols = await _analyzerService.getDocumentSymbols(uri, content);

    if (symbols.isEmpty) {
      return {
        'content': [
          {'type': 'text', 'text': 'No symbols found'},
        ],
      };
    }

    return {
      'content': [
        {
          'type': 'text',
          'text': '📋 Document symbols:\n\n${_formatSymbols(symbols, 0)}',
        },
      ],
    };
  }

  /// Tool: Get code actions
  Future<Map<String, dynamic>> _toolCodeActions(
      Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;

    _documentManager.openDocument(uri, content);

    // First analyze to get diagnostics
    final diagnostics = await _analyzerService.analyze(uri, content);

    // Then get code actions
    final range = _createRange(
      args['startLine'] as int,
      args['startCharacter'] as int,
      args['endLine'] as int,
      args['endCharacter'] as int,
    );

    final actions =
        await _analyzerService.getCodeActions(uri, content, range, diagnostics);

    if (actions.isEmpty) {
      return {
        'content': [
          {'type': 'text', 'text': 'No code actions available'},
        ],
      };
    }

    // CodeAction list - extract title from each action
    final result = actions.map((a) {
      // a is Either<Command, CodeAction> - use toString or extract title
      final title = a.toString();
      return {'title': title, 'kind': 'action'};
    }).toList();

    return {
      'content': [
        {
          'type': 'text',
          'text':
              '🔧 Available actions:\n\n${result.map((a) => '- ${a['title']}').join('\n')}',
        },
      ],
    };
  }

  /// Tool: Add workspace
  Future<Map<String, dynamic>> _toolAddWorkspace(
      Map<String, dynamic> args) async {
    final path = args['path'] as String;

    if (!_workspaces.contains(path)) {
      _workspaces.add(path);
      await _analyzerService.addWorkspace(path);
    }

    return {
      'content': [
        {'type': 'text', 'text': '✅ Added workspace: $path'},
      ],
    };
  }

  /// Tool: Get logs
  Map<String, dynamic> _toolLogs(Map<String, dynamic> args) {
    final levelStr = args['level'] as String? ?? 'info';
    final source = args['source'] as String?;
    final limit = args['limit'] as int? ?? 50;
    final sinceMinutes = args['since_minutes'] as int?;
    final search = args['search'] as String?;

    final level = LogLevel.fromString(levelStr);
    final since = sinceMinutes != null ? Duration(minutes: sinceMinutes) : null;

    final entries = _log.store.query(
      minLevel: level,
      source: source,
      limit: limit,
      since: since,
      search: search,
    );

    if (entries.isEmpty) {
      return {
        'content': [
          {'type': 'text', 'text': '📋 No logs found matching criteria'},
        ],
      };
    }

    return {
      'content': [
        {
          'type': 'text',
          'text': '📋 Logs (${entries.length} entries):\n\n'
              '${_formatLogs(entries)}',
        },
      ],
    };
  }

  /// Tool: Run pub commands
  Future<Map<String, dynamic>> _toolPub(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final command = args['command'] as String;
    final package = args['package'] as String?;
    final dev = args['dev'] as bool? ?? false;

    final projectRoot = findProjectRoot(path);
    if (projectRoot == null) {
      return {
        'content': [
          {'type': 'text', 'text': '❌ No pubspec.yaml found in $path'},
        ],
        'isError': true,
      };
    }

    // Validate package is provided for add/remove
    if ((command == 'add' || command == 'remove') &&
        (package == null || package.isEmpty)) {
      return {
        'content': [
          {
            'type': 'text',
            'text': '❌ Package name is required for pub $command',
          },
        ],
        'isError': true,
      };
    }

    final pubArgs = ['pub', command];
    if (command == 'add') {
      if (dev) pubArgs.add('--dev');
      pubArgs.add(package!);
    } else if (command == 'remove') {
      pubArgs.add(package!);
    }

    try {
      final result = await _runProjectCommand(projectRoot, pubArgs);
      final output = StringBuffer();
      if ((result.stdout as String).isNotEmpty) {
        output.writeln(result.stdout);
      }
      if ((result.stderr as String).isNotEmpty) {
        output.writeln(result.stderr);
      }

      final isError = result.exitCode != 0;
      final icon = isError ? '❌' : '✅';
      return {
        'content': [
          {
            'type': 'text',
            'text': '$icon pub $command (exit code: ${result.exitCode})\n\n'
                '${output.toString().trim()}',
          },
        ],
        'isError': isError,
      };
    } on TimeoutException catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': '❌ ${e.message}'},
        ],
        'isError': true,
      };
    }
  }

  /// Tool: Run tests
  Future<Map<String, dynamic>> _toolTest(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final name = args['name'] as String?;
    final reporter = args['reporter'] as String? ?? 'json';
    final coverage = args['coverage'] as bool? ?? false;

    // Determine project root and optional test file
    String? projectRoot;
    String? testFile;
    if (FileSystemEntity.isFileSync(path)) {
      testFile = path;
      projectRoot = findProjectRoot(path);
    } else {
      projectRoot = findProjectRoot(path) ?? path;
    }

    if (projectRoot == null) {
      return {
        'content': [
          {'type': 'text', 'text': '❌ No pubspec.yaml found for $path'},
        ],
        'isError': true,
      };
    }

    final testArgs = ['test', '--reporter', reporter];
    if (name != null && name.isNotEmpty) {
      testArgs.addAll(['--name', name]);
    }
    if (coverage) {
      testArgs.add('--coverage');
    }
    if (testFile != null) {
      testArgs.add(testFile);
    }

    try {
      final result = await _runProjectCommand(
        projectRoot,
        testArgs,
        timeout: const Duration(minutes: 10),
      );

      final stdout = result.stdout as String;
      final stderr = result.stderr as String;

      if (reporter == 'json') {
        final summary = parseJsonTestResults(stdout);
        final isError =
            result.exitCode != 0 || summary.containsKey('failures');
        return {
          'content': [
            {
              'type': 'text',
              'text': summary['formatted'] as String? ??
                  '${stdout.trim()}\n${stderr.trim()}'.trim(),
            },
          ],
          'isError': isError,
        };
      }

      // compact/expanded: return raw output
      final output = StringBuffer();
      if (stdout.isNotEmpty) output.writeln(stdout);
      if (stderr.isNotEmpty) output.writeln(stderr);

      return {
        'content': [
          {
            'type': 'text',
            'text':
                '🧪 Test results (exit code: ${result.exitCode})\n\n${output.toString().trim()}',
          },
        ],
        'isError': result.exitCode != 0,
      };
    } on TimeoutException catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': '❌ ${e.message}'},
        ],
        'isError': true,
      };
    }
  }

  /// Tool: Flutter widget outline
  Future<Map<String, dynamic>> _toolFlutterOutline(
      Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;

    _documentManager.openDocument(uri, content);
    final widgets = await _analyzerService.getFlutterOutline(uri, content);

    if (widgets.isEmpty) {
      return {
        'content': [
          {
            'type': 'text',
            'text': 'No widget tree found. '
                'Ensure the file contains Flutter widget code with build() methods.',
          },
        ],
      };
    }

    final tree = formatWidgetTree(widgets, 0);
    return {
      'content': [
        {
          'type': 'text',
          'text': '🌳 Widget Tree:\n\n$tree',
        },
      ],
    };
  }

  /// Format log entries for display
  String _formatLogs(List<LogEntry> entries) {
    return entries.map((e) => e.format()).join('\n');
  }

  /// List resources (for file watching)
  Map<String, dynamic> _listResources() {
    return {
      'resources': _workspaces
          .map((w) => {
                'uri': 'file://$w',
                'name': w.split('/').last,
                'mimeType': 'application/x-directory',
              })
          .toList(),
    };
  }

  /// Read a resource
  Future<Map<String, dynamic>> _readResource(
      Map<String, dynamic> params) async {
    final uri = params['uri'] as String;
    final path = Uri.parse(uri).toFilePath();

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    final content = await file.readAsString();

    return {
      'contents': [
        {
          'uri': uri,
          'mimeType': 'text/x-dart',
          'text': content,
        },
      ],
    };
  }

  // Helper methods

  void _sendResponse(dynamic id, dynamic result) {
    final response = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    });
    stdout.writeln(response);
  }

  void _sendError(dynamic id, int code, String message) {
    final response = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
      },
    });
    stdout.writeln(response);
  }

  // Reserved for future use - sending notifications to client
  // void _sendNotification(String method, Map<String, dynamic> params) {
  //   final notification = jsonEncode({
  //     'jsonrpc': '2.0',
  //     'method': method,
  //     'params': params,
  //   });
  //   stdout.writeln(notification);
  // }

  // ignore: avoid_dynamic_calls - DocumentSymbol from LSP uses dynamic properties
  String _formatSymbols(List<dynamic> symbols, int indent) {
    final prefix = '  ' * indent;
    return symbols.map((s) {
      // DocumentSymbol properties accessed dynamically
      // ignore: avoid_dynamic_calls
      final String name = (s as dynamic).name as String;
      // ignore: avoid_dynamic_calls
      final String kind = (s as dynamic).kind.toString().split('.').last;
      // ignore: avoid_dynamic_calls
      final List<dynamic> children =
          ((s as dynamic).children as List<dynamic>?) ?? [];

      var result = '$prefix• $name ($kind)';
      if (children.isNotEmpty) {
        result += '\n${_formatSymbols(children, indent + 1)}';
      }
      return result;
    }).join('\n');
  }

  dynamic _createRange(int startLine, int startChar, int endLine, int endChar) {
    // This would need to import lsp_server types
    // For now, returning a map that can be converted
    return _Range(startLine, startChar, endLine, endChar);
  }

  /// Run dart or flutter command depending on project type
  Future<ProcessResult> _runProjectCommand(
    String projectPath,
    List<String> args, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final isFlutter = isFlutterProject(projectPath);
    final executable = isFlutter ? 'flutter' : 'dart';
    _log.info('MCP', 'Running: $executable ${args.join(' ')} in $projectPath');
    return Process.run(
      executable,
      args,
      workingDirectory: projectPath,
    ).timeout(timeout, onTimeout: () {
      throw TimeoutException(
          '$executable ${args.first} timed out after ${timeout.inMinutes} minutes');
    });
  }
}

/// Simple Range class for internal use
class _Range {
  _Range(int startLine, int startChar, int endLine, int endChar)
      : start = _Position(startLine, startChar),
        end = _Position(endLine, endChar);

  final _Position start;
  final _Position end;
}

class _Position {
  _Position(this.line, this.character);

  final int line;
  final int character;
}
