import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/company.dart';
import '../models/job.dart';
import 'board_detector.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' show Document, Element;


class JobFetcher {
  // Keep only this many of the newest jobs per company
  static int maxJobsPerCompany = 100;
  static const int maxGenericLinks = 40;

  // ===== MAIN ENTRY: pick the right method for this company's link =====
  static Future<List<Job>> fetch(Company company,
      {Map<String, Job> known = const {},
      bool quick = false,
      int maxAgeDays = 0}) async {
    List<Job> jobs;

    switch (detectBoard(company.link)) {
      case 'greenhouse':
        jobs = await _fetchGreenhouse(company);
        break;
      case 'lever':
        jobs = await _fetchLever(company);
        break;
      case 'ashby':
        jobs = await _fetchAshby(company);
        break;
      case 'workday':
        jobs = await _fetchWorkday(company, known, quick);
        break;
      default:
        jobs = await _fetchGeneric(company, known, quick);
        break;
    }

    if (maxAgeDays > 0) {
      final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
      jobs = jobs.where((j) => j.postedDate.isAfter(cutoff)).toList();
    }


    // Newest first, then keep only the top 100
    jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    if (jobs.length > maxJobsPerCompany) {
      jobs = jobs.sublist(0, maxJobsPerCompany);
    }
    return jobs;
  }

  // ===== HELPERS =====

