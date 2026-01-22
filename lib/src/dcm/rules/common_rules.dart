import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-dynamic: Warns when `dynamic` type is used
class AvoidDynamicRule extends DcmRule {
  @override
  String get id => 'avoid-dynamic';

  @override
  String get description => 'Avoid using dynamic type to ensure type safety.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidDynamicVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidDynamicVisitor extends RecursiveAstVisitor<void> {
  _AvoidDynamicVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitNamedType(NamedType node) {
    if (node.name2.lexeme == 'dynamic') {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            "Avoid using 'dynamic' type. Consider using a specific type or 'Object?'.",
        severity: DiagnosticSeverity.Warning,
        ruleId: 'avoid-dynamic',
        suggestion: "Replace 'dynamic' with a specific type",
      ));
    }
    super.visitNamedType(node);
  }
}

/// avoid-non-null-assertion: Warns about non-null assertions (!)
class AvoidNonNullAssertionRule extends DcmRule {
  @override
  String get id => 'avoid-non-null-assertion';

  @override
  String get description => 'Avoid using non-null assertion operator (!).';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#security'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidNonNullAssertionVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidNonNullAssertionVisitor extends RecursiveAstVisitor<void> {
  _AvoidNonNullAssertionVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.lexeme == '!') {
      issues.add(DcmIssue(
        offset: node.operator.offset,
        length: 1,
        message:
            'Avoid using non-null assertion operator (!). Consider using null-aware operators or null checks.',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'avoid-non-null-assertion',
        suggestion: 'Use ?. or ?? operators instead',
      ));
    }
    super.visitPostfixExpression(node);
  }
}

/// avoid-long-functions: Warns about functions that are too long
class AvoidLongFunctionsRule extends DcmRule {
  static const int defaultMaxLines = 50;

  @override
  String get id => 'avoid-long-functions';

  @override
  String get description => 'Avoid functions that are too long.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#maintainability', '#readability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final ruleConfig = config.getRuleConfig(id);
    final maxLines = (ruleConfig['max-lines'] as int?) ?? defaultMaxLines;

    final visitor =
        _AvoidLongFunctionsVisitor(issues, maxLines, result.lineInfo);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidLongFunctionsVisitor extends RecursiveAstVisitor<void> {
  _AvoidLongFunctionsVisitor(this.issues, this.maxLines, this.lineInfo);

  final List<DcmIssue> issues;
  final int maxLines;
  final LineInfo lineInfo;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkFunction(node.name.offset, node.name.length, node.name.lexeme,
        node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkFunction(
        node.name.offset, node.name.length, node.name.lexeme, node.body);
    super.visitMethodDeclaration(node);
  }

  void _checkFunction(
      int nameOffset, int nameLength, String name, FunctionBody body) {
    final startLine = lineInfo.getLocation(body.offset).lineNumber;
    final endLine = lineInfo.getLocation(body.end).lineNumber;
    final lines = endLine - startLine;

    if (lines > maxLines) {
      issues.add(DcmIssue(
        offset: nameOffset,
        length: nameLength,
        message:
            "Function '$name' has $lines lines which exceeds the maximum of $maxLines lines.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'avoid-long-functions',
        suggestion: 'Consider breaking this function into smaller functions',
      ));
    }
  }
}

/// avoid-nested-conditional-expressions: Warns about nested ternary operators
class AvoidNestedConditionalExpressionsRule extends DcmRule {
  @override
  String get id => 'avoid-nested-conditional-expressions';

  @override
  String get description =>
      'Avoid nested conditional expressions for better readability.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#readability', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidNestedConditionalVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidNestedConditionalVisitor extends RecursiveAstVisitor<void> {
  _AvoidNestedConditionalVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    if (node.thenExpression is ConditionalExpression ||
        node.elseExpression is ConditionalExpression) {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Avoid nested conditional expressions. Consider using if-else statements instead.',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'avoid-nested-conditional-expressions',
        suggestion: 'Replace with if-else statements for better readability',
      ));
    }
    super.visitConditionalExpression(node);
  }
}

/// prefer-trailing-comma: Recommends trailing commas in multi-line collections
class PreferTrailingCommaRule extends DcmRule {
  @override
  String get id => 'prefer-trailing-comma';

  @override
  String get description =>
      'Prefer trailing commas for better version control diffs.';

  @override
  String get category => 'common';

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
    final visitor =
        _PreferTrailingCommaVisitor(issues, result.lineInfo, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferTrailingCommaVisitor extends RecursiveAstVisitor<void> {
  _PreferTrailingCommaVisitor(this.issues, this.lineInfo, this.content);

  final List<DcmIssue> issues;
  final LineInfo lineInfo;
  final String content;

  @override
  void visitArgumentList(ArgumentList node) {
    _checkTrailingComma(node.arguments, node.rightParenthesis.offset);
    super.visitArgumentList(node);
  }

  @override
  void visitListLiteral(ListLiteral node) {
    _checkTrailingComma(node.elements, node.rightBracket.offset);
    super.visitListLiteral(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    _checkTrailingComma(node.elements, node.rightBracket.offset);
    super.visitSetOrMapLiteral(node);
  }

  void _checkTrailingComma(NodeList<AstNode> elements, int closingOffset) {
    if (elements.isEmpty) return;

    final lastElement = elements.last;
    final lastElementLine = lineInfo.getLocation(lastElement.end).lineNumber;
    final closingLine = lineInfo.getLocation(closingOffset).lineNumber;

    // Multi-line check
    if (lastElementLine != closingLine) {
      final afterLastElement =
          content.substring(lastElement.end, closingOffset).trim();
      if (!afterLastElement.startsWith(',')) {
        issues.add(DcmIssue(
          offset: lastElement.end,
          length: 1,
          message:
              'Add a trailing comma for better formatting and version control diffs.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-trailing-comma',
          suggestion: 'Add trailing comma after the last element',
        ));
      }
    }
  }
}

/// no-empty-block: Warns about empty blocks
class NoEmptyBlockRule extends DcmRule {
  @override
  String get id => 'no-empty-block';

  @override
  String get description => 'Avoid empty blocks.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _NoEmptyBlockVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _NoEmptyBlockVisitor extends RecursiveAstVisitor<void> {
  _NoEmptyBlockVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitBlock(Block node) {
    if (node.statements.isEmpty) {
      // Check if it's intentionally empty (has comment)
      final blockContent = content
          .substring(node.leftBracket.end, node.rightBracket.offset)
          .trim();
      if (blockContent.isEmpty || !blockContent.contains('//')) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Empty block found. Consider adding implementation or a comment explaining why it is empty.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'no-empty-block',
        ));
      }
    }
    super.visitBlock(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (node.body.statements.isEmpty) {
      final blockContent = content
          .substring(node.body.leftBracket.end, node.body.rightBracket.offset)
          .trim();
      if (blockContent.isEmpty || !blockContent.contains('//')) {
        issues.add(DcmIssue(
          offset: node.body.offset,
          length: node.body.length,
          message:
              'Empty catch block. Consider logging the error or adding a comment explaining why it is ignored.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'no-empty-block',
        ));
      }
    }
    super.visitCatchClause(node);
  }
}

/// no-boolean-literal-compare: Warns about comparing with boolean literals
class NoBooleanLiteralCompareRule extends DcmRule {
  @override
  String get id => 'no-boolean-literal-compare';

  @override
  String get description => 'Avoid comparing with boolean literals.';

