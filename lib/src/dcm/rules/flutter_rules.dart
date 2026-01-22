import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-returning-widgets: Warns against returning widgets from methods
class AvoidReturningWidgetsRule extends DcmRule {
  @override
  String get id => 'avoid-returning-widgets';

  @override
  String get description =>
      'Avoid returning widgets from methods. Extract them into separate widget classes.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#performance', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidReturningWidgetsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidReturningWidgetsVisitor extends RecursiveAstVisitor<void> {
  _AvoidReturningWidgetsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Skip build method
    if (node.name.lexeme == 'build') {
      super.visitMethodDeclaration(node);
      return;
    }

    final returnType = node.returnType;
    if (returnType != null && _isWidgetType(returnType)) {
      issues.add(DcmIssue(
        offset: node.name.offset,
        length: node.name.length,
        message:
            "Avoid returning widgets from methods. Consider extracting '${node.name.lexeme}' into a separate widget class.",
        severity: DiagnosticSeverity.Warning,
        ruleId: 'avoid-returning-widgets',
        suggestion: 'Extract into a separate StatelessWidget or StatefulWidget',
      ));
    }
    super.visitMethodDeclaration(node);
  }

  bool _isWidgetType(TypeAnnotation type) {
    if (type is NamedType) {
      final name = type.name2.lexeme;
      return name == 'Widget' || name.endsWith('Widget');
    }
    return false;
  }
}

/// avoid-unnecessary-setstate: Warns about unnecessary setState calls
class AvoidUnnecessarySetstateRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-setstate';

  @override
  String get description =>
      'Avoid unnecessary setState calls that do not change state.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#performance'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnnecessarySetstateVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessarySetstateVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessarySetstateVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInStateClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInStateClass = superclassName.startsWith('State');
    }
    super.visitClassDeclaration(node);
    _isInStateClass = false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isInStateClass && node.methodName.name == 'setState') {
      final arguments = node.argumentList.arguments;
      if (arguments.isNotEmpty) {
        final firstArg = arguments.first;
        if (firstArg is FunctionExpression) {
          final body = firstArg.body;
          if (body is BlockFunctionBody && body.block.statements.isEmpty) {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  'Empty setState callback. Remove this setState call as it causes unnecessary rebuilds.',
              severity: DiagnosticSeverity.Warning,
              ruleId: 'avoid-unnecessary-setstate',
              suggestion: 'Remove the empty setState call',
            ));
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// dispose-fields: Warns about disposable fields not being disposed
class DisposeFieldsRule extends DcmRule {
  static const _disposableTypes = {
    'TextEditingController',
    'AnimationController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
    'StreamController',
    'StreamSubscription',
    'Timer',
  };

  @override
  String get id => 'dispose-fields';

  @override
  String get description =>
      'Dispose all disposable fields in the dispose method.';

  @override
  String get category => 'flutter';

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
    final visitor = _DisposeFieldsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _DisposeFieldsVisitor extends RecursiveAstVisitor<void> {
  _DisposeFieldsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) {
      super.visitClassDeclaration(node);
      return;
    }

    final superclassName = extendsClause.superclass.name2.lexeme;
    if (!superclassName.startsWith('State')) {
      super.visitClassDeclaration(node);
      return;
    }

    // Find all disposable fields
    final disposableFields = <String, FieldDeclaration>{};
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final typeAnnotation = member.fields.type;
        if (typeAnnotation is NamedType) {
          final typeName = typeAnnotation.name2.lexeme;
          if (DisposeFieldsRule._disposableTypes.contains(typeName)) {
            for (final variable in member.fields.variables) {
              disposableFields[variable.name.lexeme] = member;
            }
          }
        }
      }
    }

    if (disposableFields.isEmpty) {
      super.visitClassDeclaration(node);
      return;
    }

    // Find dispose method
    MethodDeclaration? disposeMethod;
    for (final member in node.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        disposeMethod = member;
        break;
      }
    }

    if (disposeMethod == null) {
      // No dispose method found
      for (final entry in disposableFields.entries) {
        issues.add(DcmIssue(
          offset: entry.value.offset,
          length: entry.value.length,
          message:
              "Field '${entry.key}' should be disposed. Add a dispose() method.",
          severity: DiagnosticSeverity.Warning,
          ruleId: 'dispose-fields',
          suggestion: 'Add dispose() method and call ${entry.key}.dispose()',
        ));
      }
    } else {
      // Check which fields are disposed
      final disposedFields = <String>{};
      disposeMethod.body.accept(_DisposeCallFinder(disposedFields));

      for (final entry in disposableFields.entries) {
        if (!disposedFields.contains(entry.key)) {
          issues.add(DcmIssue(
            offset: entry.value.offset,
            length: entry.value.length,
            message:
                "Field '${entry.key}' is not disposed in dispose() method.",
            severity: DiagnosticSeverity.Warning,
            ruleId: 'dispose-fields',
            suggestion:
                'Add ${entry.key}.dispose() or ${entry.key}.cancel() to dispose()',
          ));
        }
      }
    }

    super.visitClassDeclaration(node);
  }
}

class _DisposeCallFinder extends RecursiveAstVisitor<void> {
  _DisposeCallFinder(this.disposedFields);

