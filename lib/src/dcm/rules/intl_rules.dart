import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// prefer-date-format: Suggests using DateFormat from intl package
class PreferDateFormatRule extends DcmRule {
  @override
  String get id => 'prefer-date-format';

  @override
  String get description =>
      'Prefer using DateFormat from intl package for date formatting.';

  @override
  String get category => 'intl';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#best-practice', '#internationalization'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferDateFormatVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferDateFormatVisitor extends RecursiveAstVisitor<void> {
  _PreferDateFormatVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // Check for DateTime.toString() usage for display
    if (methodName == 'toString') {
      final target = node.target;
      if (target != null) {
        // Check if the target type looks like DateTime
        // In a real implementation, we'd use type resolution
        final targetStr = target.toString();
        if (targetStr.contains('DateTime') ||
            targetStr.contains('date') ||
            targetStr.contains('Date')) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Using DateTime.toString() for display. Consider using DateFormat from intl package for localized formatting.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-date-format',
            suggestion:
                'Use DateFormat.yMd().format(date) or similar for user-facing dates',
          ));
        }
      }
    }

    // Check for manual date string formatting
    if (methodName == 'toIso8601String') {
      final target = node.target;
      if (target != null) {
        // Check context - if this is for display, suggest DateFormat
        final parent = node.parent;
        if (parent is InterpolationExpression ||
            parent is ArgumentList ||
            (parent is BinaryExpression &&
                parent.operator.lexeme == '+')) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Using toIso8601String() which may not be user-friendly. Consider DateFormat for user-facing dates.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-date-format',
            suggestion:
                'Use DateFormat from intl package for localized date display',
          ));
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    // Check for DateTime interpolation
    for (final element in node.elements) {
      if (element is InterpolationExpression) {
        final expr = element.expression;
        if (expr is PropertyAccess) {
          final propertyName = expr.propertyName.name;
          // Common DateTime properties that might be used for display
          if (['year', 'month', 'day', 'hour', 'minute', 'second']
              .contains(propertyName)) {
            issues.add(DcmIssue(
              offset: element.offset,
              length: element.length,
              message:
                  'Manual date component interpolation detected. Use DateFormat for proper localized formatting.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-date-format',
              suggestion: 'Use DateFormat.yMd().format(date) instead',
            ));
          }
        }
      }
    }
    super.visitStringInterpolation(node);
  }
}

/// Get all Intl rules
List<DcmRule> getIntlRules() => [
      PreferDateFormatRule(),
    ];
