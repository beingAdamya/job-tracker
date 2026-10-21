import 'package:html/dom.dart';
import '../../models/company.dart';
import '../fetch_log.dart';
import 'common.dart';
import 'feed_extractor.dart';
import 'json_hunter.dart';

// Tries the "smart" ways of reading a page, in order
class SmartExtractors {
  static Future<ExtractResult?> tryAll(
      Company company, Document doc, String html, Uri pageUri) async {
    try {
      final feed = await FeedExtractor.find(company, doc, html, pageUri);
      if (feed != null && feed.jobs.isNotEmpty) return feed;
    } catch (e) {
      FetchLog.note('Feed check failed: $e');
    }

    try {
      final json = JsonHunter.find(company, doc, pageUri);
      if (json != null && json.jobs.isNotEmpty) return json;
    } catch (e) {
      FetchLog.note('JSON hunter failed: $e');
    }
    return null;
  }
}