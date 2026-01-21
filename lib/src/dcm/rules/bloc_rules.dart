import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-passing-bloc-to-bloc: Warns when a Bloc is passed to another Bloc
class AvoidPassingBlocToBlocRule extends DcmRule {
  @override
  String get id => 'avoid-passing-bloc-to-bloc';

  @override
  String get description =>
      'Avoid passing Bloc instances to other Blocs. Use streams or events instead.';

  @override
  String get category => 'bloc';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#architecture', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidPassingBlocToBlocVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidPassingBlocToBlocVisitor extends RecursiveAstVisitor<void> {
  _AvoidPassingBlocToBlocVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInBlocClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInBlocClass = superclassName == 'Bloc' || superclassName == 'Cubit';
    }
    super.visitClassDeclaration(node);
    _isInBlocClass = false;
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!_isInBlocClass) {
      super.visitConstructorDeclaration(node);
      return;
    }

    for (final param in node.parameters.parameters) {
      final type = _getParameterType(param);
      if (type != null && _isBlocType(type)) {
        issues.add(DcmIssue(
          offset: param.offset,
          length: param.length,
          message:
              'Avoid passing Bloc to another Bloc. Consider using streams or events for communication.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-passing-bloc-to-bloc',
          suggestion: 'Use stream subscriptions or event-based communication',
        ));
      }
    }
    super.visitConstructorDeclaration(node);
  }

  String? _getParameterType(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      final type = param.type;
      if (type is NamedType) {
        return type.name2.lexeme;
      }
    } else if (param is DefaultFormalParameter) {
      return _getParameterType(param.parameter);
    }
    return null;
  }

  bool _isBlocType(String typeName) {
    return typeName.endsWith('Bloc') || typeName.endsWith('Cubit');
  }
}

/// avoid-bloc-public-fields: Warns about public fields in Bloc classes
class AvoidBlocPublicFieldsRule extends DcmRule {
  @override
  String get id => 'avoid-bloc-public-fields';

  @override
  String get description =>
      'Avoid public fields in Bloc classes. Use state instead.';

  @override
  String get category => 'bloc';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#encapsulation', '#architecture'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidBlocPublicFieldsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidBlocPublicFieldsVisitor extends RecursiveAstVisitor<void> {
  _AvoidBlocPublicFieldsVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInBlocClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInBlocClass = superclassName == 'Bloc' || superclassName == 'Cubit';
    }
    super.visitClassDeclaration(node);
    _isInBlocClass = false;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!_isInBlocClass) {
      super.visitFieldDeclaration(node);
      return;
    }

    // Skip static fields
    if (node.isStatic) {
      super.visitFieldDeclaration(node);
      return;
    }

    for (final variable in node.fields.variables) {
      final name = variable.name.lexeme;
      // Check if field is public (doesn't start with underscore)
      if (!name.startsWith('_')) {
        issues.add(DcmIssue(
          offset: variable.name.offset,
          length: variable.name.length,
          message:
              "Public field '$name' in Bloc. Bloc state should be managed through emit().",
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-bloc-public-fields',
          suggestion: 'Make field private or include in Bloc state',
        ));
      }
    }
    super.visitFieldDeclaration(node);
  }
}

/// prefer-multi-bloc-provider: Suggests using MultiBlocProvider
class PreferMultiBlocProviderRule extends DcmRule {
  @override
  String get id => 'prefer-multi-bloc-provider';

  @override
  String get description =>
      'Prefer MultiBlocProvider over nested BlocProvider widgets.';