  @override
  String get category => 'common';

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
    final visitor = _NoBooleanLiteralCompareVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _NoBooleanLiteralCompareVisitor extends RecursiveAstVisitor<void> {
  _NoBooleanLiteralCompareVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '==' || node.operator.lexeme == '!=') {
      final isLeftBool = node.leftOperand is BooleanLiteral;
      final isRightBool = node.rightOperand is BooleanLiteral;

      if (isLeftBool || isRightBool) {
        final boolLiteral = isLeftBool
            ? node.leftOperand as BooleanLiteral
            : node.rightOperand as BooleanLiteral;
        final otherOperand = isLeftBool ? node.rightOperand : node.leftOperand;
        final otherText =
            content.substring(otherOperand.offset, otherOperand.end);

        // Determine replacement
        // x == true -> x, x == false -> !x
        // x != true -> !x, x != false -> x
        String replacement;
        final isTrue = boolLiteral.value;
        final isEquals = node.operator.lexeme == '==';

        if ((isEquals && isTrue) || (!isEquals && !isTrue)) {
          replacement = otherText;
        } else {
          replacement = '!$otherText';
        }

        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Avoid comparing with boolean literals. Use the expression directly.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'no-boolean-literal-compare',
          suggestion: isEquals
              ? 'Use the boolean expression directly'
              : 'Use the negated expression (!expr)',
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
    super.visitBinaryExpression(node);
  }
}

/// prefer-first: Recommends using .first instead of [0]
class PreferFirstRule extends DcmRule {
  @override
  String get id => 'prefer-first';

  @override
  String get description => 'Prefer using .first instead of [0].';

