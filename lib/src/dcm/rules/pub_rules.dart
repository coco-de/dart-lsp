import 'package:analyzer/dart/analysis/results.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-any-version-constraints: Warns about using 'any' version constraints
class AvoidAnyVersionConstraintsRule extends DcmRule {
  @override
  String get id => 'avoid-any-version-constraints';

  @override
  String get description =>
      'Avoid using "any" version constraints in pubspec.yaml. Specify explicit version constraints.';

  @override
  String get category => 'pub';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#dependency', '#stability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    // This rule only applies to pubspec.yaml files
    // We check the content for pubspec patterns
    final issues = <DcmIssue>[];

    // Check if this looks like a pubspec.yaml content
    if (!_isPubspecContent(content)) {
      return issues;
    }

    // Find "any" version constraints
    final lines = content.split('\n');
    int offset = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Check for dependency: any pattern
      final anyMatch = RegExp(r':\s*any\s*$').firstMatch(trimmed);
      if (anyMatch != null) {
        final startOfLine = offset + line.indexOf(trimmed);
        issues.add(DcmIssue(
          offset: startOfLine,
          length: trimmed.length,
          message:
              'Using "any" version constraint is unsafe. Specify an explicit version constraint.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-any-version-constraints',
          suggestion: 'Use a caret constraint like ^1.0.0',
        ));
      }

      offset += line.length + 1; // +1 for newline
    }

    return issues;
  }

  bool _isPubspecContent(String content) {
    return content.contains('dependencies:') ||
        content.contains('dev_dependencies:') ||
        content.contains('name:') && content.contains('version:');
  }
}

/// prefer-caret-version-constraints: Suggests using caret syntax for versions
class PreferCaretVersionConstraintsRule extends DcmRule {
  @override
  String get id => 'prefer-caret-version-constraints';

  @override
  String get description =>
      'Prefer caret (^) version constraints for dependency versions.';

  @override
  String get category => 'pub';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#dependency', '#best-practice'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];

    if (!_isPubspecContent(content)) {
      return issues;
    }

    final lines = content.split('\n');
    int offset = 0;
    bool inDependencies = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Track if we're in dependencies section
      if (trimmed == 'dependencies:' ||
          trimmed == 'dev_dependencies:' ||
          trimmed == 'dependency_overrides:') {
        inDependencies = true;
        offset += line.length + 1;
        continue;
      }

      // Exit dependencies section on new top-level key
      if (inDependencies &&
          !line.startsWith(' ') &&
          !line.startsWith('\t') &&
          trimmed.isNotEmpty &&
          !trimmed.startsWith('#')) {
        inDependencies = false;
      }

      if (inDependencies && trimmed.contains(':')) {
        // Check for exact version (no ^ or >=)
        // Pattern: package_name: 1.2.3
        final exactVersionMatch =
            RegExp(r'^\s*[\w_]+:\s*(\d+\.\d+\.\d+)\s*$').firstMatch(line);

        if (exactVersionMatch != null) {
          final version = exactVersionMatch.group(1);
          final startOfLine = offset + line.indexOf(trimmed);
          issues.add(DcmIssue(
            offset: startOfLine,
            length: trimmed.length,
            message:
                'Using exact version constraint "$version". Consider using caret constraint "^$version" to allow compatible updates.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-caret-version-constraints',
            suggestion: 'Change to ^$version',
          ));
        }

        // Check for >= without < (potentially too permissive)
        final permissiveMatch =
            RegExp(r':\s*>=\d+\.\d+\.\d+\s*$').firstMatch(trimmed);
        if (permissiveMatch != null) {
          final startOfLine = offset + line.indexOf(trimmed);
          issues.add(DcmIssue(
            offset: startOfLine,
            length: trimmed.length,
            message:
                'Using ">=" without upper bound may accept breaking changes. Consider caret constraint.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-caret-version-constraints',
            suggestion: 'Use caret constraint ^X.Y.Z or specify upper bound',
          ));
        }
      }

      offset += line.length + 1;
    }

    return issues;
  }

  bool _isPubspecContent(String content) {
    return content.contains('dependencies:') ||
        content.contains('dev_dependencies:');
  }
}

/// avoid-path-dependencies: Warns about path dependencies in pubspec
class AvoidPathDependenciesRule extends DcmRule {
  @override
  String get id => 'avoid-path-dependencies';

  @override
  String get description =>
      'Path dependencies should not be used in published packages.';

  @override
  String get category => 'pub';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#dependency', '#publishing'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];

    if (!_isPubspecContent(content)) {
      return issues;
    }

    final lines = content.split('\n');
    int offset = 0;
    bool inDependencies = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Track if we're in dependencies section
      if (trimmed == 'dependencies:' || trimmed == 'dev_dependencies:') {
        inDependencies = true;
        offset += line.length + 1;
        continue;
      }

      // Exit dependencies section on new top-level key
      if (inDependencies &&
          !line.startsWith(' ') &&
          !line.startsWith('\t') &&
          trimmed.isNotEmpty &&
          !trimmed.startsWith('#')) {
        inDependencies = false;
      }

      if (inDependencies) {
        // Check for path: key
        if (trimmed.startsWith('path:')) {
          final startOfLine = offset + line.indexOf(trimmed);
          issues.add(DcmIssue(
            offset: startOfLine,
            length: trimmed.length,
            message:
                'Path dependencies cannot be used in published packages and may cause issues in CI/CD.',
            severity: DiagnosticSeverity.Warning,
            ruleId: 'avoid-path-dependencies',
            suggestion: 'Use git dependency or publish the package to pub.dev',
          ));
        }
      }

      offset += line.length + 1;
    }

    return issues;
  }

  bool _isPubspecContent(String content) {
    return content.contains('dependencies:') ||
        content.contains('dev_dependencies:');
  }
}

/// Get all Pub rules
List<DcmRule> getPubRules() => [
      AvoidAnyVersionConstraintsRule(),
      PreferCaretVersionConstraintsRule(),
      AvoidPathDependenciesRule(),
    ];
