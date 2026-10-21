import 'dart:convert';
import 'package:html/dom.dart';
import '../../models/company.dart';
import '../../models/job.dart';
import '../fetch_log.dart';
import 'common.dart';

class _Found {
  final String path;
  final List<Map> items;
  final double score;
  _Found(this.path, this.items, this.score);
}

// Looks through every JSON block embedded in a page for a list that
// looks like job postings, whatever the site calls its fields.
class JsonHunter {
  static const _titleKeys = [
    'title', 'jobtitle', 'job_title', 'positiontitle', 'position', 'name', 'text'
  ];
  static const _urlKeys = [
    'absolute_url', 'applyurl', 'apply_url', 'hostedurl', 'joburl', 'job_url',
    'externalurl', 'canonicalpositionurl', 'url', 'link', 'href', 'path'
  ];
  static const _idKeys = [
    'id', 'jobid', 'job_id', 'reqid', 'req_id', 'requisitionid', 'jobseqno',
    'shortcode', 'uuid', 'slug'
  ];
  static const _dateKeys = [
    'posteddate', 'dateposted', 'posted_at', 'publishedat', 'published_at',
    'published_on', 'createdat', 'created_at', 'updatedat', 'date'
  ];
  static const _locKeys = [
    'location', 'locations', 'joblocation', 'citystate', 'locationname',
    'office', 'city', 'country'
  ];
  static const _descKeys = [
    'description', 'descriptionteaser', 'summary', 'content',
    'jobdescription', 'shortdescription', 'snippet'
  ];
  static const _roleKeys = [
    'department', 'team', 'category', 'function', 'jobfamily', 'businessunit'
  ];
  static const _jobbyWords = [
    'job', 'position', 'opening', 'posting', 'vacanc', 'career',
    'result', 'hit', 'requisition', 'offer'
  ];

  static ExtractResult? find(Company company, Document doc, Uri pageUri) {
    final blobs = _jsonBlobs(doc);
    FetchLog.note('JSON hunter: examining ${blobs.length} embedded JSON blocks');

    final found = <_Found>[];
    for (final blob in blobs) {
      _search(blob, 'root', 0, found);
    }
    if (found.isEmpty) {
      FetchLog.note('JSON hunter: no list that looks like jobs');
      return null;
    }

    found.sort((a, b) => b.score.compareTo(a.score));
    final best = found.first;
    FetchLog.note(
        'JSON hunter: using "${best.path}" (${best.items.length} items)');

    final jobs = <Job>[];
    final seen = <String>{};
    for (final m in best.items) {
      final job = _toJob(company, m, pageUri);
      if (seen.add(job.id)) jobs.add(job);
    }
    return ExtractResult(jobs);
  }

  // ---------- 1. Collect JSON from the page ----------
  static List<dynamic> _jsonBlobs(Document doc) {
    final out = <dynamic>[];

    for (final s in doc.querySelectorAll('script')) {
      final type = (s.attributes['type'] ?? '').toLowerCase();
      final text = s.text.trim();
      if (text.length < 40 || text.length > 4000000) continue;
      if (type == 'application/ld+json') continue; // handled elsewhere

      if (type == 'application/json' || s.id == '__NEXT_DATA__') {
        _tryParse(text, out);
        continue;
      }
      if (type.isNotEmpty && type != 'text/javascript' && type != 'module') {
        continue;
      }

      // Ordinary scripts: look for  something = { ... }  or  = [ ... ]
      var tried = 0;
      for (final m in RegExp(r'=\s*(?=[\[{])').allMatches(text)) {
        if (tried >= 12) break;
        final block = _balancedBlock(text, m.end);
        if (block != null && block.length > 40) {
          tried++;
          _tryParse(block, out);
        }
      }
    }
    return out;
  }

  static void _tryParse(String text, List<dynamic> out) {
    try {
      out.add(jsonDecode(text));
    } catch (_) {
      // not valid JSON: ignore it
    }
  }

