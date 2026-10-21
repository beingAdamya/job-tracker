// Looks at a link and tells us which job platform it belongs to.
// It compares the website name, so "clever.com" is not mistaken for lever.co
String detectBoard(String link) {
  final host = (Uri.tryParse(link.trim())?.host ?? '').toLowerCase();
  bool on(String domain) => host == domain || host.endsWith('.$domain');

  if (on('greenhouse.io')) return 'greenhouse';
  if (on('lever.co')) return 'lever';
  if (on('ashbyhq.com')) return 'ashby';
  if (on('myworkdayjobs.com')) return 'workday';
  if (on('smartrecruiters.com')) return 'smartrecruiters';
  if (host == 'apply.workable.com') return 'workable';
  return 'unsupported';
}