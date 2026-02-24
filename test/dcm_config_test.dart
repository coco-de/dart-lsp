import 'package:dart_lsp/src/dcm/dcm_rule.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:test/test.dart';

void main() {
  group('DcmConfig', () {
    group('recommended()', () {
      late DcmConfig config;

      setUp(() {
        config = DcmConfig.recommended();
      });

      test('contains common rules', () {
        expect(config.enabledRules, contains('avoid-dynamic'));
        expect(config.enabledRules, contains('avoid-non-null-assertion'));
        expect(config.enabledRules, contains('prefer-trailing-comma'));
      });

      test('contains bloc rules', () {
        expect(config.enabledRules, contains('avoid-passing-bloc-to-bloc'));
        expect(config.enabledRules, contains('prefer-multi-bloc-provider'));
      });

      test('contains provider rules', () {
        expect(config.enabledRules, contains('avoid-watch-outside-build'));
        expect(config.enabledRules, contains('dispose-providers'));
      });

      test('contains flutter rules', () {
        expect(config.enabledRules, contains('always-remove-listener'));
        expect(
            config.enabledRules, contains('avoid-unnecessary-stateful-widgets'));
      });

      test('contains equatable rules', () {
        expect(config.enabledRules, contains('extend-equatable'));
        expect(
            config.enabledRules, contains('equatable-proper-super-calls'));
      });

      test('has no disabled rules', () {
        expect(config.disabledRules, isEmpty);
      });
    });

    group('isRuleEnabled', () {
      test('returns true for all rules when enabledRules is empty', () {
        const config = DcmConfig();
        expect(config.isRuleEnabled('any-rule'), isTrue);
        expect(config.isRuleEnabled('another-rule'), isTrue);
      });

      test('returns true only for explicitly enabled rules', () {
        const config = DcmConfig(enabledRules: {'rule-a', 'rule-b'});
        expect(config.isRuleEnabled('rule-a'), isTrue);
        expect(config.isRuleEnabled('rule-c'), isFalse);
      });

      test('returns false for explicitly disabled rules', () {
        const config = DcmConfig(
          enabledRules: {'rule-a', 'rule-b'},
          disabledRules: {'rule-a'},
        );
        expect(config.isRuleEnabled('rule-a'), isFalse);
        expect(config.isRuleEnabled('rule-b'), isTrue);
      });

      test('disabled takes precedence even with empty enabled set', () {
        const config = DcmConfig(disabledRules: {'no-this'});
        expect(config.isRuleEnabled('no-this'), isFalse);
        expect(config.isRuleEnabled('yes-this'), isTrue);
      });
    });

    group('getSeverity', () {
      test('returns default severity when no override', () {
        const config = DcmConfig();
        expect(
          config.getSeverity('some-rule', DiagnosticSeverity.Warning),
          DiagnosticSeverity.Warning,
        );
      });

      test('returns overridden severity when set', () {
        const config = DcmConfig(
          severityOverrides: {'some-rule': DiagnosticSeverity.Error},
        );
        expect(
          config.getSeverity('some-rule', DiagnosticSeverity.Warning),
          DiagnosticSeverity.Error,
        );
      });
    });
  });

  group('DcmIssue', () {
    test('hasAutoFix is false when fixes is null', () {
      const issue = DcmIssue(
        offset: 0,
        length: 5,
        message: 'test',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'test-rule',
      );
      expect(issue.hasAutoFix, isFalse);
    });

    test('hasAutoFix is false when fixes is empty', () {
      const issue = DcmIssue(
        offset: 0,
        length: 5,
        message: 'test',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'test-rule',
        fixes: [],
      );
      expect(issue.hasAutoFix, isFalse);
    });

    test('hasAutoFix is true when fixes exist', () {
      const issue = DcmIssue(
        offset: 0,
        length: 5,
        message: 'test',
        severity: DiagnosticSeverity.Warning,
        ruleId: 'test-rule',
        fixes: [DcmFix(offset: 0, length: 5, replacement: 'fixed')],
      );
      expect(issue.hasAutoFix, isTrue);
    });
  });
}