  final Set<String> disposedFields;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName == 'dispose' ||
        methodName == 'cancel' ||
        methodName == 'close') {
      final target = node.target;
      if (target is SimpleIdentifier) {
        disposedFields.add(target.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-single-child-column-or-row: Warns about Column/Row with single child
class PreferSingleChildColumnOrRowRule extends DcmRule {
  @override
  String get id => 'prefer-single-child-column-or-row';

  @override
  String get description =>
      'Prefer using Align or Center instead of Column/Row with single child.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance', '#readability'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferSingleChildVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferSingleChildVisitor extends RecursiveAstVisitor<void> {
  _PreferSingleChildVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    if (constructorName == 'Column' || constructorName == 'Row') {
      // Find children argument
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'children') {
          final value = argument.expression;
          if (value is ListLiteral && value.elements.length == 1) {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.constructorName.length,
              message:
                  '$constructorName with single child is inefficient. Consider using Align, Center, or the child widget directly.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-single-child-column-or-row',
              suggestion: 'Replace $constructorName with Align or Center',
            ));
          }
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// avoid-shrink-wrap-in-lists: Warns about shrinkWrap in scrollable lists
class AvoidShrinkWrapInListsRule extends DcmRule {
  @override
  String get id => 'avoid-shrink-wrap-in-lists';

  @override
  String get description =>
      'Avoid using shrinkWrap in ListView, GridView, etc. for performance.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#performance'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidShrinkWrapVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidShrinkWrapVisitor extends RecursiveAstVisitor<void> {
  _AvoidShrinkWrapVisitor(this.issues);

  static const _scrollableWidgets = {
    'ListView',
    'GridView',
    'CustomScrollView'
  };

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    if (_scrollableWidgets.contains(constructorName)) {
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'shrinkWrap' &&
            argument.expression is BooleanLiteral &&
            (argument.expression as BooleanLiteral).value == true) {
          issues.add(DcmIssue(
            offset: argument.offset,
            length: argument.length,
            message:
                'Avoid using shrinkWrap: true in $constructorName. It disables lazy loading and can cause performance issues.',
            severity: DiagnosticSeverity.Warning,
            ruleId: 'avoid-shrink-wrap-in-lists',
            suggestion: 'Use a fixed-height container or slivers instead',
          ));
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// prefer-const-border-radius: Warns about non-const BorderRadius
class PreferConstBorderRadiusRule extends DcmRule {
  @override
  String get id => 'prefer-const-border-radius';

  @override
  String get description => 'Prefer const BorderRadius for better performance.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferConstBorderRadiusVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferConstBorderRadiusVisitor extends RecursiveAstVisitor<void> {
  _PreferConstBorderRadiusVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    if (constructorName == 'BorderRadius') {
      if (!node.isConst && _canBeConst(node)) {
        final nodeText = content.substring(node.offset, node.end);
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'BorderRadius can be const. Add const keyword for better performance.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-const-border-radius',
          suggestion: 'Add const keyword before BorderRadius',
          fixes: [
            DcmFix(
              offset: node.offset,
              length: node.length,
              replacement: 'const $nodeText',
            ),
          ],
        ));
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _canBeConst(InstanceCreationExpression node) {
    // Check if all arguments are constant
    for (final argument in node.argumentList.arguments) {
      Expression expr;
      if (argument is NamedExpression) {
        expr = argument.expression;
      } else {
        expr = argument;
      }

      if (!_isConstExpression(expr)) {
        return false;
      }
    }
    return true;
  }

  bool _isConstExpression(Expression expr) {
    if (expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is BooleanLiteral ||
        expr is NullLiteral) {
      return true;
    }
    if (expr is InstanceCreationExpression && expr.isConst) {
      return true;
    }
    if (expr is PrefixedIdentifier || expr is SimpleIdentifier) {
      // Could be a const reference
      return true;
    }
    return false;
  }
}

/// avoid-expanded-as-spacer: Warns about using Expanded(child: SizedBox()) instead of Spacer
class AvoidExpandedAsSpacerRule extends DcmRule {
  @override
  String get id => 'avoid-expanded-as-spacer';

  @override
  String get description => 'Use Spacer instead of Expanded with empty child.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidExpandedAsSpacerVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidExpandedAsSpacerVisitor extends RecursiveAstVisitor<void> {
  _AvoidExpandedAsSpacerVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    if (constructorName == 'Expanded' || constructorName == 'Flexible') {
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'child') {
          final child = argument.expression;
          if (child is InstanceCreationExpression) {
            final childName = child.constructorName.type.name2.lexeme;
            if (childName == 'SizedBox' || childName == 'Container') {
              // Check if child is essentially empty
              if (_isEmptyWidget(child)) {
                issues.add(DcmIssue(
                  offset: node.offset,
                  length: node.length,
                  message:
                      'Use Spacer instead of $constructorName with empty $childName.',
                  severity: DiagnosticSeverity.Information,
                  ruleId: 'avoid-expanded-as-spacer',
                  suggestion: 'Replace with Spacer()',
                  fixes: [
                    DcmFix(
                      offset: node.offset,
                      length: node.length,
                      replacement: 'const Spacer()',
                    ),
                  ],
                ));
              }
            }
          }
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _isEmptyWidget(InstanceCreationExpression node) {
    // Check if widget has no meaningful content
    for (final argument in node.argumentList.arguments) {
      if (argument is NamedExpression) {
        final name = argument.name.label.name;
        if (name == 'child' || name == 'children') {
          return false;
        }
      }
    }
    return true;
  }
}

/// avoid-border-all: Warns about Border.all usage, prefer const borders
class AvoidBorderAllRule extends DcmRule {
  @override
  String get id => 'avoid-border-all';

  @override
  String get description =>
      'Consider using const Border instead of Border.all for better performance.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidBorderAllVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidBorderAllVisitor extends RecursiveAstVisitor<void> {
  _AvoidBorderAllVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'all') {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'Border') {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Consider using const Border.fromBorderSide for better performance when all sides are the same.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'avoid-border-all',
          suggestion: 'Use const Border.fromBorderSide(BorderSide(...))',
        ));
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-dedicated-media-query-methods: Warns about MediaQuery.of(context).size
class PreferDedicatedMediaQueryMethodsRule extends DcmRule {
  @override
  String get id => 'prefer-dedicated-media-query-methods';

  @override
  String get description =>
      'Prefer dedicated MediaQuery methods like MediaQuery.sizeOf(context).';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferDedicatedMediaQueryVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferDedicatedMediaQueryVisitor extends RecursiveAstVisitor<void> {
  _PreferDedicatedMediaQueryVisitor(this.issues, this.content);

  static const _propertyMethods = {
    'size': 'sizeOf',
    'padding': 'paddingOf',
    'viewInsets': 'viewInsetsOf',
    'viewPadding': 'viewPaddingOf',
    'orientation': 'orientationOf',
    'devicePixelRatio': 'devicePixelRatioOf',
    'textScaleFactor': 'textScaleFactorOf',
    'platformBrightness': 'platformBrightnessOf',
  };

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is MethodInvocation &&
        target.methodName.name == 'of' &&
        target.target is SimpleIdentifier &&
        (target.target as SimpleIdentifier).name == 'MediaQuery') {
      final property = node.propertyName.name;
      final dedicatedMethod = _propertyMethods[property];
      if (dedicatedMethod != null) {
        // Get the context argument
        final args = target.argumentList.arguments;
        String contextArg = 'context';
        if (args.isNotEmpty) {
          contextArg = content.substring(args.first.offset, args.first.end);
        }
        final replacement = 'MediaQuery.$dedicatedMethod($contextArg)';

        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Prefer using MediaQuery.$dedicatedMethod(context) instead of MediaQuery.of(context).$property for better performance.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-dedicated-media-query-methods',
          suggestion: 'Replace with MediaQuery.$dedicatedMethod(context)',
          fixes: [
            DcmFix(
              offset: node.offset,
              length: node.length,
              replacement: replacement,
            ),
          ],
        ));
      }
    }
    super.visitPropertyAccess(node);
  }
}

/// prefer-extracting-callbacks: Warns about inline callbacks in widgets
class PreferExtractingCallbacksRule extends DcmRule {
  @override
  String get id => 'prefer-extracting-callbacks';

  @override
  String get description =>
      'Extract callback functions instead of using inline closures in widget trees.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance', '#readability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferExtractingCallbacksVisitor(issues, result.lineInfo);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferExtractingCallbacksVisitor extends RecursiveAstVisitor<void> {
  _PreferExtractingCallbacksVisitor(this.issues, this.lineInfo);

  static const _callbackArguments = {
    'onPressed',
    'onTap',
    'onLongPress',
    'onChanged',
    'onSubmitted',
    'onSaved',
    'onEditingComplete',
    'onFocusChange',
    'onHighlightChanged',
    'onHover',
    'onKey',
    'onSelected',
    'onExpansionChanged',
  };

  final List<DcmIssue> issues;
  final LineInfo lineInfo;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (_callbackArguments.contains(node.name.label.name)) {
      final expr = node.expression;
      if (expr is FunctionExpression) {
        final body = expr.body;
        int lineCount = 1;
        if (body is BlockFunctionBody) {
          final startLine = lineInfo.getLocation(body.offset).lineNumber;
          final endLine = lineInfo.getLocation(body.end).lineNumber;
          lineCount = endLine - startLine;
        }

        if (lineCount > 3) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Consider extracting this callback to a separate method for better readability and performance.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-extracting-callbacks',
            suggestion: 'Extract to a named method in the class',
          ));
        }
      }
    }
    super.visitNamedExpression(node);
  }
}

