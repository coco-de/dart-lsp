import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lsp_server/lsp_server.dart';

import '../dcm_rule.dart';

/// avoid-async-callback-in-fake-async: Warns about async callbacks in fakeAsync
class AvoidAsyncCallbackInFakeAsyncRule extends DcmRule {
  @override
  String get id => 'avoid-async-callback-in-fake-async';

  @override
  String get description =>
      'Avoid using async callbacks inside fakeAsync. Use synchronous callbacks with pump() instead.';

  @override
  String get category => 'fake_async';

  @override
  bool get enabledByDefault => true;

  @override
  DiagnosticSeverity get defaultSeverity => DiagnosticSeverity.Warning;

  @override
  List<String> get tags => ['#testing', '#correctness'];

  @override
  List<DcmIssue> analyze(
      ResolvedUnitResult result, String content, DcmConfig config) {
    final issues = <DcmIssue>[];
    final visitor = _AvoidAsyncCallbackInFakeAsyncVisitor(issues);
    result.unit.accept(visitor);
    return issues;
  }
}

class _AvoidAsyncCallbackInFakeAsyncVisitor extends RecursiveAstVisitor<void> {
  _AvoidAsyncCallbackInFakeAsyncVisitor(this.issues);

  final List<DcmIssue> issues;
  bool _isInsideFakeAsync = false;
  int _fakeAsyncDepth = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // Track entering fakeAsync
    if (methodName == 'fakeAsync') {
      _isInsideFakeAsync = true;
      _fakeAsyncDepth++;

      // Visit arguments to find the callback
      super.visitMethodInvocation(node);

      _fakeAsyncDepth--;
      if (_fakeAsyncDepth == 0) {
        _isInsideFakeAsync = false;
      }
      return;
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (_isInsideFakeAsync) {
      // Check if the function is async
      if (node.body.isAsynchronous) {
        issues.add(DcmIssue(
          offset: node.offset,
          length: node.parameters?.length ?? 0 + 5, // "async" keyword area
          message:
              'Async callback inside fakeAsync will not work correctly. Time-based operations may not be controlled properly.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-async-callback-in-fake-async',
          suggestion:
              'Remove async keyword and use synchronous patterns with pump()',
        ));
      }

      // Also check for await expressions inside
      final awaitChecker = _AwaitChecker();
      node.accept(awaitChecker);

      if (awaitChecker.hasAwait && !node.body.isAsynchronous) {
        // This shouldn't happen in valid code, but just in case
        issues.add(DcmIssue(
          offset: awaitChecker.firstAwaitOffset!,
          length: awaitChecker.firstAwaitLength!,
          message:
              'Await expression inside fakeAsync may not work as expected.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-async-callback-in-fake-async',
          suggestion: 'Use synchronous patterns with pump() instead of await',
        ));
      }
    }

    super.visitFunctionExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (_isInsideFakeAsync) {
      // Check if the function is async
      final body = node.functionExpression.body;
      if (body.isAsynchronous) {
        issues.add(DcmIssue(
          offset: node.name.offset,
          length: node.name.length,
          message:
              'Async function inside fakeAsync test. Consider using synchronous patterns.',
          severity: DiagnosticSeverity.Warning,
          ruleId: 'avoid-async-callback-in-fake-async',
          suggestion: 'Use synchronous code with flushMicrotasks() or pump()',
        ));
      }
    }

    super.visitFunctionDeclaration(node);
  }
}

/// Helper visitor to find await expressions
class _AwaitChecker extends RecursiveAstVisitor<void> {
  bool hasAwait = false;
  int? firstAwaitOffset;
  int? firstAwaitLength;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (!hasAwait) {
      hasAwait = true;
      firstAwaitOffset = node.offset;
      firstAwaitLength = 5; // "await" keyword length
    }
    super.visitAwaitExpression(node);
  }
}

/// Get all FakeAsync rules
List<DcmRule> getFakeAsyncRules() => [
      AvoidAsyncCallbackInFakeAsyncRule(),
    ];
