// Looks at a link and tells us which job board it belongs to
String detectBoard(String link) {
  final l = link.toLowerCase(); // so "Lever.co" and "lever.co" both match

  if (l.contains('greenhouse.io')) return 'greenhouse';
  if (l.contains('lever.co')) return 'lever';
  if (l.contains('ashbyhq.com')) return 'ashby';
  if (l.contains('myworkdayjobs.com')) return 'workday';
  return 'unsupported';
}

