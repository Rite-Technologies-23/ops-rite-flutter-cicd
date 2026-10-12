import 'dart:convert';
import 'dart:io';

void main() async {
  final input = await stdin.transform(utf8.decoder).join();

  if (input.trim().isEmpty) {
    stderr.writeln('Input is empty. No test results to convert.');
    print('<?xml version="1.0" encoding="UTF-8"?><testsuites></testsuites>');
    exit(0);
  }

  final events = LineSplitter.split(input)
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
    try {
      return json.decode(line);
    } catch (_) {
      return null;
    }
  }).whereType<Map>().toList();

  final testMetadata = <int, Map>{}; // testID -> test metadata
  final testResults = <String, List<Map>>{}; // suiteID -> list of test results
  final htmlEscape = HtmlEscape();

  for (var e in events) {
    switch (e['type']) {
      case 'testStart':
        final test = e['test'];
        if (test != null) {
          testMetadata[test['id']] = {
            'name': test['name'],
            'suite': test['suiteID'],
            'startTime': e['time'],
            'logs': <String>[],
          };
        }
        break;

      case 'print':
      case 'error':
      case 'message':
        final id = e['testID'];
        final meta = testMetadata[id];
        if (meta != null) {
          final message = e['message'] ?? e['error'] ?? '';
          (meta['logs'] as List<String>).add(message.toString());
        }
        break;

      case 'testDone':
        // Hidden tests are the runner's own "loading <file>" pseudo-tests.
        if (e['hidden'] == true) break;
        final id = e['testID'];
        final meta = testMetadata[id];
        if (meta != null) {
          final endTime = e['time'];
          final duration = meta['startTime'] != null
              ? (endTime - meta['startTime']) / 1000.0
              : 0.0;

          final suite = meta['suite'].toString();
          testResults.putIfAbsent(suite, () => []).add({
            'name': meta['name'],
            'status': e['result'], // e.g. 'success', 'failure', etc.
            'time': duration,
            'logs': (meta['logs'] as List<String>).join('\n'),
          });
        }
        break;
    }
  }

  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buffer.writeln('<testsuites>');

  testResults.forEach((suite, cases) {
    final totalTests = cases.length;
    final failures = cases.where((t) => t['status'] != 'success').length;
    final errors = 0; // Set 0 or add error counting logic if you want

    // Sum total time of all test cases in the suite
    final totalTime = cases.fold<double>(0.0, (sum, t) => sum + (t['time'] as double));

    buffer.writeln(
        '  <testsuite name="Suite $suite" tests="$totalTests" failures="$failures" errors="$errors" time="${totalTime.toStringAsFixed(3)}">');

    for (var test in cases) {
      final testName = htmlEscape.convert(test['name']);
      final testTime = (test['time'] as double).toStringAsFixed(3);
      buffer.write('    <testcase name="$testName" time="$testTime">');

      if (test['status'] != 'success') {
        final logs = htmlEscape.convert(test['logs'] ?? 'Test failed');
        buffer.writeln(
            '<failure message="${test['status']}"><![CDATA[$logs]]></failure>');
      }

      buffer.writeln('</testcase>');
    }

    buffer.writeln('  </testsuite>');
  });

  buffer.writeln('</testsuites>');
  print(buffer.toString());
}
