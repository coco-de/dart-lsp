import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-ref-read-inside-build: Warns when ref.read is used inside build
class AvoidRefReadInsideBuildRule extends DcmRule {
  @override
  String get id => 'avoid-ref-read-inside-build';

  @override
  String get description =>
      'Avoid using ref.read inside build method. Use ref.watch for reactive values.';

  @override
  String get category => 'riverpod';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#reactivity'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidRefReadInsideBuildVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidRefReadInsideBuildVisitor extends RecursiveAstVisitor<void> {
  _AvoidRefReadInsideBuildVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInBuildMethod = false;
  bool _isInCallback = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuildMethod = _isInBuildMethod;
    _isInBuildMethod = node.name.lexeme == 'build';
    super.visitMethodDeclaration(node);
    _isInBuildMethod = wasBuildMethod;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final wasInCallback = _isInCallback;
    _isInCallback = true;
    super.visitFunctionExpression(node);
    _isInCallback = wasInCallback;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check inside build but NOT inside a callback
    if (_isInBuildMethod && !_isInCallback) {
      final methodName = node.methodName.name;

      if (methodName == 'read') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'ref') {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Using ref.read inside build. Use ref.watch for values that should trigger rebuilds.',
            severity: DiagnosticSeverity.Warning,
            ruleId: 'avoid-ref-read-inside-build',
            suggestion:
                'Use ref.watch for reactive values, ref.read only in callbacks',
          ));
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// avoid-ref-watch-outside-build: Warns when ref.watch is used outside build
class AvoidRefWatchOutsideBuildRule extends DcmRule {
  @override
  String get id => 'avoid-ref-watch-outside-build';

  @override
  String get description =>
      'Avoid using ref.watch outside of build methods. Use ref.read instead.';

  @override
  String get category => 'riverpod';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#performance'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidRefWatchOutsideBuildVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidRefWatchOutsideBuildVisitor extends RecursiveAstVisitor<void> {
  _AvoidRefWatchOutsideBuildVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInBuildMethod = false;
  bool _isInProviderDefinition = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuildMethod = _isInBuildMethod;
    _isInBuildMethod = node.name.lexeme == 'build';
    super.visitMethodDeclaration(node);
    _isInBuildMethod = wasBuildMethod;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Check if this is inside a Provider definition
    final parent = node.parent;
    if (parent is ArgumentList) {
      final grandParent = parent.parent;
      if (grandParent is MethodInvocation) {
        final typeName = grandParent.methodName.name;
        if (typeName.contains('Provider')) {
          final wasInProvider = _isInProviderDefinition;
          _isInProviderDefinition = true;
          super.visitFunctionExpression(node);
          _isInProviderDefinition = wasInProvider;
          return;
        }
      }
    }
    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Skip if in build method or provider definition (both are valid for watch)
    if (!_isInBuildMethod && !_isInProviderDefinition) {
      final methodName = node.methodName.name;

      if (methodName == 'watch') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'ref') {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'ref.watch should only be used inside build methods or provider definitions. Use ref.read outside.',
            severity: DiagnosticSeverity.Warning,
            ruleId: 'avoid-ref-watch-outside-build',
            suggestion: 'Replace with ref.read',
          ));
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-riverpod-async-value: Suggests using AsyncValue pattern
class PreferRiverpodAsyncValueRule extends DcmRule {
  @override
  String get id => 'prefer-riverpod-async-value';

  @override
  String get description =>
      'Prefer using AsyncValue.when for comprehensive handling of async states.';

  @override
  String get category => 'riverpod';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#best-practice', '#completeness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferRiverpodAsyncValueVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferRiverpodAsyncValueVisitor extends RecursiveAstVisitor<void> {
  _PreferRiverpodAsyncValueVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Check for asyncValue.value or asyncValue.data patterns
    final propertyName = node.propertyName.name;

    if (propertyName == 'value' || propertyName == 'data') {
      // Check if target is likely an AsyncValue
      final target = node.target;
      if (target is MethodInvocation) {
        final methodName = target.methodName.name;
        // Check if it's a ref.watch call
        if (methodName == 'watch') {
          final targetOfWatch = target.target;
          if (targetOfWatch is SimpleIdentifier &&
              targetOfWatch.name == 'ref') {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  'Accessing .value directly on AsyncValue. Consider using .when() for comprehensive state handling.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-riverpod-async-value',
              suggestion:
                  'Use asyncValue.when(data: ..., loading: ..., error: ...)',
            ));
          }
        }
      }
    }

    // Also check for direct .hasValue, .hasError patterns that might be incomplete
    if (propertyName == 'hasValue' || propertyName == 'hasError') {
      // This is a hint that they might be doing manual state checking
      // Suggest using .when instead
      final target = node.target;
      if (target != null) {
        final parent = node.parent;
        // Only warn if this is used in an if condition
        if (parent is PrefixExpression ||
            parent is BinaryExpression ||
            parent is IfStatement) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Manual AsyncValue state checking detected. Consider using .when() for cleaner handling.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-riverpod-async-value',
            suggestion:
                'Use asyncValue.when(data: ..., loading: ..., error: ...)',
          ));
        }
      }
    }

    super.visitPropertyAccess(node);
  }
}

/// Get all Riverpod rules
List<DcmRule> getRiverpodRules() => [
      AvoidRefReadInsideBuildRule(),
      AvoidRefWatchOutsideBuildRule(),
      PreferRiverpodAsyncValueRule(),
    ];