  @override
  String get category => 'bloc';

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
    final visitor = _PreferMultiBlocProviderVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferMultiBlocProviderVisitor extends RecursiveAstVisitor<void> {
  _PreferMultiBlocProviderVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    if (typeName == 'BlocProvider') {
      // Check if child is also a BlocProvider
      final childArg = _findNamedArgument(node.argumentList, 'child');
      if (childArg != null) {
        final childExpr = childArg.expression;
        if (childExpr is InstanceCreationExpression) {
          final childTypeName = childExpr.constructorName.type.name2.lexeme;
          if (childTypeName == 'BlocProvider') {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  'Nested BlocProvider widgets detected. Use MultiBlocProvider for better readability.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-multi-bloc-provider',
              suggestion: 'Wrap multiple BlocProviders in MultiBlocProvider',
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

/// prefer-bloc-extensions: Suggests using Bloc extensions for listening
class PreferBlocExtensionsRule extends DcmRule {
  @override
  String get id => 'prefer-bloc-extensions';

  @override
  String get description =>
      'Prefer using BlocListener/BlocConsumer extensions over manual stream subscriptions.';

  @override
  String get category => 'bloc';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#best-practice', '#architecture'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferBlocExtensionsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferBlocExtensionsVisitor extends RecursiveAstVisitor<void> {
  _PreferBlocExtensionsVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInStatefulWidget = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInStatefulWidget = superclassName.startsWith('State');
    }
    super.visitClassDeclaration(node);
    _isInStatefulWidget = false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isInStatefulWidget) {
      super.visitMethodInvocation(node);
      return;
    }

    // Check for .stream.listen() pattern on Bloc
    if (node.methodName.name == 'listen') {
      final target = node.target;
      if (target is PrefixedIdentifier && target.identifier.name == 'stream') {
        // Check if the prefix ends with Bloc or Cubit
        final prefixName = target.prefix.name;
        if (prefixName.endsWith('Bloc') ||
            prefixName.endsWith('Cubit') ||
            prefixName.contains('bloc') ||
            prefixName.contains('cubit')) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Manual stream subscription on Bloc detected. Consider using BlocListener or BlocConsumer.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-bloc-extensions',
            suggestion: 'Use BlocListener for side effects or BlocConsumer',
          ));
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// proper-bloc-state-naming: Enforces proper Bloc state naming
class ProperBlocStateNamingRule extends DcmRule {
  @override
  String get id => 'proper-bloc-state-naming';

  @override
  String get description =>
      'Bloc state classes should follow naming convention: {Feature}State or {Feature}{Condition}.';

  @override
  String get category => 'bloc';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#naming', '#convention'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _ProperBlocStateNamingVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _ProperBlocStateNamingVisitor extends RecursiveAstVisitor<void> {
  _ProperBlocStateNamingVisitor(this.issues);

  final List<DcmIssue> issues;
  final _stateClasses = <String>[];
  final _stateSubclasses = <ClassDeclaration>[];

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // First pass: collect state class names
    for (final declaration in node.declarations) {
      if (declaration is ClassDeclaration) {
        final className = declaration.name.lexeme;
        if (className.endsWith('State')) {
          _stateClasses.add(className);
        }

        // Check if extends a State class
        final extendsClause = declaration.extendsClause;
        if (extendsClause != null) {
          final superclassName = extendsClause.superclass.name2.lexeme;
          if (superclassName.endsWith('State') && !className.endsWith('State')) {
            _stateSubclasses.add(declaration);
          }
        }
      }
    }

    // Check subclasses for proper naming
    for (final subclass in _stateSubclasses) {
      final className = subclass.name.lexeme;
      final extendsClause = subclass.extendsClause;
      if (extendsClause != null) {
        final baseName = extendsClause.superclass.name2.lexeme;
        final featurePrefix = baseName.replaceAll('State', '');

        // Valid patterns:
        // - {Feature}Initial, {Feature}Loading, {Feature}Success, {Feature}Failure
        // - {Feature}Loaded, {Feature}Error, etc.
        final validSuffixes = [
          'Initial',
          'Loading',
          'Loaded',
          'Success',
          'Failure',
          'Error',
          'Empty',
          'InProgress'
        ];

        bool isValidName = false;
        for (final suffix in validSuffixes) {
          if (className == '$featurePrefix$suffix') {
            isValidName = true;
            break;
          }
        }

        // Also allow custom suffixes with feature prefix
        if (!isValidName && className.startsWith(featurePrefix)) {
          isValidName = true;
        }

        if (!isValidName) {
          issues.add(DcmIssue(
            offset: subclass.name.offset,
            length: subclass.name.length,
            message:
                "State class '$className' should start with feature prefix '$featurePrefix'.",
            severity: DiagnosticSeverity.Information,
            ruleId: 'proper-bloc-state-naming',
            suggestion: 'Rename to $featurePrefix$className',
          ));
        }
      }
    }

    super.visitCompilationUnit(node);
  }
}

/// Get all Bloc rules
List<DcmRule> getBlocRules() => [
      AvoidPassingBlocToBlocRule(),
      AvoidBlocPublicFieldsRule(),
      PreferMultiBlocProviderRule(),
      PreferBlocExtensionsRule(),
      ProperBlocStateNamingRule(),
    ];