  // Download a web address and decode the JSON inside
  static Future<dynamic> _getJson(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Server replied ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // "boards.greenhouse.io/stripe" → "stripe"
  static String _boardName(Company company) {
    final uri = Uri.parse(company.link);

    // Older style: boards.greenhouse.io/embed/job_board?for=stripe
    final forParam = uri.queryParameters['for'];
    if (forParam != null && forParam.isNotEmpty) return forParam;

    if (uri.pathSegments.isEmpty || uri.pathSegments.first.isEmpty) {
      throw Exception('Could not find the company name in the link');
    }
    return uri.pathSegments.first;
  }

  // Turn HTML like "<p>Hello&nbsp;<b>world</b></p>" into plain text
  static String htmlToText(String html) {
    var text = html.replaceAll('&lt;', '<').replaceAll('&gt;', '>');

    text = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|ul|ol)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '') // remove every remaining tag
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  // Guess Remote / Hybrid / On-site from text
  static String _guessMode(String quickText, String description) {
    final q = quickText.toLowerCase(); // location + title
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

  // Guess a department from the job title
  static String _guessRole(String title) {
    final t = title.toLowerCase();

    // Order matters: the FIRST match wins
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
    if (t.contains('sales') || t.contains('account executive')) {
      return 'Sales';
    }
    if (t.contains('market') || t.contains('brand') || t.contains('content')) {
      return 'Marketing';
    }
    if (t.contains('recruit') || t.contains('hr ') || t.contains('people')) {
      return 'People';
    }
    if (t.contains('support') || t.contains('customer')) {
      return 'Customer Success';
    }
    if (t.contains('intern')) {
      return 'Internship';
    }
    return 'General';
  }

  // Long descriptions make saving slow, so cut them
  static String _shorten(String text) {
    const maxLength = 3000;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…\n\n(Open in browser to read the full description)';
  }

  // ===== GREENHOUSE =====
  static Future<List<Job>> _fetchGreenhouse(Company company) async {
    final name = _boardName(company);
    final data = await _getJson(
        'https://boards-api.greenhouse.io/v1/boards/$name/jobs?content=true');

    final List items = data['jobs'] ?? [];
    final jobs = <Job>[];

    for (final item in items) {
      final title = (item['title'] ?? 'Untitled').toString();
      final location =
          (item['location']?['name'] ?? 'Not specified').toString();
      final description = htmlToText((item['content'] ?? '').toString());

      final List departments = item['departments'] ?? [];
      final role = departments.isNotEmpty
          ? (departments.first['name'] ?? 'General').toString()
          : 'General';

      final dateText =
          (item['first_published'] ?? item['updated_at'] ?? '').toString();

      jobs.add(Job(
        id: '${company.id}_${item['id']}',
        companyId: company.id,
        companyName: company.name,
        title: title,
        role: role,
        location: location,
        mode: _guessMode('$location $title', description),
        description: _shorten(description),
        url: (item['absolute_url'] ?? company.link).toString(),
        postedDate: DateTime.tryParse(dateText) ?? DateTime.now(),
      ));
    }
    return jobs;
  }

  // ===== LEVER =====
  static Future<List<Job>> _fetchLever(Company company) async {
    final name = _boardName(company);
    final data =
        await _getJson('https://api.lever.co/v0/postings/$name?mode=json');

    final List items = data is List ? data : [];
    final jobs = <Job>[];

    for (final item in items) {
      final cats = item['categories'] ?? {};
      final title = (item['text'] ?? 'Untitled').toString();
      final location = (cats['location'] ?? 'Not specified').toString();
      final role = (cats['team'] ?? cats['department'] ?? 'General').toString();

      // Description + the "requirements" style sections Lever sends separately
      var description = (item['descriptionPlain'] ?? '').toString();
      final List sections = item['lists'] ?? [];
      for (final section in sections) {
        description +=
            '\n\n${section['text'] ?? ''}\n${htmlToText((section['content'] ?? '').toString())}';
      }

      // Lever tells us the mode directly
      final workplace = (item['workplaceType'] ?? '').toString().toLowerCase();
      String mode;
      if (workplace == 'remote') {
        mode = 'Remote';
      } else if (workplace == 'hybrid') {
        mode = 'Hybrid';
      } else if (workplace == 'on-site') {
        mode = 'On-site';
      } else {
        mode = _guessMode('$location $title', description);
      }

      final created = item['createdAt']; // milliseconds since 1970
      final date = created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : DateTime.now();

      jobs.add(Job(
        id: '${company.id}_${item['id']}',
        companyId: company.id,
        companyName: company.name,
        title: title,
        role: role,
        location: location,
        mode: mode,
        description: _shorten(description),
        url: (item['hostedUrl'] ?? company.link).toString(),
        postedDate: date,
      ));
    }
    return jobs;
  }

  // ===== ASHBY =====
  static Future<List<Job>> _fetchAshby(Company company) async {
    final name = _boardName(company);
    final data = await _getJson(
        'https://api.ashbyhq.com/posting-api/job-board/$name');

    final List items = data['jobs'] ?? [];
    final jobs = <Job>[];

    for (final item in items) {
      if (item['isListed'] == false) continue; // skip hidden jobs

      final title = (item['title'] ?? 'Untitled').toString();
      final location = (item['location'] ?? 'Not specified').toString();
      final role = (item['department'] ?? item['team'] ?? 'General').toString();
      final description = (item['descriptionPlain'] ??
              htmlToText((item['descriptionHtml'] ?? '').toString()))
          .toString();

      final workplace = (item['workplaceType'] ?? '').toString().toLowerCase();
      String mode;
      if (workplace == 'remote' || item['isRemote'] == true) {
        mode = 'Remote';
      } else if (workplace == 'hybrid') {
        mode = 'Hybrid';
      } else if (workplace == 'onsite') {
        mode = 'On-site';
      } else {
        mode = _guessMode('$location $title', description);
      }

      jobs.add(Job(
        id: '${company.id}_${item['id']}',
        companyId: company.id,
        companyName: company.name,
        title: title,
        role: role,
        location: location,
        mode: mode,
        description: _shorten(description),
        url: (item['jobUrl'] ?? company.link).toString(),
        postedDate:
            DateTime.tryParse((item['publishedAt'] ?? '').toString()) ??
                DateTime.now(),
      ));
    }
    return jobs;
    // ===== GENERIC SCRAPER (any career page) =====
  }
  // Words that suggest a link points to ONE job
  static const _jobWords = [
    'job', 'position', 'opening', 'vacanc', 'posting', 'requisition', 'opportunit'
  ];

  // Link texts that are menu items, not jobs
  static const _skipTitles = [
    'careers', 'jobs', 'all jobs', 'apply', 'apply now', 'home', 'search',
    'login', 'log in', 'sign in', 'back', 'privacy', 'cookie', 'learn more',
    'view all', 'view all jobs', 'see all jobs', 'read more', 'next',
    'previous', 'contact'
  ];

  static const List<String> _hopPhrases = [
    'view all jobs', 'see all jobs', 'search jobs', 'view jobs',
    'browse jobs', 'explore jobs', 'view open positions', 'open positions',
    'current openings', 'view all openings', 'see open roles', 'open roles',
    'search all jobs', 'all open positions', 'view all positions',
    'see all openings',
  ];

  static const Set<String> _skipPathWords = {
    'location', 'locations', 'type', 'types', 'category', 'categories',
    'tag', 'tags', 'feed', 'rss', 'create', 'submit', 'login', 'logout',
    'signin', 'register', 'mine', 'howto', 'search', 'page', 'about',
    'faq', 'blog', 'news', 'help', 'contact', 'privacy', 'terms', 'legal',
    'department', 'departments', 'filter',
  };

  static const List<String> _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
  ];

