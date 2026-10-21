import 'package:html/dom.dart';
import 'package:xml/xml.dart';
import '../../models/company.dart';
import '../../models/job.dart';
import '../fetch_log.dart';
import 'common.dart';

// Reads job feeds (RSS or Atom), including ones the page advertises
class FeedExtractor {
  static bool _looksJobby(String s) {
    final t = s.toLowerCase();
    return ['job', 'career', 'vacanc', 'position', 'opening', 'recruit']
        .any(t.contains);
  }

  static Future<ExtractResult?> find(
      Company company, Document doc, String html, Uri pageUri) async {
    // The page itself might be a feed
    final head = html.trimLeft();
    if (head.startsWith('<?xml') || head.startsWith('<rss') || head.startsWith('<feed')) {
      return parse(company, html, pageUri);
    }

    final urls = <String>[];
    for (final link in doc.querySelectorAll('link[rel="alternate"]')) {
      final type = (link.attributes['type'] ?? '').toLowerCase();
      final href = link.attributes['href'];
      if (href == null || href.isEmpty) continue;
      if (!(type.contains('rss') || type.contains('atom'))) continue;

      // Many sites advertise a BLOG feed: only take job-looking ones
      final label = '${link.attributes['title'] ?? ''} $href';
      if (_looksJobby(label)) urls.add(pageUri.resolve(href).toString());
    }
    // Teamtailor career sites publish /jobs.rss
    if (pageUri.host.endsWith('teamtailor.com')) {
      urls.add(pageUri.resolve('/jobs.rss').toString());
    }

    for (final u in urls.take(3)) {
      try {
        final text = await httpGetText(u);
        final result = parse(company, text, Uri.parse(u));
        if (result != null && result.jobs.isNotEmpty) {
          FetchLog.note('Feed: ${result.jobs.length} jobs from $u');
          return result;
        }
      } catch (e) {
        FetchLog.note('Feed $u failed: $e');
      }
    }
    return null;
  }

  static String? _child(XmlElement e, List<String> names) {
    for (final c in e.children.whereType<XmlElement>()) {
      if (names.contains(c.name.local.toLowerCase())) {
        final t = c.innerText.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  static String? _deep(XmlElement e, List<String> names) {
    for (final d in e.descendants.whereType<XmlElement>()) {
      if (names.contains(d.name.local.toLowerCase())) {
        final t = d.innerText.trim();
        if (t.isNotEmpty && t.length < 80) return t;
      }
    }
    return null;
  }

  static String? _linkOf(XmlElement item) {
    for (final c in item.children.whereType<XmlElement>()) {
      if (c.name.local.toLowerCase() != 'link') continue;
      final href = c.getAttribute('href');
      if (href != null && href.isNotEmpty) return href;
      final t = c.innerText.trim();
      if (t.isNotEmpty) return t;
    }
    return _child(item, ['guid', 'id']);
  }

  // "Tue, 14 Oct 2026 12:00:00 +0000"
  static DateTime? _rfc822(String s) {
    final m = RegExp(
            r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?')
        .firstMatch(s);
    if (m == null) return null;
    const months = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];
    final month = months.indexOf(m.group(2)!.toLowerCase()) + 1;
    if (month == 0) return null;
    return DateTime(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4) ?? '0'),
      int.parse(m.group(5) ?? '0'),
    );
  }

  static ExtractResult? parse(Company company, String xmlText, Uri base) {
    XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlText);
    } catch (_) {
      return null;
    }

    final items = doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'item' || e.name.local == 'entry')
        .toList();
    if (items.isEmpty) return null;

    final jobs = <Job>[];
    final seen = <String>{};

    for (final item in items) {
      final title = _child(item, ['title']);
      if (title == null) continue;

      final link = _linkOf(item);
      final url = link == null ? company.link : base.resolve(link).toString();
      final id = '${company.id}_${_child(item, ['guid', 'id']) ?? url}';
      if (!seen.add(id)) continue;

      final description = htmlToPlain(
          _child(item, ['description', 'summary', 'content', 'encoded']) ?? '');

      final city = _deep(item, ['city']);
      final country = _deep(item, ['country']);
      final location = (city != null || country != null)
          ? [city, country].whereType<String>().join(', ')
          : (_deep(item, ['location', 'joblocation']) ?? 'Not specified');

      final remote = _deep(item, ['remotestatus'])?.toLowerCase() ?? '';
      String mode;
      if (remote.contains('hybrid')) {
        mode = 'Hybrid';
      } else if (remote.contains('full') || remote.contains('remote')) {
        mode = 'Remote';
      } else if (remote.contains('none')) {
        mode = 'On-site';
      } else {
        mode = guessMode('$location $title', description);
      }

      final dateText =
          _child(item, ['pubdate', 'published', 'updated', 'date', 'created']);
      final date = dateText == null
          ? null
          : (parseAnyDate(dateText) ?? _rfc822(dateText));

      jobs.add(Job(
        id: id,
        companyId: company.id,
        companyName: company.name,
        title: title,
        role: _deep(item, ['department']) ?? guessRole(title),
        location: location,
        mode: mode,
        description: description.isEmpty
            ? 'Open in browser to read the full description.'
            : shorten(description),
        url: url,
        postedDate: date ?? DateTime.now(),
      ));
    }
    return jobs.isEmpty ? null : ExtractResult(jobs);
  }
}