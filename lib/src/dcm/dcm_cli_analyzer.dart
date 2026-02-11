import 'dart:convert';
import 'dart:io';

import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as path;

import '../logger.dart';

/// Issue from DCM CLI JSON output
class DcmCliIssue {
  const DcmCliIssue({
    required this.id,
    required this.message,
    required this.severity,
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
    this.documentation,
  });

  final String id;
  final String message;
  final String severity;
  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;
  final String? documentation;
}

/// Parsed result for a single file from DCM CLI
class DcmCliResult {
  const DcmCliResult({
    required this.path,
    required this.issues,
  });

  final String path;
  final List<DcmCliIssue> issues;
}

/// Analyzer that wraps the DCM CLI binary for real DCM analysis.
///
/// Falls back gracefully when DCM is not installed.
class DcmCliAnalyzer {
  String? _dcmPath;
  bool _isAvailable = false;

  /// Whether DCM CLI is available on the system
  bool get isAvailable => _isAvailable;

  /// Workspace-level cache: {workspacePath: {filePath: List<DcmCliIssue>}}
  final Map<String, Map<String, List<DcmCliIssue>>> _cache = {};

  /// Initialize by finding the DCM binary
  Future<void> initialize() async {
    _dcmPath = await _findDcmBinary();
    _isAvailable = _dcmPath != null;

    if (_isAvailable) {
      Logger.instance.info('DCM-CLI', 'Found DCM binary at: $_dcmPath');
    } else {
      Logger.instance.info(
        'DCM-CLI',
        'DCM binary not found, will use custom DCM fallback',
      );
    }
  }

  /// Find DCM binary on the system
  Future<String?> _findDcmBinary() async {
    // 1. Try `which dcm`
    try {
      final result = Process.runSync('which', ['dcm']);
      if (result.exitCode == 0) {
        final dcmPath = (result.stdout as String).trim();
        if (dcmPath.isNotEmpty && File(dcmPath).existsSync()) {
          return dcmPath;
        }
      }
    } catch (_) {}

    // 2. Try DCM_PATH environment variable
    final envPath = Platform.environment['DCM_PATH'];
    if (envPath != null && File(envPath).existsSync()) {
      return envPath;
    }

    // 3. Try common installation paths
    final home = Platform.environment['HOME'] ?? '';
    final commonPaths = [
      '/opt/homebrew/bin/dcm', // Homebrew ARM
      '/usr/local/bin/dcm', // Homebrew Intel
      '$home/.pub-cache/bin/dcm', // dart pub global activate
    ];

    for (final p in commonPaths) {
      if (File(p).existsSync()) {
        return p;
      }
    }

    return null;
  }

  /// Analyze an entire workspace with DCM CLI and cache results by file
  Future<void> analyzeWorkspace(String workspacePath) async {
    if (!_isAvailable || _dcmPath == null) return;

    Logger.instance.info('DCM-CLI', 'Analyzing workspace: $workspacePath');

    try {
      final result = await Process.run(
        _dcmPath!,
        [
          'analyze',
          '--reporter=json',
          '--root-folder=$workspacePath',
          workspacePath,
        ],
        workingDirectory: workspacePath,
      );

      // DCM exits with non-zero when issues are found, so check both
      final output = result.stdout as String;
      final stderr = result.stderr as String;

      if (output.isEmpty) {
        if (stderr.isNotEmpty) {
          Logger.instance.warn('DCM-CLI', 'DCM stderr: $stderr');
        }
        _cache[workspacePath] = {};
        Logger.instance.info('DCM-CLI', 'No output from DCM CLI');
        return;
      }

      final results = _parseDcmOutput(output);
      final fileCache = <String, List<DcmCliIssue>>{};

      var totalIssues = 0;
      for (final fileResult in results) {
        // Normalize path: DCM may output relative or absolute paths
        final filePath = path.isAbsolute(fileResult.path)
            ? fileResult.path
            : path.join(workspacePath, fileResult.path);
        final normalized = path.normalize(filePath);
        fileCache[normalized] = fileResult.issues;
        totalIssues += fileResult.issues.length;
      }

      _cache[workspacePath] = fileCache;
      Logger.instance.info(
        'DCM-CLI',
        'Found $totalIssues issues in ${results.length} files',
      );
    } catch (e, st) {
      Logger.instance.error('DCM-CLI', 'Failed to run DCM CLI: $e', st);
      _cache[workspacePath] = {};
    }
  }

  /// Get cached DCM diagnostics for a specific file as LSP Diagnostics
  List<Diagnostic> getDiagnostics(String workspacePath, String filePath) {
    final fileCache = _cache[workspacePath];
    if (fileCache == null) return [];

    final normalized = path.normalize(filePath);
    final issues = fileCache[normalized];
    if (issues == null || issues.isEmpty) return [];

    return issues.map((issue) {
      return Diagnostic(
        range: Range(
          start: Position(
            line: issue.startLine - 1, // DCM is 1-based, LSP is 0-based
            character: issue.startColumn - 1,
          ),
          end: Position(
            line: issue.endLine - 1,
            character: issue.endColumn - 1,
          ),
        ),
        message: issue.message,
        severity: _mapSeverity(issue.severity),
        source: 'dcm',
        code: issue.id,
        codeDescription: issue.documentation != null
            ? CodeDescription(href: Uri.parse(issue.documentation!))
            : null,
      );
    }).toList();
  }

  /// Parse DCM JSON output into structured results
  List<DcmCliResult> _parseDcmOutput(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final analyzeResults = json['analyzeResults'] as List<dynamic>?;
      if (analyzeResults == null) return [];

      return analyzeResults.map((entry) {
        final fileEntry = entry as Map<String, dynamic>;
        final filePath = fileEntry['path'] as String;
        final issuesList = fileEntry['issues'] as List<dynamic>? ?? [];

        final issues = issuesList.map((issueJson) {
          final issue = issueJson as Map<String, dynamic>;
          final location = issue['location'] as Map<String, dynamic>;

          return DcmCliIssue(
            id: issue['id'] as String,
            message: issue['message'] as String,
            severity: issue['severity'] as String? ?? 'warning',
            startLine: location['startLine'] as int,
            startColumn: location['startColumn'] as int,
            endLine: location['endLine'] as int? ?? location['startLine'] as int,
            endColumn:
                location['endColumn'] as int? ?? location['startColumn'] as int,
            documentation: issue['documentation'] as String?,
          );
        }).toList();

        return DcmCliResult(path: filePath, issues: issues);
      }).toList();
    } catch (e) {
      Logger.instance.error('DCM-CLI', 'Failed to parse DCM JSON output: $e');
      return [];
    }
  }

  /// Map DCM severity string to LSP DiagnosticSeverity
  DiagnosticSeverity _mapSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'error':
        return DiagnosticSeverity.Error;
      case 'warning':
        return DiagnosticSeverity.Warning;
      case 'style':
      case 'performance':
        return DiagnosticSeverity.Information;
      default:
        return DiagnosticSeverity.Warning;
    }
  }

  /// Clear cached results for a workspace
  void clearCache(String workspacePath) {
    _cache.remove(workspacePath);
  }
}