  @override
  String get category => 'common';

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
    final visitor = _PreferFirstVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferFirstVisitor extends RecursiveAstVisitor<void> {
  _PreferFirstVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitIndexExpression(IndexExpression node) {
    if (node.index is IntegerLiteral) {
      final literal = node.index as IntegerLiteral;
      if (literal.value == 0) {
        // Get the target expression (the list/collection)
        final target = node.target;
        if (target != null) {
          final targetText = content.substring(target.offset, target.end);
          final replacement = '$targetText.first';

          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message: "Prefer using '.first' instead of '[0]'.",
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-first',
            suggestion: 'Replace [0] with .first',
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
    super.visitIndexExpression(node);
  }
}

/// prefer-last: Recommends using .last for last element access
class PreferLastRule extends DcmRule {
  @override
  String get id => 'prefer-last';

  @override
  String get description =>
      'Prefer using .last for accessing the last element.';

  @override
  String get category => 'common';

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
    final visitor = _PreferLastVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferLastVisitor extends RecursiveAstVisitor<void> {
  _PreferLastVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitIndexExpression(IndexExpression node) {
    // Check for pattern like list[list.length - 1]
    if (node.index is BinaryExpression) {
      final binary = node.index as BinaryExpression;
      if (binary.operator.lexeme == '-' &&
          binary.rightOperand is IntegerLiteral &&
          (binary.rightOperand as IntegerLiteral).value == 1) {
        if (binary.leftOperand is PrefixedIdentifier) {
          final prefixed = binary.leftOperand as PrefixedIdentifier;
          if (prefixed.identifier.name == 'length') {
            final target = node.target;
            if (target != null) {
              final targetText = content.substring(target.offset, target.end);
              final replacement = '$targetText.last';

              issues.add(DcmIssue(
                offset: node.offset,
                length: node.length,
                message: "Prefer using '.last' instead of '[length - 1]'.",
                severity: DiagnosticSeverity.Information,
                ruleId: 'prefer-last',
                suggestion: 'Replace [length - 1] with .last',
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
    super.visitIndexExpression(node);
  }
}

/// avoid-late-keyword: Warns about using late keyword
class AvoidLateKeywordRule extends DcmRule {
  @override
  String get id => 'avoid-late-keyword';

  @override
  String get description =>
      'Avoid using late keyword which can lead to runtime errors.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => false;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#correctness', '#security'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidLateKeywordVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidLateKeywordVisitor extends RecursiveAstVisitor<void> {
  _AvoidLateKeywordVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (node.lateKeyword != null) {
      issues.add(DcmIssue(
        offset: node.lateKeyword!.offset,
        length: node.lateKeyword!.length,
        message:
            "Avoid using 'late' keyword. Consider using nullable types or initializing in the constructor.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'avoid-late-keyword',
        suggestion:
            'Use nullable type with null check or initialize in constructor',
      ));
    }
    super.visitVariableDeclarationList(node);
  }
}

/// avoid-redundant-async: Warns about async functions without await
class AvoidRedundantAsyncRule extends DcmRule {
  @override
  String get id => 'avoid-redundant-async';

  @override
  String get description => 'Avoid async functions that do not use await.';

  @override
  String get category => 'common';

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
    final visitor = _AvoidRedundantAsyncVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidRedundantAsyncVisitor extends RecursiveAstVisitor<void> {
  _AvoidRedundantAsyncVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkAsyncFunction(node.functionExpression.body, node.name.offset,
        node.name.length, node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkAsyncFunction(
        node.body, node.name.offset, node.name.length, node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  void _checkAsyncFunction(
      FunctionBody body, int nameOffset, int nameLength, String name) {
    if (body.isAsynchronous && !body.isSynchronous) {
      final hasAwait = _containsAwait(body);
      if (!hasAwait) {
        issues.add(DcmIssue(
          offset: nameOffset,
          length: nameLength,
          message:
              "Function '$name' is async but does not use await. Consider removing async or using await.",
          severity: DiagnosticSeverity.Information,
          ruleId: 'avoid-redundant-async',
          suggestion: 'Remove async keyword or add await expression',
        ));
      }
    }
  }

  bool _containsAwait(AstNode node) {
    bool found = false;
    node.accept(_AwaitFinder((n) => found = true));
    return found;
  }
}

class _AwaitFinder extends RecursiveAstVisitor<void> {
  _AwaitFinder(this.onFound);

  final void Function(AstNode) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(node);
    super.visitAwaitExpression(node);
  }
}

/// avoid-unused-parameters: Warns about unused function parameters
class AvoidUnusedParametersRule extends DcmRule {
  @override
  String get id => 'avoid-unused-parameters';

  @override
  String get description => 'Avoid unused function parameters.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnusedParametersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnusedParametersVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnusedParametersVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkParameters(
        node.functionExpression.parameters, node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Skip override methods
    if (_hasOverrideAnnotation(node.metadata)) {
      super.visitMethodDeclaration(node);
      return;
    }
    _checkParameters(node.parameters, node.body);
    super.visitMethodDeclaration(node);
  }

  bool _hasOverrideAnnotation(NodeList<Annotation> metadata) {
    return metadata.any((a) => a.name.name == 'override');
  }

  void _checkParameters(FormalParameterList? parameters, FunctionBody body) {
    if (parameters == null) return;

    final paramNames = <String, FormalParameter>{};
    for (final param in parameters.parameters) {
      final name = param.name?.lexeme;
      if (name != null && !name.startsWith('_')) {
        paramNames[name] = param;
      }
    }

    if (paramNames.isEmpty) return;

    // Find all identifier usages in the body
    final usedNames = <String>{};
    body.accept(_IdentifierCollector(usedNames));

    for (final entry in paramNames.entries) {
      if (!usedNames.contains(entry.key)) {
        issues.add(DcmIssue(
          offset: entry.value.offset,
          length: entry.value.length,
          message:
              "Parameter '${entry.key}' is not used. Consider removing it or prefixing with underscore.",
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-unused-parameters',
          suggestion: "Rename to '_${entry.key}' or remove the parameter",
        ));
      }
    }
  }
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector(this.usedNames);

  final Set<String> usedNames;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    usedNames.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// double-literal-format: Enforces consistent double literal format
class DoubleLiteralFormatRule extends DcmRule {
  @override
  String get id => 'double-literal-format';

  @override
  String get description => 'Enforce consistent double literal format.';

  @override
  String get category => 'common';

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
    final visitor = _DoubleLiteralFormatVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _DoubleLiteralFormatVisitor extends RecursiveAstVisitor<void> {
  _DoubleLiteralFormatVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    final literal = node.literal.lexeme;

    // Check for leading decimal point (e.g., .5 instead of 0.5)
    if (literal.startsWith('.')) {
      final fixed = '0$literal';
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Add leading zero before decimal point: $fixed instead of $literal',
        severity: DiagnosticSeverity.Information,
        ruleId: 'double-literal-format',
        suggestion: 'Use $fixed',
        fixes: [
          DcmFix(
            offset: node.offset,
            length: node.length,
            replacement: fixed,
          ),
        ],
      ));
    }

    // Check for trailing decimal point (e.g., 1. instead of 1.0)
    if (literal.endsWith('.')) {
      final fixed = '${literal}0';
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Add trailing zero after decimal point: $fixed instead of $literal',
        severity: DiagnosticSeverity.Information,
        ruleId: 'double-literal-format',
        suggestion: 'Use $fixed',
        fixes: [
          DcmFix(
            offset: node.offset,
            length: node.length,
            replacement: fixed,
          ),
        ],
      ));
    }

    super.visitDoubleLiteral(node);
  }
}

/// prefer-immediate-return: Recommends immediate return instead of variable assignment
class PreferImmediateReturnRule extends DcmRule {
  @override
  String get id => 'prefer-immediate-return';

  @override
  String get description =>
      'Prefer returning the expression directly instead of assigning to a variable.';

  @override
  String get category => 'common';

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
    final visitor =
        _PreferImmediateReturnVisitor(issues, content, result.lineInfo);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferImmediateReturnVisitor extends RecursiveAstVisitor<void> {
  _PreferImmediateReturnVisitor(this.issues, this.content, this.lineInfo);

  final List<DcmIssue> issues;
  final String content;
  final LineInfo lineInfo;

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    final statements = node.block.statements;
    if (statements.length >= 2) {
      final secondToLast = statements[statements.length - 2];
      final last = statements.last;

      if (secondToLast is VariableDeclarationStatement &&
          last is ReturnStatement) {
        final declarations = secondToLast.variables.variables;
        if (declarations.length == 1) {
          final declaration = declarations.first;
          final returnExpr = last.expression;

          if (returnExpr is SimpleIdentifier &&
              returnExpr.name == declaration.name.lexeme &&
              declaration.initializer != null) {
            // Get the initializer expression
            final initializerText = content.substring(
              declaration.initializer!.offset,
              declaration.initializer!.end,
            );

            issues.add(DcmIssue(
              offset: secondToLast.offset,
              length: last.end - secondToLast.offset,
              message:
                  "Prefer returning the expression directly instead of assigning to '${declaration.name.lexeme}'.",
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-immediate-return',
              suggestion: 'Return the expression directly',
              fixes: [
                DcmFix(
                  offset: secondToLast.offset,
                  length: last.end - secondToLast.offset,
                  replacement: 'return $initializerText;',
                ),
              ],
            ));
          }
        }
      }
    }
    super.visitBlockFunctionBody(node);
  }
}

// ============================================================================
// Expression-Related Rules
// ============================================================================

/// prefer-conditional-expressions: Prefer ternary over simple if-else
class PreferConditionalExpressionsRule extends DcmRule {
  @override
  String get id => 'prefer-conditional-expressions';

  @override
  String get description =>
      'Prefer conditional expressions over simple if-else statements for assignments.';

  @override
  String get category => 'common';

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
    final visitor = _PreferConditionalExpressionsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferConditionalExpressionsVisitor extends RecursiveAstVisitor<void> {
  _PreferConditionalExpressionsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitIfStatement(IfStatement node) {
    // Check for simple if-else with single assignment in each branch
    final thenStatement = node.thenStatement;
    final elseStatement = node.elseStatement;

    if (elseStatement != null && elseStatement is! IfStatement) {
      final thenAssignment = _getSingleAssignment(thenStatement);
      final elseAssignment = _getSingleAssignment(elseStatement);

      if (thenAssignment != null && elseAssignment != null) {
        // Check if they assign to the same variable
        final thenTarget = _getAssignmentTarget(thenAssignment);
        final elseTarget = _getAssignmentTarget(elseAssignment);

        if (thenTarget != null &&
            elseTarget != null &&
            thenTarget == elseTarget) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Prefer using conditional expression instead of if-else for simple assignments.',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-conditional-expressions',
            suggestion: 'Use: $thenTarget = condition ? thenValue : elseValue;',
          ));
        }
      }
    }
    super.visitIfStatement(node);
  }

  ExpressionStatement? _getSingleAssignment(Statement statement) {
    if (statement is ExpressionStatement &&
        statement.expression is AssignmentExpression) {
      return statement;
    }
    if (statement is Block && statement.statements.length == 1) {
      return _getSingleAssignment(statement.statements.first);
    }
    return null;
  }

  String? _getAssignmentTarget(ExpressionStatement statement) {
    final assignment = statement.expression as AssignmentExpression;
    final left = assignment.leftHandSide;
    if (left is SimpleIdentifier) {
      return left.name;
    }
    return null;
  }
}

/// no-equal-then-else: Warns when if and else have identical code
class NoEqualThenElseRule extends DcmRule {
  @override
  String get id => 'no-equal-then-else';

  @override
  String get description => 'Avoid if-else statements with identical branches.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _NoEqualThenElseVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _NoEqualThenElseVisitor extends RecursiveAstVisitor<void> {
  _NoEqualThenElseVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitIfStatement(IfStatement node) {
    final elseStatement = node.elseStatement;
    if (elseStatement != null) {
      final thenCode =
          content.substring(node.thenStatement.offset, node.thenStatement.end);
      final elseCode =
          content.substring(elseStatement.offset, elseStatement.end);

      if (thenCode.trim() == elseCode.trim()) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'If-else statement has identical branches. The condition has no effect.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'no-equal-then-else',
          suggestion: 'Remove the if-else and keep only the body',
        ));
      }
    }
    super.visitIfStatement(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    final thenCode =
        content.substring(node.thenExpression.offset, node.thenExpression.end);
    final elseCode =
        content.substring(node.elseExpression.offset, node.elseExpression.end);

    if (thenCode.trim() == elseCode.trim()) {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Conditional expression has identical branches. The condition has no effect.',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'no-equal-then-else',
        suggestion: 'Use the expression directly without the condition',
      ));
    }
    super.visitConditionalExpression(node);
  }
}

/// avoid-unnecessary-type-assertions: Warns about redundant type checks
class AvoidUnnecessaryTypeAssertionsRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-type-assertions';

  @override
  String get description =>
      'Avoid unnecessary type assertions when the type is already known.';

  @override
  String get category => 'common';

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
    final visitor = _AvoidUnnecessaryTypeAssertionsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessaryTypeAssertionsVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessaryTypeAssertionsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitIsExpression(IsExpression node) {
    final expressionType = node.expression.staticType;
    final testedType = node.type.type;

    if (expressionType != null && testedType != null) {
      // Check if expression is already of the tested type
      if (expressionType == testedType ||
          (testedType.isDartCoreObject && node.notOperator == null)) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Unnecessary type assertion. The expression is already of type ${expressionType.getDisplayString()}.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'avoid-unnecessary-type-assertions',
          suggestion: 'Remove the type assertion',
        ));
      }
    }
    super.visitIsExpression(node);
  }
}

/// avoid-unnecessary-type-casts: Warns about redundant type casts
class AvoidUnnecessaryTypeCastsRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-type-casts';

