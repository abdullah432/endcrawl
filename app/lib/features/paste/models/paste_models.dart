/// A candidate delimiter for splitting a pasted line into role/actor —
/// direct port of the prototype's `DELIMS`.
class DelimiterOption {
  final String id;
  final String label;
  final RegExp pattern;
  const DelimiterOption(this.id, this.label, this.pattern);
}

final kDelimiters = <DelimiterOption>[
  DelimiterOption('dash', 'Dash', RegExp(r'\s+[-–—]\s+')),
  DelimiterOption('comma', 'Comma', RegExp(r'\s*,\s*')),
  DelimiterOption('tab', 'Tab', RegExp(r'\t+')),
  DelimiterOption('colon', 'Colon', RegExp(r'\s*:\s*')),
  DelimiterOption('as', '" as "', RegExp(r'\s+as\s+', caseSensitive: false)),
  DelimiterOption('dd', '2 spaces', RegExp(r' {2,}')),
];

const kPasteRawSeed = 'Elena Marsh - Priya Raghunathan\n'
    'DET. AUGUST COLE - Kwame Boateng\n'
    'Margo - Hattie Lindqvist\n'
    'Young Elena - Sofia Navarro-Reyes\n'
    'The Ferryman - Ibrahim Sesay\n'
    'Dr. Halvorsen - Greta Lindemann\n'
    'Bartender - Yusuf Demir\n'
    'Night Nurse - Aoife Callaghan\n'
    'Transit Cop (uncredited)\n'
    'Woman on Platform - Xiulan Ma';

class ParsedRow {
  final bool ok;
  final String left;
  final String right;
  final int index;
  const ParsedRow({required this.ok, required this.left, required this.right, required this.index});
}

/// Rule-based split — never guesses, never invents: a line that doesn't
/// contain the chosen delimiter is flagged, not corrected. Port of
/// `parseRaw()`.
List<ParsedRow> parsePastedText(String raw, DelimiterOption delimiter, bool swapColumns) {
  final lines = raw.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  return [
    for (var i = 0; i < lines.length; i++)
      () {
        final t = lines[i];
        final parts = t.split(delimiter.pattern);
        if (parts.length < 2) return ParsedRow(ok: false, left: t, right: '', index: i);
        final l = parts.first.trim();
        final r = parts.sublist(1).join(' ').trim();
        return swapColumns
            ? ParsedRow(ok: true, left: r, right: l, index: i)
            : ParsedRow(ok: true, left: l, right: r, index: i);
      }(),
  ];
}
