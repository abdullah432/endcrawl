/// One rule for splitting a pasted line into role and name (4.2).
class DelimiterOption {
  final String id;
  final String label;
  final RegExp pattern;
  const DelimiterOption(this.id, this.label, this.pattern);

  bool splits(String line) => line.split(pattern).where((p) => p.trim().isNotEmpty).length >= 2;
}

final kDelimiters = <DelimiterOption>[
  DelimiterOption('dash', 'Dash —', RegExp(r'\s+[-–—]\s+')),
  DelimiterOption('comma', 'Comma', RegExp(r'\s*,\s*')),
  DelimiterOption('tab', 'Tab', RegExp(r'\t+')),
  DelimiterOption('as', '"as"', RegExp(r'\s+as\s+', caseSensitive: false)),
  DelimiterOption('spaces', '2+ spaces', RegExp(r' {2,}')),
];

/// The non-empty, trimmed lines of pasted text.
List<String> pastedLines(String raw) => raw.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

/// How many of [lines] the rule would split — the count on each chip.
int matchCount(List<String> lines, DelimiterOption rule) => lines.where(rule.splits).length;

class ParsedRow {
  final bool ok;
  final String left;
  final String right;
  final int index;
  const ParsedRow({required this.ok, required this.left, required this.right, required this.index});
}

/// Rule-based split — never guesses, never invents: a line without the
/// chosen delimiter is flagged, not corrected. Everything after the first
/// delimiter is the name, so "Dr. Vance — Helen — Tsai" keeps the rest.
List<ParsedRow> parsePastedText(String raw, DelimiterOption delimiter, bool swapColumns) {
  final lines = pastedLines(raw);
  return [
    for (final (i, t) in lines.indexed)
      if (!delimiter.splits(t))
        ParsedRow(ok: false, left: t, right: '', index: i)
      else
        () {
          final parts = t.split(delimiter.pattern);
          final l = parts.first.trim();
          final r = parts.sublist(1).join(' ').trim();
          return swapColumns ? ParsedRow(ok: true, left: r, right: l, index: i) : ParsedRow(ok: true, left: l, right: r, index: i);
        }(),
  ];
}