  @override
  String get description =>
      'Avoid unnecessary type casts when the type is already correct.';

  @override
  String get category => 'common';

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
    final visitor = _AvoidUnnecessaryTypeCastsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessaryTypeCastsVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessaryTypeCastsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitAsExpression(AsExpression node) {
    final expressionType = node.expression.staticType;
    final targetType = node.type.type;

    if (expressionType != null && targetType != null) {
      if (expressionType == targetType) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Unnecessary type cast. The expression is already of type ${expressionType.getDisplayString()}.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'avoid-unnecessary-type-casts',
          suggestion: 'Remove the type cast',
        ));
      }
    }
    super.visitAsExpression(node);
  }
}

/// avoid-unrelated-type-assertions: Warns about type checks that will always fail
class AvoidUnrelatedTypeAssertionsRule extends DcmRule {
  @override
  String get id => 'avoid-unrelated-type-assertions';

  @override
  String get description =>
      'Avoid type assertions between unrelated types that will always fail.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnrelatedTypeAssertionsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnrelatedTypeAssertionsVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnrelatedTypeAssertionsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitIsExpression(IsExpression node) {
    final expressionType = node.expression.staticType;
    final testedType = node.type.type;

    if (expressionType != null && testedType != null) {
      // Check for clearly unrelated types (both are concrete and unrelated)
      if (_areUnrelatedTypes(
          expressionType.toString(), testedType.toString())) {
        final notStr = node.notOperator != null ? '!' : '';
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Type assertion "is$notStr ${testedType.getDisplayString()}" will always be ${node.notOperator != null ? "true" : "false"} for ${expressionType.getDisplayString()}.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-unrelated-type-assertions',
          suggestion: 'Review the type check logic',
        ));
      }
    }
    super.visitIsExpression(node);
  }

  bool _areUnrelatedTypes(String type1, String type2) {
    // Simple heuristic for clearly unrelated types
    final unrelatedPairs = [
      {'int', 'String'},
      {'double', 'String'},
      {'bool', 'String'},
      {'int', 'bool'},
      {'double', 'bool'},
      {'List', 'Map'},
      {'Set', 'Map'},
    ];

    for (final pair in unrelatedPairs) {
      if ((type1.startsWith(pair.first) && type2.startsWith(pair.last)) ||
          (type1.startsWith(pair.last) && type2.startsWith(pair.first))) {
        return true;
      }
    }
    return false;
  }
}

/// binary-expression-operand-order: Suggests consistent operand ordering
class BinaryExpressionOperandOrderRule extends DcmRule {
  @override
  String get id => 'binary-expression-operand-order';

  @override
  String get description =>
      'Prefer consistent ordering of operands in binary expressions (variable on left).';

  @override
  String get category => 'common';

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
    final visitor = _BinaryExpressionOperandOrderVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _BinaryExpressionOperandOrderVisitor extends RecursiveAstVisitor<void> {
  _BinaryExpressionOperandOrderVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '==' || op == '!=') {
      // Suggest putting literal on right side (Yoda condition)
      if (node.leftOperand is Literal && node.rightOperand is! Literal) {
        final leftText =
            content.substring(node.leftOperand.offset, node.leftOperand.end);
        final rightText =
            content.substring(node.rightOperand.offset, node.rightOperand.end);
        final replacement = '$rightText $op $leftText';

        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Prefer variable on the left side of comparison for readability.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'binary-expression-operand-order',
          suggestion: 'Swap operands: variable $op literal',
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
    super.visitBinaryExpression(node);
  }
}

/// prefer-moving-to-variable: Suggests extracting complex expressions
class PreferMovingToVariableRule extends DcmRule {
  static const int defaultComplexityThreshold = 3;

  @override
  String get id => 'prefer-moving-to-variable';

  @override
  String get description =>
      'Consider extracting complex expressions into named variables.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final ruleConfig = config.getRuleConfig(id);
    final threshold = (ruleConfig['complexity-threshold'] as int?) ??
        defaultComplexityThreshold;
    final visitor = _PreferMovingToVariableVisitor(issues, threshold);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferMovingToVariableVisitor extends RecursiveAstVisitor<void> {
  _PreferMovingToVariableVisitor(this.issues, this.complexityThreshold);

  final List<DcmIssue> issues;
  final int complexityThreshold;
  final Set<int> _reportedOffsets = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _checkComplexExpression(node);
    super.visitMethodInvocation(node);
  }

  void _checkComplexExpression(Expression node) {
    if (_reportedOffsets.contains(node.offset)) return;

    int depth = 0;
    Expression? current = node;
    while (current != null) {
      if (current is MethodInvocation) {
        depth++;
        current = current.target;
      } else if (current is PrefixedIdentifier) {
        depth++;
        current = null;
      } else if (current is PropertyAccess) {
        depth++;
        current = current.target;
      } else {
        break;
      }
    }

    if (depth >= complexityThreshold) {
      _reportedOffsets.add(node.offset);
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Complex chained expression (depth: $depth). Consider extracting to a named variable.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'prefer-moving-to-variable',
        suggestion: 'Extract to a well-named variable for clarity',
      ));
    }
  }
}

/// avoid-unnecessary-nullable: Warns about nullable types that are never null
class AvoidUnnecessaryNullableRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-nullable';

  @override
  String get description =>
      'Avoid declaring variables as nullable when they are always assigned non-null values.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#correctness', '#type-safety'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnnecessaryNullableVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessaryNullableVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessaryNullableVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    if (parent is VariableDeclarationList && parent.type != null) {
      final typeAnnotation = parent.type;
      if (typeAnnotation is NamedType && typeAnnotation.question != null) {
        // It's a nullable type
        final initializer = node.initializer;
        if (initializer != null) {
          // Check if initializer is a non-null literal or constructor
          if (_isDefinitelyNonNull(initializer)) {
            issues.add(DcmIssue(
              offset: node.offset,
              length: node.length,
              message:
                  "Variable '${node.name.lexeme}' is declared nullable but initialized with non-null value.",
              severity: DiagnosticSeverity.Information,
              ruleId: 'avoid-unnecessary-nullable',
              suggestion: 'Consider removing the ? from the type',
            ));
          }
        }
      }
    }
    super.visitVariableDeclaration(node);
  }

  bool _isDefinitelyNonNull(Expression expr) {
    if (expr is Literal && expr is! NullLiteral) return true;
    if (expr is InstanceCreationExpression) return true;
    if (expr is ListLiteral) return true;
    if (expr is SetOrMapLiteral) return true;
    if (expr is ThrowExpression) return true;
    return false;
  }
}

/// newline-before-return: Suggests newline before return statements
class NewlineBeforeReturnRule extends DcmRule {
  @override
  String get id => 'newline-before-return';

  @override
  String get description =>
      'Add a blank line before return statements for better readability.';