// ============================================================================
// Widget Lifecycle Rules
// ============================================================================

/// always-remove-listener: Warns about listeners not being removed
class AlwaysRemoveListenerRule extends DcmRule {
  @override
  String get id => 'always-remove-listener';

  @override
  String get description =>
      'Always remove listeners in dispose() to prevent memory leaks.';

  @override
  String get category => 'flutter';

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
    final visitor = _AlwaysRemoveListenerVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AlwaysRemoveListenerVisitor extends RecursiveAstVisitor<void> {
  _AlwaysRemoveListenerVisitor(this.issues);

  final List<DcmIssue> issues;
  final _addedListeners = <_ListenerInfo>[];
  final _removedListeners = <String>{};
  bool _isInStateClass = false;
  bool _isInDisposeMethod = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInStateClass = superclassName.startsWith('State');
    }

    if (_isInStateClass) {
      _addedListeners.clear();
      _removedListeners.clear();

      // First pass: collect listeners
      super.visitClassDeclaration(node);

      // Check for missing removeListener calls
      for (final listener in _addedListeners) {
        if (!_removedListeners.contains(listener.targetName)) {
          issues.add(DcmIssue(
            offset: listener.offset,
            length: listener.length,
            message:
                "Listener added to '${listener.targetName}' is not removed in dispose().",
            severity: DiagnosticSeverity.Warning,
            ruleId: 'always-remove-listener',
            suggestion:
                'Add ${listener.targetName}.removeListener(...) in dispose()',
          ));
        }
      }
    } else {
      super.visitClassDeclaration(node);
    }

    _isInStateClass = false;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasInDispose = _isInDisposeMethod;
    _isInDisposeMethod = node.name.lexeme == 'dispose';
    super.visitMethodDeclaration(node);
    _isInDisposeMethod = wasInDispose;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isInStateClass) {
      super.visitMethodInvocation(node);
      return;
    }

    final methodName = node.methodName.name;
    final target = node.target;

    if (methodName == 'addListener' && target is SimpleIdentifier) {
      _addedListeners.add(_ListenerInfo(
        targetName: target.name,
        offset: node.offset,
        length: node.length,
      ));
    }

    if (_isInDisposeMethod &&
        methodName == 'removeListener' &&
        target is SimpleIdentifier) {
      _removedListeners.add(target.name);
    }

    super.visitMethodInvocation(node);
  }
}

class _ListenerInfo {
  _ListenerInfo({
    required this.targetName,
    required this.offset,
    required this.length,
  });

  final String targetName;
  final int offset;
  final int length;
}

/// avoid-unnecessary-stateful-widgets: Warns about StatefulWidgets without state
class AvoidUnnecessaryStatefulWidgetsRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-stateful-widgets';

  @override
  String get description =>
      'Use StatelessWidget when State class has no mutable fields.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance', '#simplicity'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnnecessaryStatefulWidgetsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessaryStatefulWidgetsVisitor
    extends RecursiveAstVisitor<void> {
  _AvoidUnnecessaryStatefulWidgetsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) {
      super.visitClassDeclaration(node);
      return;
    }

    final superclassName = extendsClause.superclass.name2.lexeme;
    if (!superclassName.startsWith('State')) {
      super.visitClassDeclaration(node);
      return;
    }

    // Check for mutable state
    bool hasMutableState = false;
    bool hasSetState = false;
    bool hasInitState = false;
    bool hasDispose = false;
    bool hasDidChangeDependencies = false;
    bool hasDidUpdateWidget = false;

    for (final member in node.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        // Check if field is not final
        if (!member.fields.isFinal) {
          hasMutableState = true;
          break;
        }
      }

      if (member is MethodDeclaration) {
        final name = member.name.lexeme;
        if (name == 'initState') hasInitState = true;
        if (name == 'dispose') hasDispose = true;
        if (name == 'didChangeDependencies') hasDidChangeDependencies = true;
        if (name == 'didUpdateWidget') hasDidUpdateWidget = true;
      }
    }

    // Check for setState calls
    final setStateChecker = _SetStateChecker();
    node.accept(setStateChecker);
    hasSetState = setStateChecker.hasSetState;

    // If no mutable state and no setState calls and no lifecycle methods
    if (!hasMutableState &&
        !hasSetState &&
        !hasInitState &&
        !hasDispose &&
        !hasDidChangeDependencies &&
        !hasDidUpdateWidget) {
      issues.add(DcmIssue(
        offset: node.name.offset,
        length: node.name.length,
        message:
            "State class '${node.name.lexeme}' has no mutable state. Consider using StatelessWidget.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'avoid-unnecessary-stateful-widgets',
        suggestion: 'Convert to StatelessWidget',
      ));
    }

    super.visitClassDeclaration(node);
  }
}