  // Download a normal web page (HTML, not JSON)
  static Future<String> _getHtml(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        // We say honestly who we are
        'User-Agent': 'JobTrackerApp/1.0 (college project)',
        'Accept': 'text/html,application/xhtml+xml',
      },
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Server replied ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static String? _nextPageUrl(Document doc, Uri pageUri) {
    final byRel = doc.querySelector('a[rel="next"]') ??
        doc.querySelector('link[rel="next"]');
    final candidates = <Element>[?byRel];

    for (final a in doc.querySelectorAll('a')) {
      final t = _oneLine(a.text).toLowerCase();
      if (t == 'next' || t == 'next page' || t == '›' || t == '»') {
        candidates.add(a);
      }
    }

    for (final a in candidates) {
      final href = a.attributes['href'];
      if (href == null ||
          href.isEmpty ||
          href.startsWith('#') ||
          href.startsWith('javascript:')) {
        continue;
      }
      final uri = pageUri.resolve(href).removeFragment();
      if (uri.host != pageUri.host) continue;
      if (uri.toString() == pageUri.toString()) continue;
      return uri.toString();
    }
    return null;
  }

  static String? _embeddedBoardLink(String html) {
    // Some pages write addresses as https:\/\/..., so fix those first
    final text = html.replaceAll(r'\/', '/');

    for (final m in RegExp(r'''https?://[^\s"'<>\\]+''').allMatches(text)) {
      final url = m.group(0)!.replaceAll(RegExp(r'[.,;)]+$'), '');
      final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';

      final isBoard = host == 'boards.greenhouse.io' ||
          host == 'job-boards.greenhouse.io' ||
          host == 'jobs.lever.co' ||
          host == 'jobs.ashbyhq.com' ||
          host.endsWith('.myworkdayjobs.com');

      if (isBoard) return url;
    }
    return null;
  }

  // Use the right API for a known board
  static Future<List<Job>> _fetchFromBoard(
      Company c, Map<String, Job> known, bool quick) async {
    switch (detectBoard(c.link)) {
      case 'greenhouse':
        return _fetchGreenhouse(c);
      case 'lever':
        return _fetchLever(c);
      case 'ashby':
        return _fetchAshby(c);
      case 'workday':
        return _fetchWorkday(c, known, quick);
      default:
        return [];
    }
  }

  // ONE "view all jobs" style link on a landing page (null if none or several)
  static String? _findJobsHopLink(Document doc, Uri pageUri) {
    final found = <String>{};

    for (final a in doc.querySelectorAll('a')) {
      final text = _oneLine(a.text).toLowerCase();
      if (!_hopPhrases.contains(text)) continue;

      final href = a.attributes['href'];
      if (href == null ||
          href.isEmpty ||
          href.startsWith('#') ||
          href.startsWith('javascript:') ||
          href.startsWith('mailto:')) {
        continue;
      }

      final uri = pageUri.resolve(href).removeFragment();
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;
      if (uri.toString() == pageUri.toString()) continue;

      found.add(uri.toString());
    }

    // Exactly one candidate → safe to follow. Several → we'd be guessing.
    return found.length == 1 ? found.first : null;
  }