  @override
  String get category => 'common';

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
    final visitor =
        _NewlineBeforeReturnVisitor(issues, result.lineInfo, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _NewlineBeforeReturnVisitor extends RecursiveAstVisitor<void> {
  _NewlineBeforeReturnVisitor(this.issues, this.lineInfo, this.content);

  final List<DcmIssue> issues;
  final LineInfo lineInfo;
  final String content;

  @override
  void visitBlock(Block node) {
    final statements = node.statements;
    for (int i = 1; i < statements.length; i++) {
      if (statements[i] is ReturnStatement) {
        final prevStatement = statements[i - 1];
        final prevLine = lineInfo.getLocation(prevStatement.end).lineNumber;
        final returnLine =
            lineInfo.getLocation(statements[i].offset).lineNumber;

        // Check if there's no blank line before return
        if (returnLine - prevLine == 1) {
          // Skip if previous statement is also a return or a single line
          if (prevStatement is! ReturnStatement) {
            final lineStart = lineInfo.getOffsetOfLine(returnLine - 1);

            issues.add(DcmIssue(
              offset: statements[i].offset,
              length: statements[i].length,
              message: 'Add a blank line before the return statement.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'newline-before-return',
              suggestion: 'Insert blank line before return',
              fixes: [
                DcmFix(
                  offset: lineStart,
                  length: 0,
                  replacement: '\n',
                ),
              ],
            ));
          }
        }
      }
    }
    super.visitBlock(node);
  }
}

/// prefer-commenting-analyzer-ignores: Suggests comments for analyzer ignores
class PreferCommentingAnalyzerIgnoresRule extends DcmRule {
  @override
  String get id => 'prefer-commenting-analyzer-ignores';

  @override
  String get description =>
      'Add comments explaining why analyzer rules are being ignored.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#documentation', '#maintainability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('// ignore:') || line.contains('// ignore_for_file:')) {
        // Check if there's an explanation after the ignore directive
        final ignoreMatch =
            RegExp(r'//\s*ignore[_for_file]*:\s*\S+').firstMatch(line);
        if (ignoreMatch != null) {
          final afterIgnore = line.substring(ignoreMatch.end).trim();
          if (afterIgnore.isEmpty || !afterIgnore.startsWith('//')) {
            final offset = content.indexOf(lines[i]);
            issues.add(DcmIssue(
              offset: offset >= 0 ? offset : 0,
              length: lines[i].length,
              message:
                  'Add a comment explaining why this analyzer rule is being ignored.',
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-commenting-analyzer-ignores',
              suggestion:
                  'Add explanation: // ignore: rule_name // reason here',
            ));
          }
        }
      }
    }
    return issues;
  }
}

// ============================================================================
// Statement-Related Rules
// ============================================================================

/// avoid-throw-in-catch-block: Warns about re-throwing with new exception in catch
class AvoidThrowInCatchBlockRule extends DcmRule {
  @override
  String get id => 'avoid-throw-in-catch-block';

  @override
  String get description =>
      'Avoid throwing new exceptions in catch blocks that lose the original stack trace.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness', '#debugging'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidThrowInCatchBlockVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidThrowInCatchBlockVisitor extends RecursiveAstVisitor<void> {
  _AvoidThrowInCatchBlockVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInCatchBlock = false;
  String? _catchExceptionName;

  @override
  void visitCatchClause(CatchClause node) {
    final wasInCatch = _isInCatchBlock;
    final prevExceptionName = _catchExceptionName;

    _isInCatchBlock = true;
    _catchExceptionName = node.exceptionParameter?.name.lexeme;

    super.visitCatchClause(node);

    _isInCatchBlock = wasInCatch;
    _catchExceptionName = prevExceptionName;
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (_isInCatchBlock) {
      final thrown = node.expression;
      // Check if throwing a new exception (not rethrow)
      if (thrown is InstanceCreationExpression) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Throwing a new exception in catch block loses the original stack trace. Use rethrow or preserve the original exception.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-throw-in-catch-block',
          suggestion:
              'Use rethrow, or wrap the original exception with Error.throwWithStackTrace',
        ));
      }
    }
    super.visitThrowExpression(node);
  }
}

/// avoid-unnecessary-setters: Warns about setters that just assign to field
class AvoidUnnecessarySettersRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-setters';

  @override
  String get description =>
      'Avoid setters that only assign to a field without additional logic.';

  @override
  String get category => 'common';

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
    final visitor = _AvoidUnnecessarySettersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessarySettersVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessarySettersVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isSetter) {
      final body = node.body;
      if (body is BlockFunctionBody) {
        final statements = body.block.statements;
        if (statements.length == 1) {
          final statement = statements.first;
          if (statement is ExpressionStatement &&
              statement.expression is AssignmentExpression) {
            final assignment = statement.expression as AssignmentExpression;
            if (assignment.operator.lexeme == '=') {
              final left = assignment.leftHandSide;
              final right = assignment.rightHandSide;

              // Check if it's just assigning parameter to field
              if (left is PrefixedIdentifier &&
                  left.prefix.name == 'this' &&
                  right is SimpleIdentifier) {
                issues.add(DcmIssue(
                  offset: node.offset,
                  length: node.length,
                  message:
                      "Setter '${node.name.lexeme}' only assigns to a field. Consider making the field public instead.",
                  severity: DiagnosticSeverity.Information,
                  ruleId: 'avoid-unnecessary-setters',
                  suggestion: 'Make the field public or add validation logic',
                ));
              }
            }
          }
        }
      } else if (body is ExpressionFunctionBody) {
        final expr = body.expression;
        if (expr is AssignmentExpression && expr.operator.lexeme == '=') {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                "Setter '${node.name.lexeme}' only assigns to a field. Consider making the field public instead.",
            severity: DiagnosticSeverity.Information,
            ruleId: 'avoid-unnecessary-setters',
            suggestion: 'Make the field public or add validation logic',
          ));
        }
      }
    }
    super.visitMethodDeclaration(node);
  }
}

/// avoid-unnecessary-getters: Warns about getters that just return a field
class AvoidUnnecessaryGettersRule extends DcmRule {
  @override
  String get id => 'avoid-unnecessary-getters';

  @override
  String get description =>
      'Avoid getters that only return a field without additional logic.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => false;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#simplicity'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidUnnecessaryGettersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidUnnecessaryGettersVisitor extends RecursiveAstVisitor<void> {
  _AvoidUnnecessaryGettersVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter) {
      final body = node.body;
      if (body is ExpressionFunctionBody) {
        final expr = body.expression;
        if (expr is SimpleIdentifier && expr.name.startsWith('_')) {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                "Getter '${node.name.lexeme}' only returns a private field. Consider making the field public.",
            severity: DiagnosticSeverity.Information,
            ruleId: 'avoid-unnecessary-getters',
            suggestion: 'Make the field public or add computation logic',
          ));
        }
      }
    }
    super.visitMethodDeclaration(node);
  }
}

/// prefer-switch-case-enum: Prefer switch for enum comparisons
class PreferSwitchCaseEnumRule extends DcmRule {
  @override
  String get id => 'prefer-switch-case-enum';

  @override
  String get description =>
      'Prefer switch statements over multiple if-else for enum comparisons.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#exhaustiveness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferSwitchCaseEnumVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferSwitchCaseEnumVisitor extends RecursiveAstVisitor<void> {
  _PreferSwitchCaseEnumVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitIfStatement(IfStatement node) {
    int enumComparisons = 0;
    String? commonVariable;
    IfStatement? current = node;

    while (current != null) {
      final comparison = _getEnumComparison(current.expression);
      if (comparison != null) {
        if (commonVariable == null) {
          commonVariable = comparison;
          enumComparisons++;
        } else if (commonVariable == comparison) {
          enumComparisons++;
        }
      }

      final elseStmt = current.elseStatement;
      if (elseStmt is IfStatement) {
        current = elseStmt;
      } else {
        current = null;
      }
    }

    if (enumComparisons >= 3) {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Multiple if-else comparisons on $commonVariable. Consider using a switch statement for better exhaustiveness checking.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'prefer-switch-case-enum',
        suggestion: 'Replace with switch statement',
      ));
    }

    super.visitIfStatement(node);
  }

  String? _getEnumComparison(Expression expr) {
    if (expr is BinaryExpression && expr.operator.lexeme == '==') {
      final left = expr.leftOperand;
      if (left is SimpleIdentifier) {
        return left.name;
      }
      if (left is PrefixedIdentifier) {
        return '${left.prefix.name}.${left.identifier.name}';
      }
    }
    return null;
  }
}