class _SetStateChecker extends RecursiveAstVisitor<void> {
  bool hasSetState = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      hasSetState = true;
    }
    super.visitMethodInvocation(node);
  }
}

/// avoid-recursive-widget-calls: Warns about recursive widget building
class AvoidRecursiveWidgetCallsRule extends DcmRule {
  @override
  String get id => 'avoid-recursive-widget-calls';

  @override
  String get description =>
      'Avoid recursive widget calls that can cause stack overflow.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Error;

  @override
  List<String> get tags => ['#correctness', '#crash'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidRecursiveWidgetCallsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidRecursiveWidgetCallsVisitor extends RecursiveAstVisitor<void> {
  _AvoidRecursiveWidgetCallsVisitor(this.issues);

  final List<DcmIssue> issues;
  String? _currentClassName;
  bool _isInBuildMethod = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _currentClassName = node.name.lexeme;
    super.visitClassDeclaration(node);
    _currentClassName = null;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuild = _isInBuildMethod;
    _isInBuildMethod = node.name.lexeme == 'build';
    super.visitMethodDeclaration(node);
    _isInBuildMethod = wasBuild;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isInBuildMethod && _currentClassName != null) {
      final createdTypeName = node.constructorName.type.name2.lexeme;
      if (createdTypeName == _currentClassName) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              "Recursive widget instantiation of '$_currentClassName' in build method can cause stack overflow.",
          severity: DiagnosticSeverity.Error,
          ruleId: 'avoid-recursive-widget-calls',
          suggestion:
              'Remove the recursive call or add a termination condition',
        ));
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// use-key-in-widget-constructors: Warns about missing key parameter
class UseKeyInWidgetConstructorsRule extends DcmRule {
  @override
  String get id => 'use-key-in-widget-constructors';

  @override
  String get description =>
      'Widget constructors should have a key parameter for efficient rebuilding.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance', '#best-practice'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _UseKeyInWidgetConstructorsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _UseKeyInWidgetConstructorsVisitor extends RecursiveAstVisitor<void> {
  _UseKeyInWidgetConstructorsVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isWidgetClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isWidgetClass = superclassName == 'StatelessWidget' ||
          superclassName == 'StatefulWidget';
    }
    super.visitClassDeclaration(node);
    _isWidgetClass = false;
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!_isWidgetClass) {
      super.visitConstructorDeclaration(node);
      return;
    }

    // Check if key parameter exists
    bool hasKeyParam = false;
    for (final param in node.parameters.parameters) {
      String? paramName;
      if (param is SimpleFormalParameter) {
        paramName = param.name?.lexeme;
      } else if (param is DefaultFormalParameter) {
        final innerParam = param.parameter;
        if (innerParam is SimpleFormalParameter) {
          paramName = innerParam.name?.lexeme;
        }
      } else if (param is SuperFormalParameter) {
        paramName = param.name.lexeme;
      }

      if (paramName == 'key') {
        hasKeyParam = true;
        break;
      }
    }

    if (!hasKeyParam) {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.parameters.length,
        message:
            'Widget constructor should have a key parameter for efficient rebuilding.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'use-key-in-widget-constructors',
        suggestion: 'Add {super.key} parameter to constructor',
      ));
    }

    super.visitConstructorDeclaration(node);
  }
}

// ============================================================================
// Performance Rules
// ============================================================================

/// avoid-unnecessary-containers: Warns about Container without styling
class AvoidUnnecessaryContainersRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-containers';

  @override
  String get description =>
      'Avoid using Container when it has no decoration, constraints, or alignment.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance', '#readability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnnecessaryContainersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessaryContainersVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessaryContainersVisitor(this.issues);

  final List<DcmIssue> issues;

  static const _meaningfulProperties = {
    'decoration',
    'foregroundDecoration',
    'constraints',
    'margin',
    'padding',
    'color',
    'width',
    'height',
    'alignment',
    'transform',
    'transformAlignment',
    'clipBehavior',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    if (constructorName == 'Container') {
      bool hasMeaningfulProperty = false;

      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression) {
          final name = argument.name.label.name;
          if (_meaningfulProperties.contains(name)) {
            hasMeaningfulProperty = true;
            break;
          }
        }
      }

      if (!hasMeaningfulProperty) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Container with only child is unnecessary. Use the child widget directly.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'avoid-unnecessary-containers',
          suggestion: 'Remove the Container and use child directly',
        ));
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// prefer-const-constructors: Warns about non-const widget constructors
class PreferConstConstructorsRule extends DcmRule {
  @override
  String get id => 'prefer-const-constructors';