  // Cuts one {...} or [...] block out of text, counting brackets
  static String? _balancedBlock(String text, int start) {
    var depth = 0;
    var inString = false;

    for (var i = start; i < text.length; i++) {
      if (i - start > 3000000) return null;
      final c = text[i];

      if (inString) {
        if (c == '\\') {
          i++; // skip the escaped character
        } else if (c == '"') {
          inString = false;
        }
      } else if (c == '"') {
        inString = true;
      } else if (c == '{' || c == '[') {
        depth++;
      } else if (c == '}' || c == ']') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  // ---------- 2. Search the data for job-like lists ----------
  static void _search(dynamic node, String path, int depth, List<_Found> out) {
    if (depth > 12) return;

    if (node is List) {
      final maps = node.whereType<Map>().toList();
      if (maps.length >= 2 && maps.length >= node.length * 0.8) {
        final score = _scoreList(maps, path);
        if (score > 0) out.add(_Found(path, maps, score));
      }
      for (var i = 0; i < node.length && i < 5; i++) {
        _search(node[i], '$path[$i]', depth + 1, out);
      }
    } else if (node is Map) {
      node.forEach((k, v) {
        if (v is List || v is Map) _search(v, '$path.$k', depth + 1, out);
      });
    }
  }

  static String? _firstText(Map<String, dynamic> lower, List<String> keys) {
    for (final k in keys) {
      final s = asText(lower[k]);
      if (s != null) return s;
    }
    return null;
  }

  // 0 = not a job list. Bigger = more convincing.
  static double _scoreList(List<Map> items, String path) {
    var titled = 0, linked = 0, located = 0, dated = 0;

    for (final m in items) {
      final lower = lowerKeys(m);
      final t = _firstText(lower, _titleKeys);
      if (t != null && t.length >= 4 && t.length <= 160) titled++;
      if (_firstText(lower, _urlKeys) != null ||
          _firstText(lower, _idKeys) != null) {
        linked++;
      }
      if (lower.keys.any(_locKeys.contains)) located++;
      if (lower.keys.any(_dateKeys.contains)) dated++;
    }

    final n = items.length;
    if (titled < n * 0.8 || linked < n * 0.6) return 0;

    // A menu also has titles and links, so we need more evidence:
    // locations, dates, or a job-sounding name for the list
    final jobbyPath = _jobbyWords.any((w) => path.toLowerCase().contains(w));
    if (!(located >= n * 0.4 || dated >= n * 0.4 || jobbyPath)) return 0;

    return n * (1 + located / n + dated / n + (jobbyPath ? 1 : 0));
  }

  // ---------- 3. Turn one item into a Job ----------
  static String? _remoteHint(Map m) {
    final lower = lowerKeys(m);
    for (final k in const [
      'workplacetype', 'remotetype', 'worktype', 'locationtype', 'workmodel'
    ]) {
      final s = asText(lower[k])?.toLowerCase();
      if (s == null) continue;
      if (s.contains('hybrid') || s.contains('flex')) return 'Hybrid';
      if (s.contains('remote')) return 'Remote';
      if (s.contains('site')) return 'On-site';
    }
    final r = lower['isremote'] ?? lower['remote'] ?? lower['telecommuting'];
    return r == true ? 'Remote' : null;
  }

  static Job _toJob(Company company, Map m, Uri pageUri) {
    final title = pickText(m, _titleKeys) ?? 'Untitled';

    var url = company.link;
    final rawUrl = pickText(m, _urlKeys);
    if (rawUrl != null && rawUrl.contains('/')) {
      final resolved = pageUri.resolve(rawUrl);
      if (resolved.hasScheme) url = resolved.toString();
    }

    final location = locationOf(m);
    final description = htmlToPlain(pickText(m, _descKeys) ?? '');
    final id = pickText(m, _idKeys) ?? url;

    return Job(
      id: '${company.id}_$id',
      companyId: company.id,
      companyName: company.name,
      title: title,
      role: pickText(m, _roleKeys) ?? guessRole(title),
      location: location,
      mode: _remoteHint(m) ?? guessMode('$location $title', description),
      description: description.isEmpty
          ? 'Open in browser to read the full description.'
          : shorten(description),
      url: url,
      postedDate: parseAnyDate(pickRaw(m, _dateKeys)) ?? DateTime.now(),
    );
  }
}