import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'analyzer_service.dart';

/// Parse JSON reporter output from dart test
Map<String, dynamic> parseJsonTestResults(String output) {
  var passed = 0;
  var failed = 0;
  var skipped = 0;
  final failures = <String>[];
  final errors = <String>[];
  final testNames = <int, String>{};

  for (final line in output.split('\n')) {
    if (line.isEmpty) continue;
    try {
      final event = jsonDecode(line) as Map<String, dynamic>;
      final type = event['type'] as String?;

      if (type == 'testStart') {
        final test = event['test'] as Map<String, dynamic>?;
        if (test != null) {
          testNames[test['id'] as int] = test['name'] as String;
        }
      } else if (type == 'testDone') {
        final result = event['result'] as String?;
        if (event['skipped'] == true) {
          skipped++;
        } else if (result == 'success') {
          passed++;
        } else if (result == 'failure' || result == 'error') {
          failed++;
        }
      } else if (type == 'error') {
        final testID = event['testID'] as int?;
        final message = event['error'] as String? ?? '';
        final testName = testID != null ? testNames[testID] : null;
        if (testName != null) {
          failures.add('  \u274c $testName\n     $message');
        } else {
          errors.add('  \u274c $message');
        }
      }
    } catch (_) {
      // Skip non-JSON lines
    }
  }

  final total = passed + failed + skipped;
  if (total == 0) {
    return {'formatted': '\ud83e\uddea No tests found or unable to parse results.'};
  }

  final buffer = StringBuffer();
  buffer.writeln('\ud83e\uddea Test Results: $total total');
  buffer.writeln('  \u2705 Passed: $passed');
  if (failed > 0) buffer.writeln('  \u274c Failed: $failed');
  if (skipped > 0) buffer.writeln('  \u23ed\ufe0f Skipped: $skipped');

  if (failures.isNotEmpty) {
    buffer.writeln('\nFailures:');
    buffer.writeln(failures.join('\n\n'));
  }
  if (errors.isNotEmpty) {
    buffer.writeln('\nErrors:');
    buffer.writeln(errors.join('\n\n'));
  }

  final result = <String, dynamic>{
    'formatted': buffer.toString().trim(),
    'passed': passed,
    'failed': failed,
    'skipped': skipped,
  };
  if (failures.isNotEmpty) result['failures'] = failures;
  return result;
}

/// Format widget tree with tree-drawing characters
String formatWidgetTree(List<WidgetNode> nodes, int depth) {
  final buffer = StringBuffer();
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    final isLast = i == nodes.length - 1;
    final prefix = depth == 0
        ? ''
        : '${'│  ' * (depth - 1)}${isLast ? '└─ ' : '├─ '}';
    buffer.writeln('$prefix${node.name} (line ${node.line})');
    if (node.children.isNotEmpty) {
      buffer.write(formatWidgetTree(node.children, depth + 1));
    }
  }
  return buffer.toString();
}

/// Format diagnostics for display
String formatDiagnostics(List<Map<String, dynamic>> diagnostics) {
  return diagnostics.map((d) {
    final severity = d['severity'] as String?;
    final icon =
        severity == 'error' ? '\u274c' : (severity == 'warning' ? '\u26a0\ufe0f' : '\u2139\ufe0f');
    final range = d['range'] as Map<String, dynamic>;
    final start = range['start'] as Map<String, dynamic>;
    final line = (start['line'] as int) + 1;
    final col = (start['character'] as int) + 1;
    return '$icon Line $line:$col - ${d['message']}';
  }).join('\n');
}

/// Format completions for display
String formatCompletions(List<Map<String, dynamic>> completions) {
  return completions.map((c) {
    final kind = c['kind'];
    final icon = kind == 'class'
        ? '\ud83d\udce6'
        : kind == 'function'
            ? '\ud83d\udd39'
            : kind == 'variable'
                ? '\ud83d\udcce'
                : kind == 'property'
                    ? '\ud83d\udd38'
                    : '\u2022';
    return '$icon ${c['label']}${c['detail'] != null ? ' - ${c['detail']}' : ''}';
  }).join('\n');
}

/// Convert severity to string
String severityToString(dynamic severity) {
  final name = severity.toString().toLowerCase();
  if (name.contains('error')) return 'error';
  if (name.contains('warning')) return 'warning';
  if (name.contains('info')) return 'info';
  return 'hint';
}

/// Convert completion kind to string
String completionKindToString(dynamic kind) {
  if (kind == null) return 'text';
  final name = kind.toString().toLowerCase();
  if (name.contains('class')) return 'class';
  if (name.contains('function') || name.contains('method')) return 'function';
  if (name.contains('variable') || name.contains('field')) return 'variable';
  if (name.contains('property')) return 'property';
  if (name.contains('snippet')) return 'snippet';
  return 'text';
}

/// Get offset from line and character position
int getOffset(String content, int line, int character) {
  final lines = content.split('\n');
  var offset = 0;
  for (var i = 0; i < line && i < lines.length; i++) {
    offset += lines[i].length + 1; // +1 for newline
  }
  final result = offset + character;
  // Clamp to content length to avoid RangeError
  return result > content.length ? content.length : result;
}

/// Find project root by searching for pubspec.yaml
String? findProjectRoot(String path) {
  var dir = Directory(path);
  if (!dir.existsSync()) {
    dir = File(path).parent;
  }
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return null;
}

/// Check if the project at [projectPath] is a Flutter project
bool isFlutterProject(String projectPath) {
  final pubspecFile = File('$projectPath/pubspec.yaml');
  if (!pubspecFile.existsSync()) return false;
  try {
    final content = pubspecFile.readAsStringSync();
    final pubspec = loadYaml(content) as YamlMap?;
    if (pubspec == null) return false;
    final deps = pubspec['dependencies'] as YamlMap?;
    return deps != null && deps.containsKey('flutter');
  } catch (_) {
    return false;
  }
}
