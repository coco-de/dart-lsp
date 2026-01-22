import 'dart:io';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'dcm_rule.dart';
import 'rules/common_rules.dart';
import 'rules/flutter_rules.dart';
import 'rules/bloc_rules.dart';
import 'rules/provider_rules.dart';
import 'rules/riverpod_rules.dart';
import 'rules/equatable_rules.dart';
import 'rules/intl_rules.dart';
import 'rules/pub_rules.dart';
import 'rules/firebase_rules.dart';
import 'rules/get_it_rules.dart';
import 'rules/fake_async_rules.dart';

/// DCM (Dart Code Metrics) analyzer for code quality rules
class DcmAnalyzer {
  final List<DcmRule> _rules = [];
  DcmConfig _config = DcmConfig.recommended();
  bool _isInitialized = false;

  /// Cache of issues per file for code actions
  final Map<String, List<DcmIssue>> _issueCache = {};

  /// Cache of line info per file for code actions
  final Map<String, LineInfo> _lineInfoCache = {};

  /// Get all available rules
  List<DcmRule> get rules => List.unmodifiable(_rules);

  /// Get current configuration
  DcmConfig get config => _config;

  /// Initialize the DCM analyzer for a workspace
  Future<void> initialize(String workspacePath) async {
    if (_isInitialized) return;

    // Register all rules
    _rules.addAll(getCommonRules());
    _rules.addAll(getFlutterRules());
    _rules.addAll(getBlocRules());
    _rules.addAll(getProviderRules());
    _rules.addAll(getRiverpodRules());
    _rules.addAll(getEquatableRules());
    _rules.addAll(getIntlRules());
    _rules.addAll(getPubRules());
    _rules.addAll(getFirebaseRules());
    _rules.addAll(getGetItRules());
    _rules.addAll(getFakeAsyncRules());

    // Load configuration from analysis_options.yaml or dcm.yaml
    await _loadConfig(workspacePath);

    _isInitialized = true;
    stderr.writeln('[DCM] Initialized with ${_rules.length} rules');
  }

  /// Load DCM configuration from project files
  Future<void> _loadConfig(String workspacePath) async {
    // Try dcm.yaml first
    final dcmYamlFile = File(path.join(workspacePath, 'dcm.yaml'));
    if (await dcmYamlFile.exists()) {
      await _loadDcmYaml(dcmYamlFile);
      return;
    }

    // Try analysis_options.yaml
    final analysisOptionsFile =
        File(path.join(workspacePath, 'analysis_options.yaml'));
    if (await analysisOptionsFile.exists()) {
      await _loadAnalysisOptions(analysisOptionsFile);
    }
  }

