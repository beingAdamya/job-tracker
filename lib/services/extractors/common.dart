import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/job.dart';

// What an extractor returns
class ExtractResult {
  final List<Job> jobs;
  final bool complete; // true = this is the page's whole list
  ExtractResult(this.jobs, {this.complete = false});
}

Future<String> httpGetText(String url,
    {Map<String, String>? headers, int seconds = 60}) async {
  final response = await http
      .get(Uri.parse(url), headers: {
        'User-Agent': 'JobTrackerApp/1.0 (college project)',
        ...?headers,
      })
      .timeout(Duration(seconds: seconds));

  if (response.statusCode != 200) {
    throw Exception('Server replied ${response.statusCode}');
  }
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}

Future<dynamic> httpGetJson(String url, {int seconds = 60}) async {
  final text = await httpGetText(url,
      headers: {'Accept': 'application/json'}, seconds: seconds);
  return jsonDecode(text);
}

// Anything → trimmed text (or null if there is none)
String? asText(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
  if (v is num) return v.toString();
  if (v is Map) {
    return asText(v['name'] ?? v['label'] ?? v['value'] ?? v['text'] ?? v['title']);
  }
  return null;
}

Map<String, dynamic> lowerKeys(Map m) =>
    {for (final e in m.entries) e.key.toString().toLowerCase(): e.value};

// The first value found under any of these (lowercase) keys
dynamic pickRaw(Map m, List<String> keys) {
  final lower = lowerKeys(m);
  for (final k in keys) {
    final v = lower[k];
    if (v != null && !(v is String && v.trim().isEmpty)) return v;
  }
  return null;
}

String? pickText(Map m, List<String> keys) {
  final lower = lowerKeys(m);
  for (final k in keys) {
    final s = asText(lower[k]);
    if (s != null) return s;
  }
  return null;
}

String? _locationText(dynamic v) {
  if (v == null) return null;
  if (v is List) {
    final items = v.map(_locationText).whereType<String>().toList();
    return items.isEmpty ? null : items.take(2).join(' | ');
  }
  if (v is Map) {
    final parts = [
      asText(v['city']),
      asText(v['region'] ?? v['state']),
      asText(v['country'] ?? v['countryCode']),
    ].whereType<String>().toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return asText(v['name'] ?? v['label'] ?? v['display'] ?? v['text']);
  }
  return asText(v);
}

// A readable location from whatever shape the data has
String locationOf(Map m) {
  final lower = lowerKeys(m);
  for (final k in const [
    'location', 'locations', 'joblocation', 'citystate',
    'locationname', 'office', 'offices'
  ]) {
    final s = _locationText(lower[k]);
    if (s != null) return s;
  }
  final parts = [
    asText(lower['city']),
    asText(lower['state'] ?? lower['region']),
    asText(lower['country']),
  ].whereType<String>().toList();
  return parts.isEmpty ? 'Not specified' : parts.join(', ');
}

// ISO text, "+0000" endings, or a number of seconds / milliseconds
DateTime? parseAnyDate(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    final n = v.toInt();
    return DateTime.fromMillisecondsSinceEpoch(n > 100000000000 ? n : n * 1000);
  }
  final s = asText(v);
  if (s == null) return null;

  final digits = int.tryParse(s);
  if (digits != null && s.length >= 9) {
    return DateTime.fromMillisecondsSinceEpoch(
        digits > 100000000000 ? digits : digits * 1000);
  }
  return DateTime.tryParse(s) ??
      DateTime.tryParse(s.replaceFirstMapped(
          RegExp(r'([+-]\d\d)(\d\d)$'), (m) => '${m[1]}:${m[2]}'));
}

String htmlToPlain(String html) {
  var text = html.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  text = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|h[1-6]|ul|ol)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

String shorten(String text) {
  const maxLength = 3000;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…\n\n(Open in browser to read the full description)';
}

String guessMode(String quickText, String description) {
  final q = quickText.toLowerCase();
  final d = description.toLowerCase();
  if (q.contains('hybrid')) return 'Hybrid';
  if (q.contains('remote')) return 'Remote';
  if (q.contains('on-site') || q.contains('onsite') || q.contains('on site')) {
    return 'On-site';
  }
  if (d.contains('hybrid')) return 'Hybrid';
  if (d.contains('fully remote') ||
      d.contains('100% remote') ||
      d.contains('work from home')) {
    return 'Remote';
  }
  if (d.contains('on-site') || d.contains('onsite')) return 'On-site';
  return 'Not specified';
}

String guessRole(String title) {
  final t = title.toLowerCase();
  if (t.contains('data') || t.contains('analyst') || t.contains('analytics')) {
    return 'Analytics';
  }
  if (t.contains('design') || t.contains('ux') || t.contains('ui ')) {
    return 'Design';
  }
  if (t.contains('engineer') ||
      t.contains('developer') ||
      t.contains('software') ||
      t.contains('devops')) {
    return 'Engineering';
  }
  if (t.contains('sales') || t.contains('account executive')) return 'Sales';
  if (t.contains('market') || t.contains('brand') || t.contains('content')) {
    return 'Marketing';
  }
  if (t.contains('recruit') || t.contains('hr ') || t.contains('people')) {
    return 'People';
  }
  if (t.contains('support') || t.contains('customer')) {
    return 'Customer Success';
  }
  if (t.contains('intern')) return 'Internship';
  return 'General';
}