  @override
  String get description =>
      'Use const constructors where possible for better performance.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#performance'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferConstConstructorsVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferConstConstructorsVisitor extends RecursiveAstVisitor<void> {
  _PreferConstConstructorsVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  // Common Flutter widgets that can often be const
  static const _commonConstWidgets = {
    'SizedBox',
    'Padding',
    'Center',
    'Align',
    'AspectRatio',
    'FittedBox',
    'FractionallySizedBox',
    'Divider',
    'VerticalDivider',
    'Spacer',
    'Icon',
    'Text',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.isConst) {
      super.visitInstanceCreationExpression(node);
      return;
    }

    final constructorName = node.constructorName.type.name2.lexeme;

    // Check common const widgets
    if (_commonConstWidgets.contains(constructorName)) {
      if (_canBeConst(node)) {
        final nodeText = content.substring(node.offset, node.end);
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              '$constructorName can be const. Add const for better performance.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-const-constructors',
          suggestion: 'Add const keyword before $constructorName',
          fixes: [
            DcmFix(
              offset: node.offset,
              length: node.length,
              replacement: 'const $nodeText',
            ),
          ],
        ));
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  bool _canBeConst(InstanceCreationExpression node) {
    for (final argument in node.argumentList.arguments) {
      Expression expr;
      if (argument is NamedExpression) {
        expr = argument.expression;
      } else {
        expr = argument;
      }

      if (!_isConstExpression(expr)) {
        return false;
      }
    }
    return true;
  }

  bool _isConstExpression(Expression expr) {
    if (expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is BooleanLiteral ||
        expr is NullLiteral ||
        expr is StringLiteral) {
      return true;
    }
    if (expr is InstanceCreationExpression && expr.isConst) {
      return true;
    }
    if (expr is PrefixedIdentifier) {
      // Could be an enum or const reference
      return true;
    }
    if (expr is SimpleIdentifier) {
      // Could be a const reference
      return true;
    }
    if (expr is ListLiteral && expr.isConst) {
      return true;
    }
    return false;
  }
}

/// avoid-print-in-release: Warns about print statements in release code
class AvoidPrintInReleaseRule extends DcmRule {
  @override
  String get id => 'avoid-print-in-release';

  @override
  String get description =>
      'Avoid print() in release code. Use debugPrint() or logging framework.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#production'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidPrintInReleaseVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidPrintInReleaseVisitor extends RecursiveAstVisitor<void> {
  _AvoidPrintInReleaseVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInAssertOrKDebugMode = false;

  @override
  void visitAssertStatement(AssertStatement node) {
    final wasInAssert = _isInAssertOrKDebugMode;
    _isInAssertOrKDebugMode = true;
    super.visitAssertStatement(node);
    _isInAssertOrKDebugMode = wasInAssert;
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check if condition is kDebugMode
    final condition = node.expression;
    if (condition is SimpleIdentifier && condition.name == 'kDebugMode') {
      final wasInDebug = _isInAssertOrKDebugMode;
      _isInAssertOrKDebugMode = true;
      node.thenStatement.accept(this);
      _isInAssertOrKDebugMode = wasInDebug;
      final elseStatement = node.elseStatement;
      if (elseStatement != null) {
        elseStatement.accept(this);
      }
      return;
    }
    super.visitIfStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isInAssertOrKDebugMode && node.methodName.name == 'print') {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Avoid print() in release code. Use debugPrint() or a logging framework.',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'avoid-print-in-release',
        suggestion: 'Replace with debugPrint() or wrap in kDebugMode check',
      ));
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-sized-box-shrink-expand: Suggests SizedBox.shrink/expand
class PreferSizedBoxShrinkExpandRule extends DcmRule {
  @override
  String get id => 'prefer-sized-box-shrink-expand';

  @override
  String get description =>
      'Prefer SizedBox.shrink() and SizedBox.expand() over explicit zero/infinity dimensions.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#best-practice'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferSizedBoxShrinkExpandVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferSizedBoxShrinkExpandVisitor extends RecursiveAstVisitor<void> {
  _PreferSizedBoxShrinkExpandVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    final namedConstructor = node.constructorName.name?.name;

    if (constructorName == 'SizedBox' && namedConstructor == null) {
      double? width;
      double? height;
      bool hasChild = false;

      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression) {
          final name = argument.name.label.name;
          final expr = argument.expression;

          if (name == 'child') {
            hasChild = true;
          } else if (name == 'width') {
            width = _extractDouble(expr);
          } else if (name == 'height') {
            height = _extractDouble(expr);
          }
        }
      }

      // Check for SizedBox.shrink pattern: width: 0, height: 0
      if (width == 0 && height == 0 && !hasChild) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Use SizedBox.shrink() instead of SizedBox(width: 0, height: 0).',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-sized-box-shrink-expand',
          suggestion: 'Replace with SizedBox.shrink()',
          fixes: [
            DcmFix(
              offset: node.offset,
              length: node.length,
              replacement: 'const SizedBox.shrink()',
            ),
          ],
        ));
      }

      // Check for SizedBox.expand pattern: width/height = infinity
      if ((width != null && width == double.infinity) &&
          (height != null && height == double.infinity)) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Use SizedBox.expand() instead of SizedBox with infinite dimensions.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-sized-box-shrink-expand',
          suggestion: 'Replace with SizedBox.expand()',
          fixes: [
            DcmFix(
              offset: node.offset,
              length: node.length,
              replacement: hasChild
                  ? 'SizedBox.expand(child: /* existing child */)'
                  : 'const SizedBox.expand()',
            ),
          ],
        ));
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  double? _extractDouble(Expression expr) {
    if (expr is IntegerLiteral) {
      return expr.value?.toDouble();
    }
    if (expr is DoubleLiteral) {
      return expr.value;
    }
    if (expr is PrefixedIdentifier) {
      if (expr.prefix.name == 'double' && expr.identifier.name == 'infinity') {
        return double.infinity;
      }
    }
    return null;
  }
}

// ============================================================================
// UI/UX Rules
// ============================================================================

/// prefer-correct-edge-insets-constructor: Suggests better EdgeInsets constructors
class PreferCorrectEdgeInsetsConstructorRule extends DcmRule {
  @override
  String get id => 'prefer-correct-edge-insets-constructor';

  @override
  String get description =>
      'Use the most specific EdgeInsets constructor for the use case.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#best-practice'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferCorrectEdgeInsetsConstructorVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferCorrectEdgeInsetsConstructorVisitor
    extends RecursiveAstVisitor<void> {
  _PreferCorrectEdgeInsetsConstructorVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    final namedConstructor = node.constructorName.name?.name;

    if (constructorName == 'EdgeInsets' && namedConstructor == 'only') {
      double? left, top, right, bottom;

      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression) {
          final name = argument.name.label.name;
          final value = _extractDouble(argument.expression);

          switch (name) {
            case 'left':
              left = value;
              break;
            case 'top':
              top = value;
              break;
            case 'right':
              right = value;
              break;
            case 'bottom':
              bottom = value;
              break;
          }
        }
      }

