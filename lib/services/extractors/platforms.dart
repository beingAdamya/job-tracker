import '../../models/company.dart';
import '../../models/job.dart';
import 'common.dart';

// Job platforms that publish their jobs through a public address
class Platforms {
  // ---------- SmartRecruiters:  jobs.smartrecruiters.com/CompanyName ----------
  static Future<ExtractResult> smartRecruiters(Company company, int cap) async {
    final uri = Uri.parse(company.link);
    final id = uri.pathSegments.firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (id.isEmpty) throw Exception('Could not find the company name in the link');

    final jobs = <Job>[];
    final seen = <String>{};
    var offset = 0;
    var total = 0;

    while (jobs.length < cap) {
      final data = await httpGetJson(
          'https://api.smartrecruiters.com/v1/companies/$id/postings?limit=100&offset=$offset');
      final List items = (data is Map ? data['content'] : null) ?? [];
      total = int.tryParse('${data['totalFound']}') ?? total;
      if (items.isEmpty) break;

      for (final raw in items) {
        if (raw is! Map) continue;
        final postingId = asText(raw['id']) ?? asText(raw['uuid']);
        if (postingId == null || !seen.add(postingId)) continue;

        final title = asText(raw['name']) ?? 'Untitled';
        final loc = raw['location'];
        final location = locationOf(raw);

        String mode = 'On-site';
        if (loc is Map && loc['remote'] == true) {
          mode = 'Remote';
        } else if (loc is Map && loc['hybrid'] == true) {
          mode = 'Hybrid';
        } else {
          mode = guessMode('$location $title', '');
        }

        final department = asText(raw['department']);
        final type = asText(raw['typeOfEmployment']);

        jobs.add(Job(
          id: '${company.id}_$postingId',
          companyId: company.id,
          companyName: company.name,
          title: title,
          role: department ?? guessRole(title),
          location: location,
          mode: mode,
          description: [
            if (department != null) 'Department: $department',
            if (type != null) 'Type: $type',
            '(Open in browser to read the full description)',
          ].join('\n'),
          url: 'https://jobs.smartrecruiters.com/$id/$postingId',
          postedDate: parseAnyDate(raw['releasedDate']) ?? DateTime.now(),
        ));
      }

      offset += items.length;
      if (offset >= total) break;
    }
    return ExtractResult(jobs, complete: offset >= total);
  }

  // ---------- Workable:  apply.workable.com/accountname ----------
  static Future<ExtractResult> workable(Company company) async {
    final uri = Uri.parse(company.link);
    final account =
        uri.pathSegments.firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (account.isEmpty || account == 'j') {
      throw Exception('Could not find the company name in the link');
    }

    final data = await httpGetJson(
        'https://apply.workable.com/api/v1/widget/accounts/$account?details=true');
    final List items = (data is Map ? data['jobs'] : null) ?? [];

    final jobs = <Job>[];
    final seen = <String>{};

    for (final raw in items) {
      if (raw is! Map) continue;
      final code = pickText(raw, ['shortcode', 'id']);
      final url = pickText(raw, ['url', 'shortlink', 'application_url']) ??
          company.link;
      final key = code ?? url;
      if (!seen.add(key)) continue; // multi-location jobs repeat

      final title = pickText(raw, ['title']) ?? 'Untitled';
      final location = locationOf(raw);
      final description = htmlToPlain(
          pickText(raw, ['description', 'full_description']) ?? '');

      final remote = raw['telecommuting'] == true || raw['isRemote'] == true;

      jobs.add(Job(
        id: '${company.id}_$key',
        companyId: company.id,
        companyName: company.name,
        title: title,
        role: pickText(raw, ['department', 'function']) ?? guessRole(title),
        location: location,
        mode: remote ? 'Remote' : guessMode('$location $title', description),
        description: description.isEmpty
            ? 'Open in browser to read the full description.'
            : shorten(description),
        url: url,
        postedDate:
            parseAnyDate(pickRaw(raw, ['published_on', 'created_at'])) ??
                DateTime.now(),
      ));
    }
    return ExtractResult(jobs, complete: true);
  }
}