/// avoid-positional-boolean-parameters: Warns about positional boolean params
class AvoidPositionalBooleanParametersRule extends DcmRule {
  @override
  String get id => 'avoid-positional-boolean-parameters';

  @override
  String get description =>
      'Avoid positional boolean parameters which reduce code readability.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#api-design'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidPositionalBooleanParametersVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidPositionalBooleanParametersVisitor
    extends RecursiveAstVisitor<void> {
  _AvoidPositionalBooleanParametersVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (final param in node.parameters) {
      if (param is SimpleFormalParameter && !param.isNamed) {
        final type = param.type;
        if (type is NamedType && type.name2.lexeme == 'bool') {
          issues.add(DcmIssue(
            offset: param.offset,
            length: param.length,
            message:
                "Positional boolean parameter '${param.name?.lexeme}'. Use named parameter for clarity.",
            severity: DiagnosticSeverity.Information,
            ruleId: 'avoid-positional-boolean-parameters',
            suggestion:
                'Change to named parameter: {required bool ${param.name?.lexeme}}',
          ));
        }
      }
    }
    super.visitFormalParameterList(node);
  }
}

/// avoid-global-state: Warns about mutable global state
class AvoidGlobalStateRule extends DcmRule {
  @override
  String get id => 'avoid-global-state';

  @override
  String get description =>
      'Avoid mutable global state which makes code harder to test and reason about.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#maintainability', '#testability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidGlobalStateVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidGlobalStateVisitor extends RecursiveAstVisitor<void> {
  _AvoidGlobalStateVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      // Check if it's mutable (not final or const)
      if (!node.variables.isFinal && !node.variables.isConst) {
        issues.add(DcmIssue(
          offset: variable.name.offset,
          length: variable.name.length,
          message:
              "Mutable global variable '${variable.name.lexeme}'. Global state makes code harder to test and reason about.",
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-global-state',
          suggestion: 'Make it final/const, or encapsulate in a class',
        ));
      }
    }
    super.visitTopLevelVariableDeclaration(node);
  }
}

/// avoid-duplicate-exports: Warns about duplicate export directives
class AvoidDuplicateExportsRule extends DcmRule {
  @override
  String get id => 'avoid-duplicate-exports';

  @override
  String get description => 'Avoid duplicate export directives.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final exports = <String, ExportDirective>{};

    for (final directive in result.unit.directives) {
      if (directive is ExportDirective) {
        final uri = directive.uri.stringValue;
        if (uri != null) {
          if (exports.containsKey(uri)) {
            issues.add(DcmIssue(
              offset: directive.offset,
              length: directive.length,
              message: "Duplicate export of '$uri'.",
              severity: DiagnosticSeverity.Warning,
              ruleId: 'avoid-duplicate-exports',
              suggestion: 'Remove the duplicate export directive',
            ));
          } else {
            exports[uri] = directive;
          }
        }
      }
    }
    return issues;
  }
}

// ============================================================================
// Collection-Related Rules
// ============================================================================

/// avoid-collection-methods-with-unrelated-types: Warns about type mismatches
class AvoidCollectionMethodsWithUnrelatedTypesRule extends DcmRule {
  @override
  String get id => 'avoid-collection-methods-with-unrelated-types';