  static String? _balancedObject(String text, int start) {
    var depth = 0;
    var inString = false;

    for (var i = start; i < text.length; i++) {
      final c = text[i];

      if (inString) {
        if (c == '\\') {
          i++; // skip the escaped character
        } else if (c == '"') {
          inString = false;
        }
      } else {
        if (c == '"') {
          inString = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) return text.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  // The jobs hidden in one Phenom page: {'jobs': [...], 'total': 23}
  static Map<String, dynamic>? _phenomData(String html) {
    final key = RegExp(r'"eagerLoadRefineSearch"\s*:\s*\{').firstMatch(html);
    if (key == null) return null;

    final block = _balancedObject(html, key.end - 1); // the '{' of the block
    if (block == null) return null;

    try {
      final data = jsonDecode(block);
      final List jobs = data['data']?['jobs'] ?? [];
      if (jobs.isEmpty) return null;

      return {
        'jobs': jobs,
        'total': int.tryParse('${data['totalHits']}') ?? jobs.length,
      };
    } catch (_) {
      return null;
    }
  }

  // "2026-10-14T12:55:11.878+0000" → a date (some versions of Dart want +00:00)
  static DateTime? _parseIsoDate(String? text) {
    if (text == null) return null;
    return DateTime.tryParse(text) ??
        DateTime.tryParse(text.replaceFirstMapped(
            RegExp(r'([+-]\d\d)(\d\d)$'), (m) => '${m[1]}:${m[2]}'));
  }

  static Job _phenomJob(Company company, Map<String, dynamic> j) {
    final title = _str(j['title']) ?? 'Untitled';

    final multi = j['multi_location'];
    final places = multi is List
        ? multi.map((e) => _str(e)).whereType<String>().toList()
        : <String>[];
    final location =
        places.isNotEmpty ? places.take(2).join(' | ') : (_str(j['location']) ?? 'Not specified');

    final parser = j['ml_job_parser'];
    final moreText =
        parser is Map ? (_str(parser['descriptionTeaser_ats']) ?? '') : '';
    final teaser = _str(j['descriptionTeaser']) ?? '';

    final business = _str(j['_jobPostingBusinessLabel']);
    final employer = _str(j['companyName']);
    final reqId = _str(j['reqId'] ?? j['jobId']);
    final kind = [_str(j['_timeTypeLabel']), _str(j['_workerSubTypeLabel'])]
        .whereType<String>()
        .join(' · ');

    final description = [
      teaser,
      if (business != null) 'Business: $business',
      if (employer != null) 'Employer: $employer',
      if (kind.isNotEmpty) 'Type: $kind',
      if (reqId != null) 'Job ID: $reqId',
      '(Open in browser to read the full description)',
    ].where((s) => s.isNotEmpty).join('\n\n');

    // The "apply" address minus /apply = the job's own page
    var url = _str(j['applyUrl']) ?? company.link;
    if (url.endsWith('/apply')) {
      url = url.substring(0, url.length - '/apply'.length);
    }

    return Job(
      id: '${company.id}_${_str(j['jobSeqNo']) ?? reqId ?? title}',
      companyId: company.id,
      companyName: company.name,
      title: title,
      role: _str(j['category']) ?? _guessRole(title),
      location: location,
      mode: _guessMode('$location $title', '$teaser $moreText'),
      description: description,
      url: url,
      postedDate: _parseIsoDate(_str(j['postedDate'])) ?? DateTime.now(),
    );
  }

  // Read the job list from the first page, then follow "next" links
  static Future<List<Job>> _fetchPhenom(
      Company company, String firstHtml, Uri firstUri, bool quick) async {
    final jobs = <Job>[];
    final seen = <String>{};
    var html = firstHtml;
    var uri = firstUri;
    final maxPages = quick ? 1 : 10; // 10 jobs per page

    for (var page = 1; page <= maxPages; page++) {
      final data = _phenomData(html);
      if (data == null) break;

      for (final raw in data['jobs'] as List) {
        final job = _phenomJob(company, Map<String, dynamic>.from(raw as Map));
        if (seen.add(job.id)) jobs.add(job);
      }

      final total = data['total'] as int;
      if (jobs.length >= total || jobs.length >= maxJobsPerCompany) break;

      final next = _nextPageUrl(parse(html), uri);
      if (next == null) break;
      try {
        uri = Uri.parse(next);
        html = await _getHtml(next);
      } catch (_) {
        break; // keep the jobs we already have
      }
    }
    return jobs;
  }

  // ---------- Reading the hidden JobPosting data ----------

  // Find every JobPosting hidden in the page
  static List<Map<String, dynamic>> _jobPostings(Document doc) {
    final found = <Map<String, dynamic>>[];

    for (final script
        in doc.querySelectorAll('script[type="application/ld+json"]')) {
      try {
        _collectPostings(jsonDecode(script.text), found);
      } catch (_) {
        // Broken JSON on one script: ignore it and move on
      }
    }
    return found;
  }

  // The data can be nested in lists and sub-objects, so we search it
  // by calling this function on each piece (recursion)
  static void _collectPostings(dynamic node, List<Map<String, dynamic>> out) {
    if (node is List) {
      for (final item in node) {
        _collectPostings(item, out);
      }
    } else if (node is Map) {
      final type = node['@type'];
      final isJob =
          type == 'JobPosting' || (type is List && type.contains('JobPosting'));

      if (isJob) {
        out.add(Map<String, dynamic>.from(node));
      } else {
        for (final value in node.values) {
          if (value is List || value is Map) _collectPostings(value, out);
        }
      }
    }
  }

  // Safely turn "anything" into text (or null if empty)
  static String? _str(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is num) return v.toString();
    if (v is Map) return _str(v['name'] ?? v['value']);
    return null;
  }

  // "San Francisco, CA, US" from the jobLocation data
  static String _postingLocation(Map<String, dynamic> p) {
    final raw = p['jobLocation'];
    final List list = raw is List ? raw : (raw == null ? [] : [raw]);
    final places = <String>[];

    for (final loc in list) {
      if (loc is! Map) continue;
      final addr = loc['address'];

      if (addr is Map) {
        final parts = [
          _str(addr['addressLocality']),
          _str(addr['addressRegion']),
          _str(addr['addressCountry']),
        ].whereType<String>().toList();
        if (parts.isNotEmpty) places.add(parts.join(', '));
      } else {
        final s = _str(addr) ?? _str(loc['name']);
        if (s != null) places.add(s);
      }
    }

    if (places.isEmpty) {
      final isRemote =
          (_str(p['jobLocationType']) ?? '').toUpperCase() == 'TELECOMMUTE';
      return isRemote ? 'Remote' : 'Not specified';
    }
    return places.take(2).join(' | ');
  }

  // Turn one JobPosting into our Job class
  static Job _jobFromPosting(
      Company company, Map<String, dynamic> p, String? id, String fallbackUrl) {
    final title = _str(p['title']) ?? 'Untitled';
    final description = htmlToText(_str(p['description']) ?? '');
    final location = _postingLocation(p);
    final postingUrl = _str(p['url']);

    final isRemote =
        (_str(p['jobLocationType']) ?? '').toUpperCase() == 'TELECOMMUTE';
    final mode =
        isRemote ? 'Remote' : _guessMode('$location $title', description);

    return Job(
      id: id ?? '${company.id}_${postingUrl ?? '$title|$location'}',
      companyId: company.id,
      companyName: company.name,
      title: title,
      role: _str(p['occupationalCategory']) ?? _guessRole(title),
      location: location,
      mode: mode,
      description: _shorten(description),
      url: postingUrl ?? fallbackUrl,
      postedDate: DateTime.tryParse(_str(p['datePosted']) ?? '') ??
          DateTime.now(),
    );
  }

  // ---------- Finding job-looking links ----------

  static List<_JobLink> _findJobLinks(Document doc, Uri pageUri) {
    final seen = <String>{};
    final strong = <_JobLink>[]; // address contains an ID number
    final weak = <_JobLink>[];   // other links that look like jobs

    String bareHost(String h) => h.replaceFirst('www.', '');

    for (final a in doc.querySelectorAll('a')) {
      final href = a.attributes['href'];
      if (href == null || href.isEmpty) continue;
      if (href.startsWith('#') ||
          href.startsWith('mailto:') ||
          href.startsWith('tel:') ||
          href.startsWith('javascript:')) {
        continue;
      }

      final uri = pageUri.resolve(href).removeFragment();
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;
      if (bareHost(uri.host) != bareHost(pageUri.host)) continue;
      if (uri.path == pageUri.path) continue;

      // NEW: skip filter, menu and login pages
      final segments = uri.pathSegments
          .where((s) => s.isNotEmpty)
          .map((s) => s.toLowerCase())
          .toList();
      if (segments.any((s) => _skipPathWords.contains(s))) continue;

      final lines = a.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final title = lines.first.replaceAll(RegExp(r'\s+'), ' ');
      if (title.length < 5 || title.length > 120) continue;
      if (_skipTitles.contains(title.toLowerCase())) continue;

      final path = uri.path.toLowerCase();
      final hasJobWord = _jobWords.any((w) => path.contains(w));
      final hasId = RegExp(r'\d{3,}').hasMatch(path);
      final deepEnough = segments.length >= 2;
      if (!hasJobWord || !(hasId || deepEnough)) continue;

      if (!seen.add(uri.toString())) continue;

      // NEW: read location and date from the "card" around the link
      final card = _cardAround(a);
      final link = _JobLink(
        uri.toString(),
        title,
        card == null ? '' : _cardLocation(card),
        card == null ? null : _cardDate(card),
      );

      if (hasId) {
        strong.add(link);
      } else {
        weak.add(link);
      }
    }

    // 3 or more ID-style links → trust only those
    final chosen = strong.length >= 3 ? strong : [...strong, ...weak];
    return chosen.take(maxGenericLinks).toList();
  }

  // The nearest <li>, <article> or <tr> around a link = the job's "card"
  static Element? _cardAround(Element a) {
    Element? e = a.parent;
    for (var i = 0; i < 6 && e != null; i++) {
      final tag = e.localName;
      if (tag == 'li' || tag == 'article' || tag == 'tr') return e;
      e = e.parent;
    }
    return null;
  }

  static String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Many sites mark the location with a class like "listing-location"
  static String _cardLocation(Element card) {
    final el = card.querySelector('[class*="location"]');
    return el == null ? '' : _oneLine(el.text);
  }

  // Posted date: a <time datetime="..."> tag, or a date written in the text
  static DateTime? _cardDate(Element card) {
    final t = card.querySelector('time[datetime]');
    final fromTag = DateTime.tryParse(t?.attributes['datetime'] ?? '');
    if (fromTag != null) return fromTag;
    return _parseTextDate(card.text);
  }

  // "14 October 2026" or "October 14, 2026" → a real date
  static DateTime? _parseTextDate(String text) {
    final t = text.toLowerCase();
    const month = r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?';

    var m = RegExp(r'(\d{1,2})\s+' + month + r',?\s+(\d{4})').firstMatch(t);
    if (m != null) {
      return DateTime(int.parse(m.group(3)!),
          _months.indexOf(m.group(2)!) + 1, int.parse(m.group(1)!));
    }

    m = RegExp(month + r'\s+(\d{1,2}),?\s+(\d{4})').firstMatch(t);
    if (m != null) {
      return DateTime(int.parse(m.group(3)!),
          _months.indexOf(m.group(1)!) + 1, int.parse(m.group(2)!));
    }
    return null;
  }

  // The readable text of a job page (used when there's no JobPosting data)
  static String _pageText(Document doc) {
    // Throw away the parts that are never the job description
    for (final tag in ['script', 'style', 'nav', 'header', 'footer', 'noscript']) {
      for (final e in doc.querySelectorAll(tag)) {
        e.remove();
      }
    }

    const selectors = [
      '[class*="description"]',
      '[itemprop="description"]',
      'article',
      'main',
      'body',
    ];

    for (final s in selectors) {
      final el = doc.querySelector(s);
      if (el == null) continue;

      final text = el.text
          .split('\n')
          .map((l) => _oneLine(l))
          .where((l) => l.isNotEmpty)
          .join('\n');

      if (text.length > 200) return text; // long enough to be real
    }
    return '';
  }

  // ---------- Putting it together ----------

  static Future<List<Job>> _fetchGeneric(
      Company company, Map<String, Job> known, bool quick,
      {bool canHop = true}) async {
    var pageUri = Uri.parse(company.link);
    final firstUri = pageUri;
    final firstHtml = await _getHtml(company.link);
    var doc = parse(firstHtml);
    final firstDoc = doc;

    // LEVEL 1: JobPosting data on the page itself
    final onPage = _jobPostings(doc);
    print('Generic ${company.name}: ${onPage.length} postings on page');
    if (onPage.isNotEmpty) {
      return onPage
          .map((p) => _jobFromPosting(company, p, null, company.link))
          .toList();
    }

    // LEVEL 1.2: Phenom career sites keep their job list inside the page
    if (firstHtml.contains('eagerLoadRefineSearch')) {
      final phenomJobs =
          await _fetchPhenom(company, firstHtml, firstUri, quick);
      print('Generic ${company.name}: Phenom data has ${phenomJobs.length} jobs');
      if (phenomJobs.isNotEmpty) return phenomJobs;
    }

    // LEVEL 1.5: a known job board hiding inside the page
    final boardLink = _embeddedBoardLink(firstHtml);
    if (boardLink != null) {
      try {
        final viaBoard = await _fetchFromBoard(
          Company(id: company.id, name: company.name, link: boardLink),
          known,
          quick,
        );
        print('Generic ${company.name}: board found inside page ($boardLink)');
        if (viaBoard.isNotEmpty) return viaBoard;
      } catch (_) {
        // The board didn't work out: carry on with the other levels
      }
    }

    // LEVEL 2: collect job links from up to 3 pages
    final collected = <_JobLink>[];
    final seenUrls = <String>{};
    final maxPages = quick ? 1 : 3;

    for (var page = 1; page <= maxPages; page++) {
      for (final l in _findJobLinks(doc, pageUri)) {
        if (seenUrls.add(l.url)) collected.add(l);
      }
      if (collected.length >= maxGenericLinks) break;

      final next = _nextPageUrl(doc, pageUri);
      if (next == null || page == maxPages) break;
      try {
        pageUri = Uri.parse(next);
        doc = parse(await _getHtml(next));
      } catch (_) {
        break;
      }
    }

    print('Generic ${company.name}: ${collected.length} job links');

    if (collected.isEmpty) {
      // LEVEL 2.5: landing page with ONE "view all jobs" link → follow it once
      if (canHop) {
        final hop = _findJobsHopLink(firstDoc, firstUri);
        if (hop != null) {
          print('Generic ${company.name}: following "view jobs" link to $hop');
          return _fetchGeneric(
            Company(id: company.id, name: company.name, link: hop),
            known,
            quick,
            canHop: false, // follow only ONE link, never a chain
          );
        }
      }

      if (firstHtml.contains('phenompeople.com')) {
        throw Exception('This looks like a landing page whose jobs are loaded '
            'by JavaScript, which this app cannot read. Open the job search '
            'page of the site, filter it (for example by company or brand), '
            'and paste that link instead.');
      }
      throw Exception('No jobs found on this page. It may load its jobs with '
          'JavaScript, which this app cannot read. If a job on this site has '
          'an Apply button, try the link it opens.');
    }

    var links = collected.take(maxGenericLinks).toList();
    if (quick) links = links.take(3).toList();

    final jobs = <Job>[];
    final pending = <_JobLink>[];

    for (final link in links) {
      final old = known['${company.id}_${link.url}'];
      if (old != null && !old.description.startsWith('Details could not')) {
        jobs.add(old);
      } else {
        pending.add(link);
      }
    }

    for (var i = 0; i < pending.length; i += 3) {
      final end = (i + 3 > pending.length) ? pending.length : i + 3;
      final results = await Future.wait(
        pending.sublist(i, end).map((l) => _genericJob(company, l)),
      );
      jobs.addAll(results);
    }
    return jobs;
  }

  // Open ONE job link and build a Job from it
  static Future<Job> _genericJob(Company company, _JobLink link) async {
    final id = '${company.id}_${link.url}';
    var description = '';

    try {
      final doc = parse(await _getHtml(link.url));
      final postings = _jobPostings(doc);
      if (postings.isNotEmpty) {
        return _jobFromPosting(company, postings.first, id, link.url);
      }
      description = _pageText(doc); // LEVEL 3: use the page's own text
    } catch (_) {
      // Page failed to load: use what the link told us
    }

    final location = link.location.isEmpty ? 'Not specified' : link.location;

    return Job(
      id: id,
      companyId: company.id,
      companyName: company.name,
      title: link.title,
      role: _guessRole(link.title),
      location: location,
      mode: _guessMode('$location ${link.title}', description),
      description: description.isEmpty
          ? 'Details could not be read automatically. Open in browser to read this job.'
          : _shorten(description),
      url: link.url,
      postedDate: link.date ?? DateTime.now(),
    );
  }

static Future<dynamic> _postJson(
      String url, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body), // Map → text
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Server replied ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // Pull host, tenant and site out of the link
  static Map<String, String> _workdayParts(Company company) {
    final uri = Uri.parse(company.link);
    final host = uri.host;                  // nvidia.wd5.myworkdayjobs.com
    final tenant = host.split('.').first;   // nvidia

    // Language codes look like "en", "en-US", "fr_CA": skip those
    final languageCode = RegExp(r'^[a-z]{2}([-_][A-Za-z]{2})?$');

    String? site;
    for (final segment in uri.pathSegments) {
      if (segment.isEmpty || languageCode.hasMatch(segment)) continue;
      site = segment;
      break;
    }
    if (site == null) {
      throw Exception('Could not find the site name in the link');
    }
    return {'host': host, 'tenant': tenant, 'site': site};
  }

  // "Posted 3 Days Ago" → a real date
  static DateTime _parseWorkdayPosted(String text) {
    final t = text.toLowerCase();
    final now = DateTime.now();

    if (t.contains('today')) return now;
    if (t.contains('yesterday')) return now.subtract(const Duration(days: 1));

    final match = RegExp(r'(\d+)\+?\s*day').firstMatch(t);
    if (match != null) {
      return now.subtract(Duration(days: int.parse(match.group(1)!)));
    }
    return now;
  }

  static Future<List<Job>> _fetchWorkday(
      Company company, Map<String, Job> known, bool quick) async {
    final limit = quick ? 3 : maxJobsPerCompany; 
    final parts = _workdayParts(company);
    final base =
        'https://${parts['host']}/wday/cxs/${parts['tenant']}/${parts['site']}';

    // ---- Step 1: collect the job list, 20 per page ----
    final listings = <Map<String, dynamic>>[];
    var offset = 0;
    var total = 0;

    while (listings.length < limit) { 
      final data = await _postJson('$base/jobs', {
        'appliedFacets': {},
        'limit': 20,
        'offset': offset,
        'searchText': '',
      });

      // Workday only reports the total on the first page
      if (offset == 0) {
        total = int.tryParse(data['total'].toString()) ?? 0;
      }

      final List postings = data['jobPostings'] ?? [];
      if (postings.isEmpty) break;

      for (final p in postings) {
        listings.add(Map<String, dynamic>.from(p));
      }

      offset += 20;
      if (offset >= total || postings.length < 20) break; // no more pages
    }

    final wanted = listings.take(limit).toList(); 

    // ---- Step 2: split into "already known" and "new" ----
    final jobs = <Job>[];
    final pending = <Map<String, dynamic>>[];

    for (final p in wanted) {
      final id = '${company.id}_${p['externalPath']}';
      final old = known[id];
      if (old != null && !old.description.startsWith('Details could not')) {
        jobs.add(old);   // seen before → reuse, no download needed
      } else {
        pending.add(p);
      }
    }

    print('Workday ${company.name}: ${jobs.length} reused, ${pending.length} new');    

    // ---- Step 3: download details for new jobs, 5 at a time ----
    for (var i = 0; i < pending.length; i += 5) {
      final end = (i + 5 > pending.length) ? pending.length : i + 5;
      final batch = pending.sublist(i, end);

      final results = await Future.wait(
        batch.map((p) => _workdayJob(company, parts, base, p)),
      );
      jobs.addAll(results);
    }

    return jobs;
  }

  // Build ONE Job: list info + (if possible) the detail page
  static Future<Job> _workdayJob(Company company, Map<String, String> parts,
      String base, Map<String, dynamic> p) async {
    final path = (p['externalPath'] ?? '').toString();
    final title = (p['title'] ?? 'Untitled').toString();

    var location = (p['locationsText'] ?? 'Not specified').toString();
    var description = '';
    String? remoteType;
    String? url;
    var date = _parseWorkdayPosted((p['postedOn'] ?? '').toString());

    try {
      final data = await _getJson('$base$path');
      final info = data['jobPostingInfo'] ?? {};

      description = htmlToText((info['jobDescription'] ?? '').toString());
      location = (info['location'] ?? location).toString();
      remoteType = info['remoteType']?.toString();
      url = info['externalUrl']?.toString();

      final start = DateTime.tryParse((info['startDate'] ?? '').toString());
      if (start != null) date = start;
    } catch (_) {
      // One broken job must not break the whole sync
      description =
          'Details could not be loaded. Open in browser to read this job.';
    }

    // Mode: use Workday's own field first, then guess
    final r = (remoteType ?? '').toLowerCase();
    String mode;
    if (r.contains('remote')) {
      mode = 'Remote';
    } else if (r.contains('hybrid') || r.contains('flex')) {
      mode = 'Hybrid';
    } else if (r.contains('on-site') ||
        r.contains('onsite') ||
        r.contains('on site')) {
      mode = 'On-site';
    } else {
      mode = _guessMode('$location $title', description);
    }

    return Job(
      id: '${company.id}_$path',
      companyId: company.id,
      companyName: company.name,
      title: title,
      role: _guessRole(title),
      location: location,
      mode: mode,
      description: _shorten(description),
      url: url ?? 'https://${parts['host']}/${parts['site']}$path',
      postedDate: date,
    );
  }
}

// A link that looks like a job
class _JobLink {
  final String url;
  final String title;
  final String location; // '' if we couldn't find one
  final DateTime? date;  // null if we couldn't find one

  _JobLink(this.url, this.title, this.location, this.date);
}