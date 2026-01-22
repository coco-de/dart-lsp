import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-getting-unregistered-services: Warns about getting services without registration check
class AvoidGettingUnregisteredServicesRule extends DcmRule {
  @override
  String get id => 'avoid-getting-unregistered-services';

  @override
  String get description =>
      'Avoid getting services from GetIt without checking if they are registered.';

  @override
  String get category => 'get_it';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#safety', '#best-practice'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidGettingUnregisteredServicesVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidGettingUnregisteredServicesVisitor
    extends RecursiveAstVisitor<void> {
  _AvoidGettingUnregisteredServicesVisitor(this.issues);

  final List<DcmIssue> issues;
  final Set<String> _checkedTypes = {};
  bool _isInsideIfRegistered = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;

    // Track isRegistered checks
    if (methodName == 'isRegistered') {
      if (_isGetItTarget(target)) {
        // Extract the type being checked
        final typeArgs = node.typeArguments;
        if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
          final typeName = typeArgs.arguments.first.toString();
          _checkedTypes.add(typeName);
        }
      }
    }

    // Check for get() or call() without prior registration check
    if (methodName == 'get' || methodName == 'call') {
      if (_isGetItTarget(target)) {
        final typeArgs = node.typeArguments;
        String? typeName;
        if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
          typeName = typeArgs.arguments.first.toString();
        }

        // Check if this type was checked with isRegistered
        if (typeName == null || !_checkedTypes.contains(typeName)) {
          // Check if we're inside an if block that checks isRegistered
          if (!_isInsideIfRegistered) {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  'Getting service from GetIt without checking if it is registered. This may throw if the service is not registered.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'avoid-getting-unregistered-services',
              suggestion:
                  'Use getIt.isRegistered<T>() before get<T>() or use getOrNull<T>()',
            ));
          }
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check if the condition involves isRegistered
    final condition = node.expression;
    bool checksRegistration = _checksIsRegistered(condition);

    if (checksRegistration) {
      _isInsideIfRegistered = true;
      node.thenStatement.accept(this);
      _isInsideIfRegistered = false;

      final elseStatement = node.elseStatement;
      if (elseStatement != null) {
        elseStatement.accept(this);
      }
    } else {
      super.visitIfStatement(node);
    }
  }

  bool _checksIsRegistered(Expression expr) {
    if (expr is MethodInvocation && expr.methodName.name == 'isRegistered') {
      return _isGetItTarget(expr.target);
    }
    if (expr is PrefixExpression) {
      return _checksIsRegistered(expr.operand);
    }
    if (expr is BinaryExpression) {
      return _checksIsRegistered(expr.leftOperand) ||
          _checksIsRegistered(expr.rightOperand);
    }
    return false;
  }

  bool _isGetItTarget(Expression? target) {
    if (target == null) return false;

    if (target is SimpleIdentifier) {
      final name = target.name.toLowerCase();
      return name == 'getit' ||
          name == 'locator' ||
          name == 'sl' ||
          name == 'servicelocator' ||
          name == 'di';
    }

    if (target is PrefixedIdentifier) {
      final name = target.identifier.name.toLowerCase();
      return name == 'instance' || name == 'i' || name == 'getit';
    }

    if (target is MethodInvocation) {
      // GetIt.instance pattern
      final targetName = target.methodName.name.toLowerCase();
      return targetName == 'instance' || targetName == 'i';
    }

    if (target is PropertyAccess) {
      final propertyName = target.propertyName.name.toLowerCase();
      return propertyName == 'instance' || propertyName == 'i';
    }

    return false;
  }
}

/// Get all GetIt rules
List<DcmRule> getGetItRules() => [
      AvoidGettingUnregisteredServicesRule(),
    ];