      // Check for .all pattern
      if (left != null &&
          left == top &&
          top == right &&
          right == bottom &&
          bottom != null) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Use EdgeInsets.all($left) instead of EdgeInsets.only with equal values.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-correct-edge-insets-constructor',
          suggestion: 'Replace with EdgeInsets.all($left)',
        ));
      }
      // Check for .symmetric pattern
      else if (left != null && left == right && top != null && top == bottom) {
        if (left == 0 && top != 0) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Use EdgeInsets.symmetric(vertical: $top) for vertical-only padding.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-correct-edge-insets-constructor',
            suggestion: 'Replace with EdgeInsets.symmetric(vertical: $top)',
          ));
        } else if (top == 0 && left != 0) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Use EdgeInsets.symmetric(horizontal: $left) for horizontal-only padding.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-correct-edge-insets-constructor',
            suggestion: 'Replace with EdgeInsets.symmetric(horizontal: $left)',
          ));
        } else if (left != 0 && top != 0) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Use EdgeInsets.symmetric(horizontal: $left, vertical: $top) for symmetric padding.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-correct-edge-insets-constructor',
            suggestion:
                'Replace with EdgeInsets.symmetric(horizontal: $left, vertical: $top)',
          ));
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  double? _extractDouble(Expression expr) {
    if (expr is IntegerLiteral) {
      return expr.value?.toDouble();
    }
    if (expr is DoubleLiteral) {
      return expr.value;
    }
    return null;
  }
}

/// avoid-hardcoded-colors: Warns about hardcoded color values
class AvoidHardcodedColorsRule extends DcmRule {
  @override
  String get id => 'avoid-hardcoded-colors';

  @override
  String get description =>
      'Avoid hardcoded colors. Use Theme colors or define in a centralized location.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#maintainability', '#theming'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidHardcodedColorsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidHardcodedColorsVisitor extends RecursiveAstVisitor<void> {
  _AvoidHardcodedColorsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;
    final namedConstructor = node.constructorName.name?.name;

    if (constructorName == 'Color' && namedConstructor == null) {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Avoid hardcoded Color values. Define colors centrally or use Theme colors.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'avoid-hardcoded-colors',
        suggestion: 'Use Theme.of(context).colorScheme or define in AppColors',
      ));
    }

    if (constructorName == 'Color' && namedConstructor == 'fromARGB') {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Avoid hardcoded Color.fromARGB. Define colors centrally for maintainability.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'avoid-hardcoded-colors',
        suggestion: 'Use Theme colors or define in a centralized location',
      ));
    }

    if (constructorName == 'Color' && namedConstructor == 'fromRGBO') {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Avoid hardcoded Color.fromRGBO. Define colors centrally for maintainability.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'avoid-hardcoded-colors',
        suggestion: 'Use Theme colors or define in a centralized location',
      ));
    }

    super.visitInstanceCreationExpression(node);
  }
}

/// avoid-hardcoded-strings: Warns about hardcoded UI strings
class AvoidHardcodedStringsRule extends DcmRule {
  @override
  String get id => 'avoid-hardcoded-strings';

  @override
  String get description =>
      'Avoid hardcoded strings in UI. Use localization or constants.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => false; // Opt-in rule

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#i18n', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidHardcodedStringsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidHardcodedStringsVisitor extends RecursiveAstVisitor<void> {
  _AvoidHardcodedStringsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;

