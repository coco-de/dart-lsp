import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:lsp_server/lsp_server.dart';

/// Represents a single text edit for auto-fix
class DcmFix {
  const DcmFix({
    required this.offset,
    required this.length,
    required this.replacement,
  });

  /// Start offset of the text to replace
  final int offset;

  /// Length of text to replace (0 for insert)
  final int length;

  /// Replacement text
  final String replacement;
}

/// Represents a DCM rule issue found in the code
class DcmIssue {
  const DcmIssue({
    required this.offset,
    required this.length,
    required this.message,
    required this.severity,
    required this.ruleId,
    this.suggestion,
    this.fixes,
  });

  final int offset;
  final int length;
  final String message;
  final DiagnosticSeverity severity;
  final String ruleId;
  final String? suggestion;

  /// Optional list of fixes to apply for auto-fix
  final List<DcmFix>? fixes;

  /// Whether this issue has auto-fix available
  bool get hasAutoFix => fixes != null && fixes!.isNotEmpty;
}

/// Base class for all DCM rules
abstract class DcmRule {
  /// Unique identifier for the rule (e.g., 'avoid-dynamic')
  String get id;

  /// Human-readable description of the rule
  String get description;

  /// Documentation URL for the rule
  String get documentationUrl => 'https://dcm.dev/docs/rules/$category/$id';

  /// Category of the rule (common, flutter, etc.)
  String get category;

  /// Whether this rule is enabled by default
  bool get enabledByDefault;

  /// Default severity of the rule
  DiagnosticSeverity get defaultSeverity;

  /// Tags for the rule (e.g., #correctness, #maintainability)
  List<String> get tags;

  /// Whether this rule has auto-fix support
  bool get hasAutoFix => false;

  /// Analyze the given compilation unit and return issues
  List<DcmIssue> analyze(
    ResolvedUnitResult result,
    String content,
    DcmConfig config,
  );
}

/// Configuration for DCM rules
class DcmConfig {
  const DcmConfig({
    this.enabledRules = const {},
    this.disabledRules = const {},
    this.ruleConfigs = const {},
    this.severityOverrides = const {},
  });

  /// Default configuration with recommended rules enabled
  factory DcmConfig.recommended() {
    return const DcmConfig(
      enabledRules: {
        // Common rules
        'avoid-dynamic',
        'avoid-non-null-assertion',
        'avoid-unnecessary-nullable',
        'prefer-trailing-comma',
        'avoid-long-functions',
        'avoid-nested-conditional-expressions',
        'avoid-returning-widgets',
        'prefer-correct-identifier-length',
        'avoid-unnecessary-setstate',
        'dispose-fields',
        'prefer-extracting-callbacks',
        'prefer-single-child-column-or-row',
        'avoid-shrink-wrap-in-lists',
        'prefer-const-border-radius',
        'avoid-expanded-as-spacer',
        'avoid-border-all',
        'prefer-dedicated-media-query-methods',
        'avoid-collection-methods-with-unrelated-types',
        'avoid-duplicate-exports',
        'avoid-global-state',
        'avoid-late-keyword',
        'avoid-redundant-async',
        'avoid-unnecessary-type-assertions',
        'avoid-unnecessary-type-casts',
        'avoid-unrelated-type-assertions',
        'avoid-unused-parameters',
        'binary-expression-operand-order',
        'double-literal-format',
        'newline-before-return',
        'no-boolean-literal-compare',
        'no-empty-block',
        'no-equal-then-else',
        'prefer-commenting-analyzer-ignores',
        'prefer-conditional-expressions',
        'prefer-first',
        'prefer-last',
        'prefer-immediate-return',
        'prefer-moving-to-variable',
        // Statement rules (common)
        'avoid-throw-in-catch-block',
        'avoid-unnecessary-setters',
        'prefer-switch-case-enum',
        'avoid-positional-boolean-parameters',
        // Collection rules
        'prefer-iterable-methods',
        'avoid-cascade-after-if-null',
        'prefer-spread-collections',
        'prefer-contains',
        'prefer-is-empty',
        // Naming rules
        'prefer-match-file-name',
        // Bloc rules
        'avoid-passing-bloc-to-bloc',
        'avoid-bloc-public-fields',
        'prefer-multi-bloc-provider',
        'prefer-bloc-extensions',
        'proper-bloc-state-naming',
        // Provider rules
        'avoid-watch-outside-build',
        'avoid-read-inside-build',
        'dispose-providers',
        'prefer-multi-provider',
        // Riverpod rules
        'avoid-ref-read-inside-build',
        'avoid-ref-watch-outside-build',
        'prefer-riverpod-async-value',
        // Equatable rules
        'extend-equatable',
        'equatable-proper-super-calls',
        // Intl rules
        'prefer-date-format',
        // Pub rules
        'avoid-any-version-constraints',
        'prefer-caret-version-constraints',
        'avoid-path-dependencies',
        // Firebase rules
        'incorrect-firebase-event-name',
        // GetIt rules
        'avoid-getting-unregistered-services',
        // FakeAsync rules
        'avoid-async-callback-in-fake-async',
        // Extended Flutter rules
        'always-remove-listener',
        'avoid-unnecessary-stateful-widgets',
        'avoid-recursive-widget-calls',
        'use-key-in-widget-constructors',
        'avoid-unnecessary-containers',
        'prefer-const-constructors',
        'avoid-print-in-release',
        'prefer-sized-box-shrink-expand',
        'prefer-correct-edge-insets-constructor',
        'avoid-hardcoded-colors',
        'avoid-setstate-in-build',
        'prefer-intl-name',
        'avoid-wrapping-in-padding',
        'check-for-equals-in-render-object-setters',
        'avoid-late-context',
        'prefer-null-aware-method-calls',
        'avoid-using-expanded-on-scrollable',
      },
    );
  }

  /// Enabled rules
  final Set<String> enabledRules;

  /// Disabled rules
  final Set<String> disabledRules;

  /// Rule-specific configurations
  final Map<String, Map<String, dynamic>> ruleConfigs;

  /// Severity overrides for rules
  final Map<String, DiagnosticSeverity> severityOverrides;

  /// Check if a rule is enabled
  bool isRuleEnabled(String ruleId) {
    if (disabledRules.contains(ruleId)) return false;

    return enabledRules.isEmpty || enabledRules.contains(ruleId);
  }

  /// Get severity for a rule
  DiagnosticSeverity getSeverity(
    String ruleId,
    DiagnosticSeverity defaultSeverity,
  ) {
    return severityOverrides[ruleId] ?? defaultSeverity;
  }

  /// Get configuration for a specific rule
  Map<String, dynamic> getRuleConfig(String ruleId) {
    return ruleConfigs[ruleId] ?? {};
  }
}

/// Helper extension for converting DcmIssue to Diagnostic
extension DcmIssueToDiagnostic on DcmIssue {
  Diagnostic toDiagnostic(LineInfo lineInfo) {
    final startLocation = lineInfo.getLocation(offset);
    final endLocation = lineInfo.getLocation(offset + length);

    return Diagnostic(
      range: Range(
        start: Position(
          line: startLocation.lineNumber - 1,
          character: startLocation.columnNumber - 1,
        ),
        end: Position(
          line: endLocation.lineNumber - 1,
          character: endLocation.columnNumber - 1,
        ),
      ),
      message: message,
      severity: severity,
      source: 'dcm',
      code: ruleId,
    );
  }
}
