import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-watch-outside-build: Warns when context.watch is used outside build
class AvoidWatchOutsideBuildRule extends DcmRule {
  @override
  String get id => 'avoid-watch-outside-build';

  @override
  String get description =>
      'Avoid using context.watch outside of build methods. Use context.read instead.';

  @override
  String get category => 'provider';

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
    final visitor = _AvoidWatchOutsideBuildVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidWatchOutsideBuildVisitor extends RecursiveAstVisitor<void> {
  _AvoidWatchOutsideBuildVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInBuildMethod = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuildMethod = _isInBuildMethod;
    _isInBuildMethod = node.name.lexeme == 'build';
    super.visitMethodDeclaration(node);
    _isInBuildMethod = wasBuildMethod;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isInBuildMethod) {
      // Check for context.watch() or Provider.of with listen:true
      final methodName = node.methodName.name;

      if (methodName == 'watch') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'context') {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'context.watch should only be used inside build method. Use context.read outside build.',
            severity: DiagnosticSeverity.Warning,
            ruleId: 'avoid-watch-outside-build',
            suggestion: 'Replace with context.read',
          ));
        }
      }

      // Check Provider.of without listen: false
      if (methodName == 'of') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'Provider') {
          // Check if listen: false is specified
          bool hasListenFalse = false;
          for (final arg in node.argumentList.arguments) {
            if (arg is NamedExpression &&
                arg.name.label.name == 'listen' &&
                arg.expression is BooleanLiteral &&
                (arg.expression as BooleanLiteral).value == false) {
              hasListenFalse = true;
              break;
            }
          }

          if (!hasListenFalse) {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  'Provider.of outside build should specify listen: false to avoid unnecessary rebuilds.',
              severity: DiagnosticSeverity.Warning,
              ruleId: 'avoid-watch-outside-build',
              suggestion: 'Add listen: false parameter',
            ));
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// avoid-read-inside-build: Warns when context.read is used inside build
class AvoidReadInsideBuildRule extends DcmRule {
  @override
  String get id => 'avoid-read-inside-build';

  @override
  String get description =>
      'Avoid using context.read inside build method for values that should trigger rebuilds.';

  @override
  String get category => 'provider';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#correctness', '#reactivity'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidReadInsideBuildVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidReadInsideBuildVisitor extends RecursiveAstVisitor<void> {
  _AvoidReadInsideBuildVisitor(this.issues);

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
    // Only check when inside build but NOT inside a callback
    if (_isInBuildMethod && !_isInCallback) {
      final methodName = node.methodName.name;

      if (methodName == 'read') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'context') {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Using context.read inside build method. If you need reactivity, use context.watch instead.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'avoid-read-inside-build',
            suggestion:
                'Use context.watch for reactive values, or context.read only in callbacks',
          ));
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// dispose-providers: Warns about ChangeNotifier not being disposed
class DisposeProvidersRule extends DcmRule {
  @override
  String get id => 'dispose-providers';

  @override
  String get description =>
      'ChangeNotifier providers should be disposed to prevent memory leaks.';

  @override
  String get category => 'provider';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#memory', '#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _DisposeProvidersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _DisposeProvidersVisitor extends RecursiveAstVisitor<void> {
  _DisposeProvidersVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;

    // Check if using ChangeNotifierProvider without dispose consideration
    if (typeName == 'ChangeNotifierProvider') {
      // Check if using create: vs value:
      bool usesValue = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final argName = arg.name.label.name;
          if (argName == 'value') usesValue = true;
        }
      }

      // If using value:, the provider doesn't handle disposal
      if (usesValue) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'ChangeNotifierProvider.value does not dispose the notifier. Ensure manual disposal or use create: instead.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'dispose-providers',
          suggestion:
              'Use ChangeNotifierProvider with create: for automatic disposal',
        ));
      }
    }

    super.visitInstanceCreationExpression(node);
  }
}

/// prefer-multi-provider: Suggests using MultiProvider over nested providers
class PreferMultiProviderRule extends DcmRule {
  @override
  String get id => 'prefer-multi-provider';

  @override
  String get description =>
      'Prefer MultiProvider over nested Provider widgets for better readability.';

  @override
  String get category => 'provider';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#best-practice'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferMultiProviderVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferMultiProviderVisitor extends RecursiveAstVisitor<void> {
  _PreferMultiProviderVisitor(this.issues);

  final List<DcmIssue> issues;

  static const _providerTypes = {
    'Provider',
    'ChangeNotifierProvider',
    'StreamProvider',
    'FutureProvider',
    'ValueListenableProvider',
    'ListenableProvider',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;

    if (_providerTypes.contains(typeName)) {
      // Check if child is also a Provider
      final childArg = _findNamedArgument(node.argumentList, 'child');
      if (childArg != null) {
        final childExpr = childArg.expression;
        if (childExpr is InstanceCreationExpression) {
          final childTypeName = childExpr.constructorName.type.name2.lexeme;
          if (_providerTypes.contains(childTypeName)) {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  'Nested Provider widgets detected. Use MultiProvider for better readability.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-multi-provider',
              suggestion: 'Wrap multiple Providers in MultiProvider',
            ));
          }
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  NamedExpression? _findNamedArgument(ArgumentList args, String name) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return arg;
      }
    }
    return null;
  }
}

/// Get all Provider rules
List<DcmRule> getProviderRules() => [
      AvoidWatchOutsideBuildRule(),
      AvoidReadInsideBuildRule(),
      DisposeProvidersRule(),
      PreferMultiProviderRule(),
    ];