    if (constructorName == 'Text') {
      for (final argument in node.argumentList.arguments) {
        if (argument is! NamedExpression) {
          // First positional argument is the text
          if (argument is SimpleStringLiteral) {
            final value = argument.value;
            // Ignore short strings, punctuation, or empty strings
            if (value.length > 3 && !_isPunctuation(value)) {
              issues.add(DcmIssue(
                offset: argument.offset,
                length: argument.length,
                message:
                    'Hardcoded string in Text widget. Consider using localization.',
                severity: DiagnosticSeverity.Information,
                ruleId: 'avoid-hardcoded-strings',
                suggestion: 'Use localization or define in a constants file',
              ));
            }
          }
          break;
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  bool _isPunctuation(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ||
        RegExp(r'^[\s\.,!?\-:;/\\|@#\$%^&*()+=\[\]{}]+$').hasMatch(trimmed);
  }
}

/// prefer-safe-area: Suggests using SafeArea for edge widgets
class PreferSafeAreaRule extends DcmRule {
  @override
  String get id => 'prefer-safe-area';

  @override
  String get description =>
      'Wrap Scaffold body with SafeArea to handle notches and system UI.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => false; // Opt-in rule

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#ux', '#accessibility'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferSafeAreaVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferSafeAreaVisitor extends RecursiveAstVisitor<void> {
  _PreferSafeAreaVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;

    if (constructorName == 'Scaffold') {
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression && argument.name.label.name == 'body') {
          final body = argument.expression;
          if (body is InstanceCreationExpression) {
            final bodyTypeName = body.constructorName.type.name2.lexeme;
            // Check if body is wrapped in SafeArea
            if (bodyTypeName != 'SafeArea') {
              issues.add(DcmIssue(
                offset: argument.offset,
                length: argument.length,
                message:
                    'Consider wrapping Scaffold body with SafeArea to handle notches and system UI.',
                severity: DiagnosticSeverity.Information,
                ruleId: 'prefer-safe-area',
                suggestion: 'Wrap body with SafeArea widget',
              ));
            }
          }
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }
}

// ============================================================================
// Best Practice Rules
// ============================================================================

/// avoid-setstate-in-build: Warns about setState in build method
class AvoidSetStateInBuildRule extends DcmRule {
  @override
  String get id => 'avoid-setstate-in-build';

  @override
  String get description =>
      'Avoid calling setState directly in build method which causes infinite rebuilds.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Error;

  @override
  List<String> get tags => ['#correctness', '#crash'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidSetStateInBuildVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidSetStateInBuildVisitor extends RecursiveAstVisitor<void> {
  _AvoidSetStateInBuildVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInBuildMethod = false;
  bool _isInCallback = false;
  bool _isInStateClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInStateClass = superclassName.startsWith('State');
    }
    super.visitClassDeclaration(node);
    _isInStateClass = false;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuild = _isInBuildMethod;
    _isInBuildMethod = node.name.lexeme == 'build' && _isInStateClass;
    super.visitMethodDeclaration(node);
    _isInBuildMethod = wasBuild;
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
    if (_isInBuildMethod &&
        !_isInCallback &&
        node.methodName.name == 'setState') {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message: 'Calling setState in build method causes infinite rebuilds.',
        severity: DiagnosticSeverity.Error,
        ruleId: 'avoid-setstate-in-build',
        suggestion: 'Move setState call to a callback or lifecycle method',
      ));
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-intl-name: Warns about missing Intl.message name parameter
class PreferIntlNameRule extends DcmRule {
  @override
  String get id => 'prefer-intl-name';

  @override
  String get description =>
      'Intl.message should have a name parameter for proper extraction.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#i18n', '#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferIntlNameVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferIntlNameVisitor extends RecursiveAstVisitor<void> {
  _PreferIntlNameVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'message') {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'Intl') {
        bool hasName = false;

        for (final argument in node.argumentList.arguments) {
          if (argument is NamedExpression &&
              argument.name.label.name == 'name') {
            hasName = true;
            break;
          }
        }

        if (!hasName) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Intl.message should have a name parameter for proper message extraction.',
            severity: DiagnosticSeverity.Warning,
            ruleId: 'prefer-intl-name',
            suggestion: 'Add name: parameter to Intl.message',
          ));
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// avoid-wrapping-in-padding: Suggests using parent padding
class AvoidWrappingInPaddingRule extends DcmRule {
  @override
  String get id => 'avoid-wrapping-in-padding';

  @override
  String get description =>
      'Avoid wrapping in Padding when parent widget supports padding parameter.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#simplicity'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidWrappingInPaddingVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidWrappingInPaddingVisitor extends RecursiveAstVisitor<void> {
  _AvoidWrappingInPaddingVisitor(this.issues);

  final List<DcmIssue> issues;

  // Widgets that have a contentPadding or padding parameter
  static const _widgetsWithPadding = {
    'ListTile',
    'ExpansionTile',
    'Card',
    'TextField',
    'TextFormField',
    'DropdownButton',
    'DropdownButtonFormField',
    'InputDecorator',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;

    if (constructorName == 'Padding') {
      // Check what the child is
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'child') {
          final child = argument.expression;
          if (child is InstanceCreationExpression) {
            final childName = child.constructorName.type.name2.lexeme;
            if (_widgetsWithPadding.contains(childName)) {
              issues.add(DcmIssue(
                offset: node.offset,
                length: constructorName.length + 8, // "Padding("
                message:
                    'Avoid Padding around $childName. Use its padding/contentPadding parameter instead.',
                severity: DiagnosticSeverity.Information,
                ruleId: 'avoid-wrapping-in-padding',
                suggestion: 'Use $childName\'s padding parameter',
              ));
            }
          }
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }
}

/// check-for-equals-in-render-object-setters: Warns about missing equality check in setters
class CheckForEqualsInRenderObjectSettersRule extends DcmRule {
  @override
  String get id => 'check-for-equals-in-render-object-setters';

  @override
  String get description =>
      'RenderObject setters should check for equality before updating and marking needs layout/paint.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#performance', '#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _CheckForEqualsInRenderObjectSettersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _CheckForEqualsInRenderObjectSettersVisitor
    extends RecursiveAstVisitor<void> {
  _CheckForEqualsInRenderObjectSettersVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInRenderObjectClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInRenderObjectClass = superclassName.startsWith('Render') ||
          superclassName == 'RenderBox' ||
          superclassName == 'RenderSliver' ||
          superclassName == 'RenderProxyBox';
    }
    super.visitClassDeclaration(node);
    _isInRenderObjectClass = false;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!_isInRenderObjectClass || !node.isSetter) {
      super.visitMethodDeclaration(node);
      return;
    }

    // Check if setter body has equality check
    final body = node.body;
    bool hasEqualityCheck = false;
    bool hasMarkNeedsCall = false;

    if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        // Look for if (_field == value) return; pattern
        if (statement is IfStatement) {
          final condition = statement.expression;
          if (condition is BinaryExpression &&
              condition.operator.lexeme == '==') {
            hasEqualityCheck = true;
          }
        }

        // Look for markNeedsLayout or markNeedsPaint
        if (statement is ExpressionStatement) {
          final expr = statement.expression;
          if (expr is MethodInvocation) {
            final name = expr.methodName.name;
            if (name == 'markNeedsLayout' || name == 'markNeedsPaint') {
              hasMarkNeedsCall = true;
            }
          }
        }
      }
    }

    if (hasMarkNeedsCall && !hasEqualityCheck) {
      issues.add(DcmIssue(
        offset: node.name.offset,
        length: node.name.length,
        message:
            "Setter '${node.name.lexeme}' calls markNeeds* without equality check. This may cause unnecessary rebuilds.",
        severity: DiagnosticSeverity.Warning,
        ruleId: 'check-for-equals-in-render-object-setters',
        suggestion: 'Add "if (_field == value) return;" before assignment',
      ));
    }

    super.visitMethodDeclaration(node);
  }
}

/// prefer-widget-private-members: Warns about public members in widget classes
class PreferWidgetPrivateMembersRule extends DcmRule {
  @override
  String get id => 'prefer-widget-private-members';

  @override
  String get description =>
      'Widget fields should generally be private. Use constructor parameters for public API.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => false; // Opt-in rule

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#encapsulation', '#architecture'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferWidgetPrivateMembersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferWidgetPrivateMembersVisitor extends RecursiveAstVisitor<void> {
  _PreferWidgetPrivateMembersVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInWidgetClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      _isInWidgetClass = superclassName == 'StatelessWidget' ||
          superclassName == 'StatefulWidget';
    }
    super.visitClassDeclaration(node);
    _isInWidgetClass = false;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!_isInWidgetClass || node.isStatic) {
      super.visitFieldDeclaration(node);
      return;
    }

    for (final variable in node.fields.variables) {
      final name = variable.name.lexeme;
      // Check if public (not starting with _) and not final
      if (!name.startsWith('_') && !node.fields.isFinal) {
        issues.add(DcmIssue(
          offset: variable.name.offset,
          length: variable.name.length,
          message:
              "Widget field '$name' should be private or final. Widgets should be immutable.",
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-widget-private-members',
          suggestion: 'Make field final or rename to _$name',
        ));
      }
    }

    super.visitFieldDeclaration(node);
  }
}

