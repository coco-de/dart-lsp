import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// extend-equatable: Warns about classes that override == without Equatable
class ExtendEquatableRule extends DcmRule {
  @override
  String get id => 'extend-equatable';

  @override
  String get description =>
      'Consider extending Equatable for value equality instead of manually overriding == and hashCode.';

  @override
  String get category => 'equatable';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#best-practice', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _ExtendEquatableVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _ExtendEquatableVisitor extends RecursiveAstVisitor<void> {
  _ExtendEquatableVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Check if already extends Equatable
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName == 'Equatable') {
        super.visitClassDeclaration(node);
        return;
      }
    }

    // Check if class has @immutable annotation (these are good candidates)
    bool hasImmutableAnnotation = false;
    for (final annotation in node.metadata) {
      if (annotation.name.name == 'immutable') {
        hasImmutableAnnotation = true;
        break;
      }
    }

    // Check if class manually overrides == and hashCode
    bool overridesEquals = false;
    bool overridesHashCode = false;

    if (node.body case BlockClassBody body) {
      for (final member in body.members) {
        if (member is MethodDeclaration) {
          final name = member.name.lexeme;
          if (name == '==' && member.isOperator) {
            overridesEquals = true;
          }
        }
        if (member is MethodDeclaration && member.isGetter) {
          if (member.name.lexeme == 'hashCode') {
            overridesHashCode = true;
          }
        }
      }
    }

    final className = node.namePart.typeName.lexeme;
    final classNameOffset = node.namePart.typeName.offset;
    final classNameLength = node.namePart.typeName.length;

    if (overridesEquals && overridesHashCode) {
      issues.add(DcmIssue(
        offset: classNameOffset,
        length: classNameLength,
        message:
            "Class '$className' manually overrides == and hashCode. Consider extending Equatable for cleaner value equality.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'extend-equatable',
        suggestion: 'Extend Equatable and implement props getter',
      ));
    } else if (hasImmutableAnnotation && !overridesEquals) {
      // Immutable classes should probably implement equality
      issues.add(DcmIssue(
        offset: classNameOffset,
        length: classNameLength,
        message:
            "Immutable class '$className' does not implement value equality. Consider extending Equatable.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'extend-equatable',
        suggestion: 'Extend Equatable for proper value comparison',
      ));
    }

    super.visitClassDeclaration(node);
  }
}

/// equatable-proper-super-calls: Ensures proper super calls in Equatable
class EquatableProperSuperCallsRule extends DcmRule {
  @override
  String get id => 'equatable-proper-super-calls';

  @override
  String get description =>
      'Equatable subclasses should properly include parent props in their props list.';

  @override
  String get category => 'equatable';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#equality'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _EquatableProperSuperCallsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _EquatableProperSuperCallsVisitor extends RecursiveAstVisitor<void> {
  _EquatableProperSuperCallsVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _extendsEquatableSubclass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _extendsEquatableSubclass = false;

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name.lexeme;

      // Check if extends something other than Equatable directly
      // (which would be an Equatable subclass)
      if (superclassName != 'Equatable' && superclassName != 'Object') {
        // We assume it might extend an Equatable subclass
        // In a real implementation, we'd need type resolution
        _extendsEquatableSubclass = true;
      }
    }

    super.visitClassDeclaration(node);

    _extendsEquatableSubclass = false;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!_extendsEquatableSubclass) {
      super.visitMethodDeclaration(node);
      return;
    }

    // Check if this is the props getter
    if (node.isGetter && node.name.lexeme == 'props') {
      final body = node.body;

      bool hasSuperProps = false;

      // Check for super.props in the return expression
      if (body is ExpressionFunctionBody) {
        hasSuperProps = _containsSuperProps(body.expression);
      } else if (body is BlockFunctionBody) {
        for (final statement in body.block.statements) {
          if (statement is ReturnStatement && statement.expression != null) {
            hasSuperProps = _containsSuperProps(statement.expression!);
          }
        }
      }

      if (!hasSuperProps) {
        issues.add(DcmIssue(
          offset: node.name.offset,
          length: node.name.length,
          message:
              'props getter in Equatable subclass should include ...super.props for proper equality.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'equatable-proper-super-calls',
          suggestion: 'Add ...super.props to the props list',
        ));
      }
    }

    super.visitMethodDeclaration(node);
  }

  bool _containsSuperProps(Expression expr) {
    if (expr is ListLiteral) {
      for (final element in expr.elements) {
        if (element is SpreadElement) {
          final spreadExpr = element.expression;
          if (spreadExpr is PrefixedIdentifier) {
            if (spreadExpr.prefix.name == 'super' &&
                spreadExpr.identifier.name == 'props') {
              return true;
            }
          }
          if (spreadExpr is PropertyAccess) {
            final target = spreadExpr.target;
            if (target is SuperExpression &&
                spreadExpr.propertyName.name == 'props') {
              return true;
            }
          }
        }
      }
    }
    return false;
  }
}

/// Get all Equatable rules
List<DcmRule> getEquatableRules() => [
      ExtendEquatableRule(),
      EquatableProperSuperCallsRule(),
    ];
