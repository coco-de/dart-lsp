import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// incorrect-firebase-event-name: Validates Firebase Analytics event names
class IncorrectFirebaseEventNameRule extends DcmRule {
  @override
  String get id => 'incorrect-firebase-event-name';

  @override
  String get description =>
      'Firebase Analytics event names must follow naming conventions: snake_case, max 40 chars, alphanumeric and underscores only.';

  @override
  String get category => 'firebase';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#firebase', '#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _IncorrectFirebaseEventNameVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _IncorrectFirebaseEventNameVisitor extends RecursiveAstVisitor<void> {
  _IncorrectFirebaseEventNameVisitor(this.issues);

  final List<DcmIssue> issues;

  // Firebase Analytics reserved event names that should not be used
  static const _reservedNames = {
    'ad_activeview',
    'ad_click',
    'ad_exposure',
    'ad_impression',
    'ad_query',
    'adunit_exposure',
    'app_clear_data',
    'app_exception',
    'app_remove',
    'app_store_refund',
    'app_store_subscription_cancel',
    'app_store_subscription_convert',
    'app_store_subscription_renew',
    'app_update',
    'app_upgrade',
    'dynamic_link_app_open',
    'dynamic_link_app_update',
    'dynamic_link_first_open',
    'error',
    'first_open',
    'first_visit',
    'in_app_purchase',
    'notification_dismiss',
    'notification_foreground',
    'notification_open',
    'notification_receive',
    'os_update',
    'screen_view',
    'session_start',
    'user_engagement',
  };

  // Firebase Analytics reserved prefixes
  static const _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

  // Valid event name pattern: snake_case, alphanumeric and underscores
  static final _validPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // Check for Firebase Analytics logEvent calls
    if (methodName == 'logEvent') {
      final target = node.target;

      // Check if it's called on FirebaseAnalytics or analytics instance
      bool isFirebaseAnalytics = false;
      if (target is SimpleIdentifier) {
        final name = target.name.toLowerCase();
        if (name.contains('analytics') || name.contains('firebase')) {
          isFirebaseAnalytics = true;
        }
      }

      if (isFirebaseAnalytics) {
        // Find the 'name' argument
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'name') {
            final nameExpr = arg.expression;
            if (nameExpr is StringLiteral) {
              final eventName = nameExpr.stringValue;
              if (eventName != null) {
                _validateEventName(eventName, arg.offset, arg.length);
              }
            }
          }
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  void _validateEventName(String eventName, int offset, int length) {
    // Check length (max 40 characters)
    if (eventName.length > 40) {
      issues.add(DcmIssue(
        offset: offset,
        length: length,
        message:
            'Firebase event name "$eventName" exceeds 40 characters (${eventName.length} chars).',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'incorrect-firebase-event-name',
        suggestion: 'Shorten the event name to 40 characters or less',
      ));
      return;
    }

    // Check for reserved names
    if (_reservedNames.contains(eventName.toLowerCase())) {
      issues.add(DcmIssue(
        offset: offset,
        length: length,
        message: 'Firebase event name "$eventName" is a reserved event name.',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'incorrect-firebase-event-name',
        suggestion: 'Use a custom event name that is not reserved',
      ));
      return;
    }

    // Check for reserved prefixes
    final lowerName = eventName.toLowerCase();
    for (final prefix in _reservedPrefixes) {
      if (lowerName.startsWith(prefix)) {
        issues.add(DcmIssue(
          offset: offset,
          length: length,
          message:
              'Firebase event name "$eventName" starts with reserved prefix "$prefix".',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'incorrect-firebase-event-name',
          suggestion: 'Remove the reserved prefix from the event name',
        ));
        return;
      }
    }

    // Check format: should be snake_case, alphanumeric and underscores
    if (!_validPattern.hasMatch(eventName)) {
      String suggestion = 'Use snake_case format with only lowercase letters, numbers, and underscores';

      // Check specific issues
      if (eventName.contains('-')) {
        suggestion = 'Replace hyphens with underscores';
      } else if (eventName.contains(' ')) {
        suggestion = 'Replace spaces with underscores';
      } else if (eventName != eventName.toLowerCase()) {
        suggestion = 'Convert to lowercase snake_case';
      } else if (eventName.startsWith('_') || eventName.startsWith(RegExp(r'[0-9]'))) {
        suggestion = 'Event name must start with a lowercase letter';
      }

      issues.add(DcmIssue(
        offset: offset,
        length: length,
        message:
            'Firebase event name "$eventName" does not follow naming conventions.',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'incorrect-firebase-event-name',
        suggestion: suggestion,
      ));
    }
  }
}

/// Get all Firebase rules
List<DcmRule> getFirebaseRules() => [
      IncorrectFirebaseEventNameRule(),
    ];
