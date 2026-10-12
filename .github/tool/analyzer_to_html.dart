import 'dart:convert';
import 'dart:io';

/// Converts `dart analyze --format=machine` output into an HTML table.
///
/// Usage: dart analyzer_to_html.dart [input.txt] [output.html]
/// Machine lines: SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE
void main(List<String> args) async {
  final inputFile = File(args.isNotEmpty ? args[0] : 'analyzer-report.txt');
  final outputFile = File(args.length > 1 ? args[1] : 'analyzer-report.html');

  if (!inputFile.existsSync()) {
    stderr.writeln('${inputFile.path} not found.');
    exit(1);
  }

  const esc = HtmlEscape();
  final rows = StringBuffer();

  for (final line in await inputFile.readAsLines()) {
    final f = line.split('|');
    if (f.length < 8) continue;
    final severity = f[0].toLowerCase();
    final message = f.sublist(7).join('|');
    rows.writeln('<tr><td class="$severity">$severity</td>'
        '<td>${esc.convert(f[3])}</td><td>${f[4]}</td><td>${f[5]}</td>'
        '<td>${esc.convert(message)}</td><td>${esc.convert(f[2].toLowerCase())}</td></tr>');
  }

  await outputFile.writeAsString('''
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Dart Analyzer Report</title>
<style>
body { font-family: Arial, sans-serif; padding: 20px; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ddd; padding: 8px; }
th { background-color: #f2f2f2; }
.error { color: #dc2626; } .warning { color: #d97706; } .info { color: #2563eb; }
</style></head><body>
<h1>Dart Analyzer Report</h1>
<table><thead><tr><th>Severity</th><th>File</th><th>Line</th><th>Column</th><th>Message</th><th>Code</th></tr></thead><tbody>
$rows</tbody></table></body></html>
''');

  print('${outputFile.path} generated.');
}