/// avoid-late-context: Warns about late BuildContext
class AvoidLateContextRule extends DcmRule {
  @override
  String get id => 'avoid-late-context';

  @override
  String get description =>
      'Avoid storing BuildContext in late fields as it may become invalid.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#lifecycle'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidLateContextVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidLateContextVisitor extends RecursiveAstVisitor<void> {
  _AvoidLateContextVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.fields.isLate) {
      final type = node.fields.type;
      if (type is NamedType && type.name2.lexeme == 'BuildContext') {
        for (final variable in node.fields.variables) {
          issues.add(DcmIssue(
            offset: variable.name.offset,
            length: variable.name.length,
            message:
                "Avoid storing BuildContext in late field '${variable.name.lexeme}'. Context may become invalid.",
            severity: DiagnosticSeverity.Warning,
            ruleId: 'avoid-late-context',
            suggestion: 'Pass context as method parameter instead',
          ));
        }
      }
    }
    super.visitFieldDeclaration(node);
  }
}

/// prefer-null-aware-method-calls: Suggests ?. for nullable method calls
class PreferNullAwareMethodCallsRule extends DcmRule {
  @override
  String get id => 'prefer-null-aware-method-calls';

  @override
  String get description =>
      'Use null-aware method call (?.) instead of null check then call.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#null-safety'];

  @override
  bool get hasAutoFix => true;

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferNullAwareMethodCallsVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferNullAwareMethodCallsVisitor extends RecursiveAstVisitor<void> {
  _PreferNullAwareMethodCallsVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitIfStatement(IfStatement node) {
    final condition = node.expression;

    // Check for: if (x != null) x.method()
    if (condition is BinaryExpression && condition.operator.lexeme == '!=') {
      final right = condition.rightOperand;
      if (right is NullLiteral) {
        final left = condition.leftOperand;
        if (left is SimpleIdentifier) {
          final varName = left.name;

          // Check if then statement uses this variable
          final thenStatement = node.thenStatement;
          if (thenStatement is ExpressionStatement) {
            final expr = thenStatement.expression;
            if (expr is MethodInvocation) {
              final target = expr.target;
              if (target is SimpleIdentifier && target.name == varName) {
                // Get the method call arguments
                final argsText = content.substring(
                  expr.argumentList.offset,
                  expr.argumentList.end,
                );
                final replacement =
                    '$varName?.${expr.methodName.name}$argsText;';

                issues.add(DcmIssue(
                  offset: node.offset,
                  length: node.length,
                  message:
                      'Use null-aware call: $varName?.${expr.methodName.name}() instead of null check.',
                  severity: DiagnosticSeverity.Information,
                  ruleId: 'prefer-null-aware-method-calls',
                  suggestion:
                      'Replace with $varName?.${expr.methodName.name}()',
                  fixes: [
                    DcmFix(
                      offset: node.offset,
                      length: node.length,
                      replacement: replacement,
                    ),
                  ],
                ));
              }
            }
          }
        }
      }
    }

    super.visitIfStatement(node);
  }
}

/// avoid-using-expanded-on-scrollable: Warns about Expanded in scrollable
class AvoidUsingExpandedOnScrollableRule extends DcmRule {
  @override
  String get id => 'avoid-using-expanded-on-scrollable';

  @override
  String get description =>
      'Avoid using Expanded/Flexible with scrollable widgets inside Column/Row.';

  @override
  String get category => 'flutter';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#layout'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUsingExpandedOnScrollableVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUsingExpandedOnScrollableVisitor extends RecursiveAstVisitor<void> {
  _AvoidUsingExpandedOnScrollableVisitor(this.issues);

  final List<DcmIssue> issues;

  static const _scrollableWidgets = {
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
    'NestedScrollView',
    'PageView',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName.type.name2.lexeme;

    if (constructorName == 'Expanded' || constructorName == 'Flexible') {
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'child') {
          final child = argument.expression;
          if (child is InstanceCreationExpression) {
            final childName = child.constructorName.type.name2.lexeme;
            if (_scrollableWidgets.contains(childName)) {
              issues.add(DcmIssue(
                offset: node.offset,
                length: node.length,
                message:
                    '$constructorName around $childName is unnecessary. Scrollable widgets determine their own size.',
                severity: DiagnosticSeverity.Warning,
                ruleId: 'avoid-using-expanded-on-scrollable',
                suggestion:
                    'Remove $constructorName and use $childName directly, or use shrinkWrap: true',
              ));
            }
          }
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }
}

/// Get all Flutter rules
List<DcmRule> getFlutterRules() => [
      // Original 10 rules
      AvoidReturningWidgetsRule(),
      AvoidUnnecessarySetstateRule(),
      DisposeFieldsRule(),
      PreferSingleChildColumnOrRowRule(),
      AvoidShrinkWrapInListsRule(),
      PreferConstBorderRadiusRule(),
      AvoidExpandedAsSpacerRule(),
      AvoidBorderAllRule(),
      PreferDedicatedMediaQueryMethodsRule(),
      PreferExtractingCallbacksRule(),
      // Widget lifecycle rules
      AlwaysRemoveListenerRule(),
      AvoidUnnecessaryStatefulWidgetsRule(),
      AvoidRecursiveWidgetCallsRule(),
      UseKeyInWidgetConstructorsRule(),
      // Performance rules
      AvoidUnnecessaryContainersRule(),
      PreferConstConstructorsRule(),
      AvoidPrintInReleaseRule(),
      PreferSizedBoxShrinkExpandRule(),
      // UI/UX rules
      PreferCorrectEdgeInsetsConstructorRule(),
      AvoidHardcodedColorsRule(),
      AvoidHardcodedStringsRule(),
      PreferSafeAreaRule(),
      // Best practice rules
      AvoidSetStateInBuildRule(),
      PreferIntlNameRule(),
      AvoidWrappingInPaddingRule(),
      CheckForEqualsInRenderObjectSettersRule(),
      PreferWidgetPrivateMembersRule(),
      AvoidLateContextRule(),
      PreferNullAwareMethodCallsRule(),
      AvoidUsingExpandedOnScrollableRule(),
    ];