  Future<void> _loadDcmYaml(File file) async {
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return;

      _config = _parseConfig(yaml);
      stderr.writeln('[DCM] Loaded configuration from dcm.yaml');
    } catch (e) {
      stderr.writeln('[DCM] Error loading dcm.yaml: $e');
    }
  }

  Future<void> _loadAnalysisOptions(File file) async {
    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return;

      // Check for dart_code_metrics or dcm section
      final dcmSection =
          yaml['dart_code_metrics'] as YamlMap? ?? yaml['dcm'] as YamlMap?;
      if (dcmSection != null) {
        _config = _parseConfig(dcmSection);
        stderr.writeln('[DCM] Loaded configuration from analysis_options.yaml');
      }
    } catch (e) {
      stderr.writeln('[DCM] Error loading analysis_options.yaml: $e');
    }
  }

  DcmConfig _parseConfig(YamlMap yaml) {
    final enabledRules = <String>{};
    final disabledRules = <String>{};
    final ruleConfigs = <String, Map<String, dynamic>>{};
    final severityOverrides = <String, DiagnosticSeverity>{};

    // Parse rules section
    final rulesSection = yaml['rules'] as YamlMap?;
    if (rulesSection != null) {
      for (final entry in rulesSection.entries) {
        final ruleId = entry.key as String;
        final value = entry.value;

        if (value == true) {
          enabledRules.add(ruleId);
        } else if (value == false) {
          disabledRules.add(ruleId);
        } else if (value is YamlMap) {
          enabledRules.add(ruleId);
          ruleConfigs[ruleId] = Map<String, dynamic>.from(value);

          // Parse severity if present
          final severity = value['severity'] as String?;
          if (severity != null) {
            severityOverrides[ruleId] = _parseSeverity(severity);
          }
        }
      }
    }

    // Parse extends (presets)
    final extends_ = yaml['extends'] as YamlList?;
    if (extends_ != null) {
      for (final preset in extends_) {
        if (preset == 'recommended') {
          // Add all recommended rules
          enabledRules.addAll(DcmConfig.recommended().enabledRules);
        }
      }
    }

    return DcmConfig(
      enabledRules: enabledRules,
      disabledRules: disabledRules,
      ruleConfigs: ruleConfigs,
      severityOverrides: severityOverrides,
    );
  }

  DiagnosticSeverity _parseSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'error':
        return DiagnosticSeverity.Error;
      case 'warning':
        return DiagnosticSeverity.Warning;
      case 'info':
      case 'information':
        return DiagnosticSeverity.Information;
      case 'hint':
        return DiagnosticSeverity.Hint;
      default:
        return DiagnosticSeverity.Information;
    }
  }

  /// Analyze a file and return diagnostics
  Future<List<Diagnostic>> analyze(
    String filePath,
    String content,
    ResolvedUnitResult result,
  ) async {
    final diagnostics = <Diagnostic>[];
    final allIssues = <DcmIssue>[];

    if (!_isInitialized) return diagnostics;

    // Cache line info for later use in code actions
    _lineInfoCache[filePath] = result.lineInfo;

    // Pre-analyze content for package detection
    final packageContext = _detectPackageContext(content);

    for (final rule in _rules) {
      // Check if rule is enabled
      if (!_config.isRuleEnabled(rule.id)) continue;

      // Skip category-specific rules if context doesn't match
      if (!_shouldRunRule(rule.category, filePath, packageContext)) continue;

      try {
        final issues = rule.analyze(result, content, _config);

        for (final issue in issues) {
          // Apply severity override from config
          final overriddenSeverity =
              _config.getSeverity(rule.id, issue.severity);
          final adjustedIssue = DcmIssue(
            offset: issue.offset,
            length: issue.length,
            message: issue.message,
            severity: overriddenSeverity,
            ruleId: issue.ruleId,
            suggestion: issue.suggestion,
            fixes: issue.fixes,
          );
          allIssues.add(adjustedIssue);
          diagnostics.add(adjustedIssue.toDiagnostic(result.lineInfo));
        }
      } catch (e) {
        stderr.writeln('[DCM] Error running rule ${rule.id}: $e');
      }
    }

    // Cache issues for code actions
    _issueCache[filePath] = allIssues;

    return diagnostics;
  }

  /// Detect which packages are used in the file
  _PackageContext _detectPackageContext(String content) {
    return _PackageContext(
      hasFlutter: content.contains("import 'package:flutter/") ||
          content.contains('import "package:flutter/'),
      hasBloc: content.contains("import 'package:flutter_bloc/") ||
          content.contains('import "package:flutter_bloc/') ||
          content.contains("import 'package:bloc/") ||
          content.contains('import "package:bloc/'),
      hasProvider: content.contains("import 'package:provider/") ||
          content.contains('import "package:provider/'),
      hasRiverpod: content.contains("import 'package:flutter_riverpod/") ||
          content.contains('import "package:flutter_riverpod/') ||
          content.contains("import 'package:riverpod/") ||
          content.contains('import "package:riverpod/') ||
          content.contains("import 'package:hooks_riverpod/") ||
          content.contains('import "package:hooks_riverpod/'),
      hasEquatable: content.contains("import 'package:equatable/") ||
          content.contains('import "package:equatable/'),
      hasIntl: content.contains("import 'package:intl/") ||
          content.contains('import "package:intl/'),
      hasFirebase: content.contains("import 'package:firebase") ||
          content.contains('import "package:firebase'),
      hasGetIt: content.contains("import 'package:get_it/") ||
          content.contains('import "package:get_it/'),
      hasFakeAsync: content.contains("import 'package:fake_async/") ||
          content.contains('import "package:fake_async/') ||
          content.contains('fakeAsync('),
      isTestFile: content.contains("import 'package:test/") ||
          content.contains('import "package:test/') ||
          content.contains("import 'package:flutter_test/") ||
          content.contains('import "package:flutter_test/'),
    );
  }

  /// Check if a rule should run based on category and context
  bool _shouldRunRule(String category, String filePath, _PackageContext ctx) {
    switch (category) {
      case 'common':
        return true;
      case 'flutter':
        return ctx.hasFlutter || _isFlutterFile(filePath);
      case 'bloc':
        return ctx.hasBloc;
      case 'provider':
        return ctx.hasProvider;
      case 'riverpod':
        return ctx.hasRiverpod;
      case 'equatable':
        return ctx.hasEquatable;
      case 'intl':
        return ctx.hasIntl;
      case 'pub':
        return filePath.endsWith('pubspec.yaml');
      case 'firebase':
        return ctx.hasFirebase;
      case 'get_it':
        return ctx.hasGetIt;
      case 'fake_async':
        return ctx.hasFakeAsync || ctx.isTestFile;
      default:
        return true;
    }
  }

  bool _isFlutterFile(String filePath) {
    // Simple heuristic for Flutter files
    return filePath.contains('lib/') ||
        filePath.endsWith('_widget.dart') ||
        filePath.endsWith('_screen.dart') ||
        filePath.endsWith('_page.dart');
  }

  /// Get rule by ID
  DcmRule? getRule(String ruleId) {
    try {
      return _rules.firstWhere((r) => r.id == ruleId);
    } catch (e) {
      return null;
    }
  }

  /// Get all rules in a category
  List<DcmRule> getRulesByCategory(String category) {
    return _rules.where((r) => r.category == category).toList();
  }

  /// Get all enabled rules
  List<DcmRule> getEnabledRules() {
    return _rules.where((r) => _config.isRuleEnabled(r.id)).toList();
  }

  /// Get code actions for DCM diagnostics
  Future<List<CodeAction>> getCodeActions(
    String filePath,
    String content,
    Range range,
    List<Diagnostic> diagnostics,
  ) async {
    final actions = <CodeAction>[];
    final uri = Uri.file(filePath);
    final lineInfo = _lineInfoCache[filePath];
    final cachedIssues = _issueCache[filePath] ?? [];

    for (final diagnostic in diagnostics) {
      if (diagnostic.source != 'dcm') continue;

      final ruleId = diagnostic.code;
      if (ruleId == null) continue;

      final rule = getRule(ruleId.toString());
      if (rule == null) continue;

      // Find the matching issue with fixes
      final matchingIssue = _findMatchingIssue(
        cachedIssues,
        diagnostic.range,
        ruleId.toString(),
        lineInfo,
      );

      // Add quick fix action if fixes are available
      if (matchingIssue != null &&
          matchingIssue.hasAutoFix &&
          lineInfo != null) {
        final textEdits = _createTextEdits(matchingIssue.fixes!, lineInfo);
        if (textEdits.isNotEmpty) {
          actions.add(CodeAction(
            title: 'DCM: Fix ${rule.id}',
            kind: CodeActionKind.QuickFix,
            diagnostics: [diagnostic],
            isPreferred: true,
            edit: WorkspaceEdit(
              changes: {uri: textEdits},
            ),
          ));
        }
      }

      // Add suggestion hint if available
      if (matchingIssue?.suggestion != null) {
        actions.add(CodeAction(
          title: 'DCM: ${matchingIssue!.suggestion}',
          kind: CodeActionKind.QuickFix,
          diagnostics: [diagnostic],
          disabled: CodeActionDisabled(
            reason: 'Manual fix required: ${matchingIssue.suggestion}',
          ),
        ));
      }

      // Add ignore comment action
      if (lineInfo != null) {
        final ignoreEdit = _createIgnoreCommentEdit(
          diagnostic.range,
          ruleId.toString(),
          content,
          lineInfo,
        );
        actions.add(CodeAction(
          title: 'Ignore: ${rule.id} (add ignore comment)',
          kind: CodeActionKind.QuickFix,
          diagnostics: [diagnostic],
          edit: WorkspaceEdit(
            changes: {
              uri: [ignoreEdit]
            },
          ),
        ));
      }
    }

    return actions;
  }

  /// Find cached issue matching the diagnostic
  DcmIssue? _findMatchingIssue(
    List<DcmIssue> issues,
    Range diagnosticRange,
    String ruleId,
    LineInfo? lineInfo,
  ) {
    if (lineInfo == null) return null;

    for (final issue in issues) {
      if (issue.ruleId != ruleId) continue;

      final issueRange = _offsetToRange(issue.offset, issue.length, lineInfo);
      if (issueRange.start.line == diagnosticRange.start.line &&
          issueRange.start.character == diagnosticRange.start.character) {
        return issue;
      }
    }
    return null;
  }

  /// Convert DcmFix list to TextEdit list
  List<TextEdit> _createTextEdits(List<DcmFix> fixes, LineInfo lineInfo) {
    return fixes.map((fix) {
      final range = _offsetToRange(fix.offset, fix.length, lineInfo);
      return TextEdit(range: range, newText: fix.replacement);
    }).toList();
  }

  /// Create TextEdit for adding ignore comment
  TextEdit _createIgnoreCommentEdit(
    Range diagnosticRange,
    String ruleId,
    String content,
    LineInfo lineInfo,
  ) {
    final lineStart = lineInfo.getOffsetOfLine(diagnosticRange.start.line);
    final lineContent = content.substring(
      lineStart,
      diagnosticRange.start.line < lineInfo.lineCount - 1
          ? lineInfo.getOffsetOfLine(diagnosticRange.start.line + 1)
          : content.length,
    );

    // Detect indentation
    final indent =
        lineContent.substring(0, lineContent.indexOf(lineContent.trimLeft()));

    return TextEdit(
      range: Range(
        start: Position(line: diagnosticRange.start.line, character: 0),
        end: Position(line: diagnosticRange.start.line, character: 0),
      ),
      newText: '$indent// ignore: $ruleId\n',
    );
  }

  /// Convert offset/length to LSP Range
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

  /// Get documentation URL for a rule
  String? getRuleDocumentationUrl(String ruleId) {
    return getRule(ruleId)?.documentationUrl;
  }
}

/// Context about which packages are used in a file
class _PackageContext {
  const _PackageContext({
    required this.hasFlutter,
    required this.hasBloc,
    required this.hasProvider,
    required this.hasRiverpod,
    required this.hasEquatable,
    required this.hasIntl,
    required this.hasFirebase,
    required this.hasGetIt,
    required this.hasFakeAsync,
    required this.isTestFile,
  });

  final bool hasFlutter;
  final bool hasBloc;
  final bool hasProvider;
  final bool hasRiverpod;
  final bool hasEquatable;
  final bool hasIntl;
  final bool hasFirebase;
  final bool hasGetIt;
  final bool hasFakeAsync;
  final bool isTestFile;
}
