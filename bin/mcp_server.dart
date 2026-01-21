import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_lsp/dart_lsp.dart';

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
    stderr.writeln('[Dart MCP] Starting server...');
    
    // Read from stdin, write to stdout (MCP protocol)
    stdin.transform(utf8.decoder).transform(const LineSplitter()).listen(
      _handleInput,
      onError: (e) => stderr.writeln('[Dart MCP] Input error: $e'),
      onDone: () => stderr.writeln('[Dart MCP] Input closed'),
    );
    
    // Keep the server running
    await ProcessSignal.sigint.watch().first;
    stderr.writeln('[Dart MCP] Shutting down...');
  }
  
  /// Handle incoming JSON-RPC messages
  void _handleInput(String line) async {
    if (line.isEmpty) return;
    
    try {
      final message = jsonDecode(line) as Map<String, dynamic>;
      
      if (message.containsKey('method')) {
        // It's a request or notification
        await _handleRequest(message);
      } else if (message.containsKey('result') || message.containsKey('error')) {
        // It's a response
        _handleResponse(message);
      }
    } catch (e, st) {
      stderr.writeln('[Dart MCP] Parse error: $e\n$st');
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
      stderr.writeln('[Dart MCP] Error handling $method: $e\n$st');
      
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
  Future<Map<String, dynamic>> _handleInitialize(Map<String, dynamic> params) async {
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
    stderr.writeln('[Dart MCP] Server initialized with workspaces: $_workspaces');
  }
  
  /// Handle shutdown request
  Future<void> _handleShutdown() async {
    await _analyzerService.dispose();
    stderr.writeln('[Dart MCP] Server shutdown');
  }
  
  /// List available tools
  Map<String, dynamic> _listTools() {
    return {
      'tools': [
        {
          'name': 'dart_analyze',
          'description': 'Analyze Dart code and return diagnostics (errors, warnings, hints). '
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
          'description': 'Get hover information (documentation, type info) at a position.',
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
          'description': 'Format Dart code according to the official style guide.',
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
          'description': 'Get document symbols (classes, functions, variables) for outline.',
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
          'description': 'Get available code actions (quick fixes, refactorings) for a range.',
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
            'required': ['uri', 'content', 'startLine', 'startCharacter', 'endLine', 'endCharacter'],
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
        'severity': _severityToString(d.severity),
        'message': d.message,
        'range': {
          'start': {'line': d.range.start.line, 'character': d.range.start.character},
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
              : '🔍 Found ${result.length} issue(s):\n\n${_formatDiagnostics(result)}',
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
    final completions = await _analyzerService.getCompletions(uri, content, line, character);
    
    final result = completions.take(20).map((c) => {
      'label': c.label,
      'kind': _completionKindToString(c.kind),
      'detail': c.detail,
      'insertText': c.insertText ?? c.label,
    }).toList();
    
    return {
      'content': [
        {
          'type': 'text',
          'text': result.isEmpty
              ? 'No completions available'
              : '💡 Completions:\n\n${_formatCompletions(result)}',
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
    final hover = await _analyzerService.getHover(uri, content, line, character);
    
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
  Future<Map<String, dynamic>> _toolDefinition(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final content = args['content'] as String;
    final line = args['line'] as int;
    final character = args['character'] as int;
    
    _documentManager.openDocument(uri, content);
    final definition = await _analyzerService.getDefinition(uri, content, line, character);
    
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
      final startOffset = _getOffset(content, edit.range.start.line, edit.range.start.character);
      final endOffset = _getOffset(content, edit.range.end.line, edit.range.end.character);
      formattedContent = formattedContent.substring(0, startOffset) +
          edit.newText +
          formattedContent.substring(endOffset);
    }
    
    return {
      'content': [
        {'type': 'text', 'text': '✨ Formatted code:\n\n```dart\n$formattedContent\n```'},
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
  Future<Map<String, dynamic>> _toolCodeActions(Map<String, dynamic> args) async {
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
    
    final actions = await _analyzerService.getCodeActions(uri, content, range, diagnostics);
    
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
          'text': '🔧 Available actions:\n\n${result.map((a) => '- ${a['title']}').join('\n')}',
        },
      ],
    };
  }
  
  /// Tool: Add workspace
  Future<Map<String, dynamic>> _toolAddWorkspace(Map<String, dynamic> args) async {
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
  
  /// List resources (for file watching)
  Map<String, dynamic> _listResources() {
    return {
      'resources': _workspaces.map((w) => {
        'uri': 'file://$w',
        'name': w.split('/').last,
        'mimeType': 'application/x-directory',
      }).toList(),
    };
  }
  
  /// Read a resource
  Future<Map<String, dynamic>> _readResource(Map<String, dynamic> params) async {
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
  
  String _severityToString(dynamic severity) {
    final name = severity.toString().toLowerCase();
    if (name.contains('error')) return 'error';
    if (name.contains('warning')) return 'warning';
    if (name.contains('info')) return 'info';
    return 'hint';
  }
  
  String _completionKindToString(dynamic kind) {
    if (kind == null) return 'text';
    final name = kind.toString().toLowerCase();
    if (name.contains('class')) return 'class';
    if (name.contains('function') || name.contains('method')) return 'function';
    if (name.contains('variable') || name.contains('field')) return 'variable';
    if (name.contains('property')) return 'property';
    if (name.contains('snippet')) return 'snippet';
    return 'text';
  }
  
  String _formatDiagnostics(List<Map<String, dynamic>> diagnostics) {
    return diagnostics.map((d) {
      final severity = d['severity'] as String?;
      final icon = severity == 'error' ? '❌' : (severity == 'warning' ? '⚠️' : 'ℹ️');
      final range = d['range'] as Map<String, dynamic>;
      final start = range['start'] as Map<String, dynamic>;
      final line = (start['line'] as int) + 1;
      final col = (start['character'] as int) + 1;
      return '$icon Line $line:$col - ${d['message']}';
    }).join('\n');
  }
  
  String _formatCompletions(List<Map<String, dynamic>> completions) {
    return completions.map((c) {
      final kind = c['kind'];
      final icon = kind == 'class' ? '📦' : 
                   kind == 'function' ? '🔹' :
                   kind == 'variable' ? '📎' :
                   kind == 'property' ? '🔸' : '•';
      return '$icon ${c['label']}${c['detail'] != null ? ' - ${c['detail']}' : ''}';
    }).join('\n');
  }
  
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
  
  int _getOffset(String content, int line, int character) {
    final lines = content.split('\n');
    var offset = 0;
    for (var i = 0; i < line && i < lines.length; i++) {
      offset += lines[i].length + 1; // +1 for newline
    }
    final result = offset + character;
    // Clamp to content length to avoid RangeError
    return result > content.length ? content.length : result;
  }
  
  dynamic _createRange(int startLine, int startChar, int endLine, int endChar) {
    // This would need to import lsp_server types
    // For now, returning a map that can be converted
    return _Range(startLine, startChar, endLine, endChar);
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