  @override
  String get description =>
      'Avoid calling collection methods with unrelated types.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidCollectionMethodsWithUnrelatedTypesVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidCollectionMethodsWithUnrelatedTypesVisitor
    extends RecursiveAstVisitor<void> {
  _AvoidCollectionMethodsWithUnrelatedTypesVisitor(this.issues);

  final List<DcmIssue> issues;

  static const _methodsToCheck = {'contains', 'remove', 'indexOf', 'lookup'};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_methodsToCheck.contains(node.methodName.name)) {
      final targetType = node.target?.staticType;
      if (targetType != null && node.argumentList.arguments.isNotEmpty) {
        final argType = node.argumentList.arguments.first.staticType;
        if (argType != null && targetType.toString().contains('<')) {
          // Extract generic type from collection
          final genericMatch =
              RegExp(r'<([^>]+)>').firstMatch(targetType.toString());
          if (genericMatch != null) {
            final elementType = genericMatch.group(1);
            final argTypeName = argType.toString();

            // Simple unrelated type check
            if (elementType != null &&
                !argTypeName.contains(elementType) &&
                !elementType.contains(argTypeName) &&
                elementType != 'dynamic' &&
                argTypeName != 'dynamic' &&
                elementType != 'Object' &&
                argTypeName != 'Object') {
              issues.add(DcmIssue(
                offset: node.offset,
                length: node.length,
                message:
                    "Calling '${node.methodName.name}' with type '$argTypeName' on collection of '$elementType'. This will always return false/null/-1.",
                severity: DiagnosticSeverity.Warning,
                ruleId: 'avoid-collection-methods-with-unrelated-types',
                suggestion:
                    'Ensure the argument type matches the collection element type',
              ));
            }
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-iterable-methods: Prefer Iterable methods over manual loops
class PreferIterableMethodsRule extends DcmRule {
  @override
  String get id => 'prefer-iterable-methods';

  @override
  String get description =>
      'Prefer using Iterable methods (map, where, etc.) over manual loops.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#readability', '#functional'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _PreferIterableMethodsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferIterableMethodsVisitor extends RecursiveAstVisitor<void> {
  _PreferIterableMethodsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitForStatement(ForStatement node) {
    final body = node.body;

    // Check for simple transformation pattern
    if (body is Block && body.statements.length == 1) {
      final statement = body.statements.first;
      if (statement is ExpressionStatement) {
        final expr = statement.expression;
        if (expr is MethodInvocation && expr.methodName.name == 'add') {
          issues.add(DcmIssue(
            offset: node.offset,
            length: node.length,
            message:
                'Consider using .map() or .where() instead of a for loop with add().',
            severity: DiagnosticSeverity.Information,
            ruleId: 'prefer-iterable-methods',
            suggestion: 'Use list.map((item) => transform(item)).toList()',
          ));
        }
      }
    }

    super.visitForStatement(node);
  }
}

/// avoid-cascade-after-if-null: Warns about cascades after ?? operator
class AvoidCascadeAfterIfNullRule extends DcmRule {
  @override
  String get id => 'avoid-cascade-after-if-null';

  @override
  String get description =>
      'Avoid using cascade operator after null-coalescing operator.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidCascadeAfterIfNullVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidCascadeAfterIfNullVisitor extends RecursiveAstVisitor<void> {
  _AvoidCascadeAfterIfNullVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitCascadeExpression(CascadeExpression node) {
    if (node.target is BinaryExpression) {
      final binary = node.target as BinaryExpression;
      if (binary.operator.lexeme == '??') {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              'Cascade after ?? operator may have unexpected behavior. The cascade applies to the right operand, not the full expression.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-cascade-after-if-null',
          suggestion:
              'Wrap the ?? expression in parentheses: (a ?? b)..method()',
        ));
      }
    }
    super.visitCascadeExpression(node);
  }
}

/// prefer-spread-collections: Prefer spread operator over addAll
class PreferSpreadCollectionsRule extends DcmRule {
  @override
  String get id => 'prefer-spread-collections';

  @override
  String get description =>
      'Prefer using spread operator (...) over addAll for combining collections.';

  @override
  String get category => 'common';

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
    final visitor = _PreferSpreadCollectionsVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferSpreadCollectionsVisitor extends RecursiveAstVisitor<void> {
  _PreferSpreadCollectionsVisitor(this.issues);

  final List<DcmIssue> issues;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'addAll') {
      issues.add(DcmIssue(
        offset: node.offset,
        length: node.length,
        message:
            'Consider using spread operator (...) instead of addAll() when creating collections.',
        severity: DiagnosticSeverity.Information,
        ruleId: 'prefer-spread-collections',
        suggestion: 'Use [...list1, ...list2] instead of list1..addAll(list2)',
      ));
    }
    super.visitMethodInvocation(node);
  }
}

/// prefer-contains: Prefer contains over indexOf
class PreferContainsRule extends DcmRule {
  @override
  String get id => 'prefer-contains';

  @override
  String get description =>
      'Prefer using contains() instead of indexOf() >= 0 or indexOf() != -1.';

  @override
  String get category => 'common';

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
    final visitor = _PreferContainsVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferContainsVisitor extends RecursiveAstVisitor<void> {
  _PreferContainsVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;

    // Check for indexOf() >= 0, indexOf() > -1, indexOf() != -1
    if ((op == '>=' || op == '>' || op == '!=') &&
        node.leftOperand is MethodInvocation) {
      final method = node.leftOperand as MethodInvocation;
      if (method.methodName.name == 'indexOf') {
        final right = node.rightOperand;
        if (right is IntegerLiteral) {
          if ((op == '>=' && right.value == 0) ||
              (op == '>' && right.value == -1) ||
              (op == '!=' && right.value == -1)) {
            // Generate fix: target.contains(arg)
            final target = method.target;
            final args = method.argumentList.arguments;
            if (target != null && args.isNotEmpty) {
              final targetText = content.substring(target.offset, target.end);
              final argText =
                  content.substring(args.first.offset, args.first.end);
              final replacement = '$targetText.contains($argText)';

              issues.add(DcmIssue(
                offset: node.offset,
                length: node.length,
                message:
                    'Prefer using contains() instead of indexOf() comparison.',
                severity: DiagnosticSeverity.Information,
                ruleId: 'prefer-contains',
                suggestion: 'Use .contains(element) instead',
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

    // Check for indexOf() < 0, indexOf() == -1
    if ((op == '<' || op == '==') && node.leftOperand is MethodInvocation) {
      final method = node.leftOperand as MethodInvocation;
      if (method.methodName.name == 'indexOf') {
        final right = node.rightOperand;
        if (right is IntegerLiteral) {
          if ((op == '<' && right.value == 0) ||
              (op == '==' && right.value == -1)) {
            // Generate fix: !target.contains(arg)
            final target = method.target;
            final args = method.argumentList.arguments;
            if (target != null && args.isNotEmpty) {
              final targetText = content.substring(target.offset, target.end);
              final argText =
                  content.substring(args.first.offset, args.first.end);
              final replacement = '!$targetText.contains($argText)';

              issues.add(DcmIssue(
                offset: node.offset,
                length: node.length,
                message:
                    'Prefer using !contains() instead of indexOf() comparison.',
                severity: DiagnosticSeverity.Information,
                ruleId: 'prefer-contains',
                suggestion: 'Use !list.contains(element) instead',
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

    super.visitBinaryExpression(node);
  }
}

/// prefer-is-empty: Prefer isEmpty over length == 0
class PreferIsEmptyRule extends DcmRule {
  @override
  String get id => 'prefer-is-empty';

  @override
  String get description =>
      'Prefer using isEmpty/isNotEmpty instead of length comparisons.';

  @override
  String get category => 'common';

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
    final visitor = _PreferIsEmptyVisitor(issues, content);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferIsEmptyVisitor extends RecursiveAstVisitor<void> {
  _PreferIsEmptyVisitor(this.issues, this.content);

  final List<DcmIssue> issues;
  final String content;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;

    // Check for .length == 0 or 0 == .length
    if (op == '==' || op == '!=' || op == '>' || op == '<=' || op == '<') {
      final left = node.leftOperand;
      final right = node.rightOperand;

      bool isLengthAccess = false;
      bool isZeroLiteral = false;
      String suggestion = '';
      String? replacement;
      String? targetText;

      if (left is PrefixedIdentifier && left.identifier.name == 'length') {
        isLengthAccess = true;
        targetText = content.substring(left.prefix.offset, left.prefix.end);
        if (right is IntegerLiteral && right.value == 0) {
          isZeroLiteral = true;
          if (op == '==') {
            suggestion = 'Use .isEmpty instead';
            replacement = '$targetText.isEmpty';
          } else if (op == '!=' || op == '>') {
            suggestion = 'Use .isNotEmpty instead';
            replacement = '$targetText.isNotEmpty';
          }
        }
      } else if (right is PrefixedIdentifier &&
          right.identifier.name == 'length') {
        isLengthAccess = true;
        targetText = content.substring(right.prefix.offset, right.prefix.end);
        if (left is IntegerLiteral && left.value == 0) {
          isZeroLiteral = true;
          if (op == '==') {
            suggestion = 'Use .isEmpty instead';
            replacement = '$targetText.isEmpty';
          } else if (op == '!=' || op == '<') {
            suggestion = 'Use .isNotEmpty instead';
            replacement = '$targetText.isNotEmpty';
          }
        }
      }

      if (isLengthAccess &&
          isZeroLiteral &&
          suggestion.isNotEmpty &&
          replacement != null) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message: 'Prefer isEmpty/isNotEmpty over length comparison.',
          severity: DiagnosticSeverity.Information,
          ruleId: 'prefer-is-empty',
          suggestion: suggestion,
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

    super.visitBinaryExpression(node);
  }
}

// ============================================================================
// Naming and Style Rules
// ============================================================================

/// prefer-correct-identifier-length: Warns about too short/long identifiers
class PreferCorrectIdentifierLengthRule extends DcmRule {
  static const int defaultMinLength = 2;
  static const int defaultMaxLength = 40;

  @override
  String get id => 'prefer-correct-identifier-length';

  @override
  String get description =>
      'Prefer identifiers with appropriate length for readability.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#naming', '#readability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final ruleConfig = config.getRuleConfig(id);
    final minLength = (ruleConfig['min-length'] as int?) ?? defaultMinLength;
    final maxLength = (ruleConfig['max-length'] as int?) ?? defaultMaxLength;
    final exceptions = (ruleConfig['exceptions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        {'i', 'j', 'k', 'x', 'y', 'z', 'e', 'id', '_'};

    final visitor = _PreferCorrectIdentifierLengthVisitor(
        issues, minLength, maxLength, exceptions);
    result.unit.accept(visitor);
    return issues;
  }
}

class _PreferCorrectIdentifierLengthVisitor extends RecursiveAstVisitor<void> {
  _PreferCorrectIdentifierLengthVisitor(
      this.issues, this.minLength, this.maxLength, this.exceptions);

  final List<DcmIssue> issues;
  final int minLength;
  final int maxLength;
  final Set<String> exceptions;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _checkIdentifier(node.name.lexeme, node.name.offset, node.name.length);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkIdentifier(node.name.lexeme, node.name.offset, node.name.length);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkIdentifier(node.name.lexeme, node.name.offset, node.name.length);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final name = node.name?.lexeme;
    if (name != null) {
      _checkIdentifier(name, node.name!.offset, node.name!.length);
    }
    super.visitSimpleFormalParameter(node);
  }

  void _checkIdentifier(String name, int offset, int length) {
    // Skip private identifiers starting with _
    final effectiveName = name.startsWith('_') ? name.substring(1) : name;

    if (exceptions.contains(name) || exceptions.contains(effectiveName)) {
      return;
    }

    if (effectiveName.length < minLength) {
      issues.add(DcmIssue(
        offset: offset,
        length: length,
        message:
            "Identifier '$name' is too short (${effectiveName.length} chars). Minimum is $minLength.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'prefer-correct-identifier-length',
        suggestion: 'Use a more descriptive name',
      ));
    } else if (effectiveName.length > maxLength) {
      issues.add(DcmIssue(
        offset: offset,
        length: length,
        message:
            "Identifier '$name' is too long (${effectiveName.length} chars). Maximum is $maxLength.",
        severity: DiagnosticSeverity.Information,
        ruleId: 'prefer-correct-identifier-length',
        suggestion: 'Consider a shorter, clearer name',
      ));
    }
  }
}

/// avoid-abbreviations: Warns about unclear abbreviations in names
class AvoidAbbreviationsRule extends DcmRule {
  @override
  String get id => 'avoid-abbreviations';

  @override
  String get description => 'Avoid unclear abbreviations in identifiers.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => false;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#naming', '#readability'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final ruleConfig = config.getRuleConfig(id);
    final allowedAbbreviations = (ruleConfig['allowed'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toSet() ??
        {
          'id',
          'ui',
          'api',
          'url',
          'uri',
          'db',
          'io',
          'os',
          'ip',
          'html',
          'css',
          'json',
          'xml',
          'http',
          'https'
        };

    final visitor = _AvoidAbbreviationsVisitor(issues, allowedAbbreviations);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidAbbreviationsVisitor extends RecursiveAstVisitor<void> {
  _AvoidAbbreviationsVisitor(this.issues, this.allowedAbbreviations);

  final List<DcmIssue> issues;
  final Set<String> allowedAbbreviations;

  // Common unclear abbreviations
  static const _unclearAbbreviations = {
    'btn': 'button',
    'msg': 'message',
    'err': 'error',
    'val': 'value',
    'num': 'number',
    'cnt': 'count',
    'idx': 'index',
    'tmp': 'temporary',
    'str': 'string',
    'obj': 'object',
    'arr': 'array',
    'func': 'function',
    'param': 'parameter',
    'arg': 'argument',
    'calc': 'calculate',
    'init': 'initialize',
    'config': 'configuration',
    'ctx': 'context',
    'req': 'request',
    'res': 'response',
    'cb': 'callback',
    'evt': 'event',
    'elem': 'element',
    'attr': 'attribute',
    'prop': 'property',
    'prev': 'previous',
    'cur': 'current',
    'src': 'source',
    'dest': 'destination',
    'mgr': 'manager',
    'svc': 'service',
  };

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parts = _splitCamelCase(node.name);

    for (final part in parts) {
      final lowerPart = part.toLowerCase();
      if (_unclearAbbreviations.containsKey(lowerPart) &&
          !allowedAbbreviations.contains(lowerPart)) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.length,
          message:
              "Avoid abbreviation '$part'. Consider using '${_unclearAbbreviations[lowerPart]}' instead.",
          severity: DiagnosticSeverity.Information,
          ruleId: 'avoid-abbreviations',
          suggestion: 'Use full word: ${_unclearAbbreviations[lowerPart]}',
        ));
        break; // Only report first abbreviation per identifier
      }
    }

    super.visitSimpleIdentifier(node);
  }

  List<String> _splitCamelCase(String name) {
    final result = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < name.length; i++) {
      final char = name[i];
      if (char == '_') {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
      } else if (char.toUpperCase() == char && char.toLowerCase() != char) {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(char);
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString());
    }

    return result;
  }
}

/// prefer-match-file-name: Class name should match file name
class PreferMatchFileNameRule extends DcmRule {
  @override
  String get id => 'prefer-match-file-name';

  @override
  String get description =>
      'The main class/function name should match the file name.';

  @override
  String get category => 'common';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Information;

  @override
  List<String> get tags => ['#naming', '#organization'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final uri = result.uri;
    final fileName = uri.pathSegments.last;

    // Skip generated files
    if (fileName.endsWith('.g.dart') || fileName.endsWith('.freezed.dart')) {
      return issues;
    }

    final baseName = fileName.replaceAll('.dart', '');
    final expectedClassName = _snakeToPascal(baseName);

    // Find the first public class or top-level function
    for (final declaration in result.unit.declarations) {
      if (declaration is ClassDeclaration) {
        final className = declaration.name.lexeme;
        if (!className.startsWith('_')) {
          if (className != expectedClassName &&
              className != '${expectedClassName}s') {
            issues.add(DcmIssue(
              offset: declaration.name.offset,
              length: declaration.name.length,
              message:
                  "Class '$className' doesn't match file name. Expected '$expectedClassName' based on file '$fileName'.",
              severity: DiagnosticSeverity.Information,
              ruleId: 'prefer-match-file-name',
              suggestion:
                  'Rename class to $expectedClassName or file to match class',
            ));
          }
          break; // Only check first public class
        }
      }
    }

    return issues;
  }

  String _snakeToPascal(String snake) {
    return snake.split('_').map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    }).join('');
  }
}

/// Get all common rules
List<DcmRule> getCommonRules() => [
      // Original rules
      AvoidDynamicRule(),
      AvoidNonNullAssertionRule(),
      AvoidLongFunctionsRule(),
      AvoidNestedConditionalExpressionsRule(),
      PreferTrailingCommaRule(),
      NoEmptyBlockRule(),
      NoBooleanLiteralCompareRule(),
      PreferFirstRule(),
      PreferLastRule(),
      AvoidLateKeywordRule(),
      AvoidRedundantAsyncRule(),
      AvoidUnusedParametersRule(),
      DoubleLiteralFormatRule(),
      PreferImmediateReturnRule(),
      // Expression-related rules
      PreferConditionalExpressionsRule(),
      NoEqualThenElseRule(),
      AvoidUnnecessaryTypeAssertionsRule(),
      AvoidUnnecessaryTypeCastsRule(),
      AvoidUnrelatedTypeAssertionsRule(),
      BinaryExpressionOperandOrderRule(),
      PreferMovingToVariableRule(),
      AvoidUnnecessaryNullableRule(),
      NewlineBeforeReturnRule(),
      PreferCommentingAnalyzerIgnoresRule(),
      // Statement-related rules
      AvoidThrowInCatchBlockRule(),
      AvoidUnnecessarySettersRule(),
      AvoidUnnecessaryGettersRule(),
      PreferSwitchCaseEnumRule(),
      AvoidPositionalBooleanParametersRule(),
      AvoidGlobalStateRule(),
      AvoidDuplicateExportsRule(),
      // Collection-related rules
      AvoidCollectionMethodsWithUnrelatedTypesRule(),
      PreferIterableMethodsRule(),
      AvoidCascadeAfterIfNullRule(),
      PreferSpreadCollectionsRule(),
      PreferContainsRule(),
      PreferIsEmptyRule(),
      // Naming and style rules
      PreferCorrectIdentifierLengthRule(),
      AvoidAbbreviationsRule(),
      PreferMatchFileNameRule(),
    ];
