import 'package:flutter_test/flutter_test.dart';
import 'package:job_tracker/models/app_settings.dart';
import 'package:job_tracker/models/company.dart';
import 'package:job_tracker/models/job.dart';
import 'package:job_tracker/services/board_detector.dart';
import 'package:job_tracker/services/job_fetcher.dart';
import 'package:job_tracker/services/job_keys.dart';
import 'package:job_tracker/services/sync_service.dart';

Job makeJob({
  String title = 'Engineer',
  String location = 'Mumbai',
  int daysAgo = 0,
}) {
  return Job(
    id: 'x',
    companyId: 'c',
    companyName: 'Co',
    title: title,
    role: 'R',
    location: location,
    mode: 'Remote',
    description: 'D',
    url: 'https://example.com',
    postedDate: DateTime.now().subtract(Duration(days: daysAgo)),
  );
}

void main() {
  group('AppSettings', () {
    test('splits and cleans notification keywords', () {
      final s = AppSettings(keywords: ' Python, Remote,, animator ,');
      expect(s.keywordList, ['python', 'remote', 'animator']);
    });

    test('falls back to defaults when saved values are not valid options', () {
      final s = AppSettings.fromJson({'syncHours': 7, 'maxJobs': 5});
      expect(s.syncHours, 24);
      expect(s.maxJobs, 100);
    });

    test('survives a save and load round trip', () {
      final original = AppSettings(
          syncHours: 12, notifyHours: 1, keywords: 'python', maxJobs: 200);
      final copy = AppSettings.fromJson(original.toJson());
      expect(copy.syncHours, 12);
      expect(copy.notifyHours, 1);
      expect(copy.keywords, 'python');
      expect(copy.maxJobs, 200);
    });
  });

  group('Company', () {
    test('keeps its fields through JSON', () {
      final c = Company(
        id: '1',
        name: 'ILM',
        link: 'https://example.com',
        isMuted: true,
      );
      final copy = Company.fromJson(c.toJson());
      expect(copy.id, '1');
      expect(copy.name, 'ILM');
      expect(copy.link, 'https://example.com');
      expect(copy.isMuted, true);
    });

    test('is not muted unless saved that way', () {
      final c = Company.fromJson(
          {'id': '1', 'name': 'Old', 'link': 'https://example.com'});
      expect(c.isMuted, false);
    });
  });
  group('Job', () {
    test('keeps every field through JSON, including the date', () {
      final job = Job(
        id: 'a_1',
        companyId: 'a',
        companyName: 'Stripe',
        title: 'Software Engineer',
        role: 'Engineering',
        location: 'Bengaluru, India',
        mode: 'Hybrid',
        description: 'Build things',
        url: 'https://example.com/job',
        postedDate: DateTime(2026, 10, 14),
        isFavourite: true,
        noLongerListed: true,
      );
      final copy = Job.fromJson(job.toJson());
      expect(copy.title, 'Software Engineer');
      expect(copy.mode, 'Hybrid');
      expect(copy.postedDate, DateTime(2026, 10, 14));
      expect(copy.isFavourite, true);
      expect(copy.isRemoved, false);
      expect(copy.noLongerListed, true);
    });
  });

  group('detectBoard', () {
    test('recognises the supported job boards', () {
      expect(detectBoard('https://boards.greenhouse.io/stripe'), 'greenhouse');
      expect(detectBoard('https://jobs.lever.co/spotify'), 'lever');
      expect(detectBoard('https://jobs.ashbyhq.com/notion'), 'ashby');
      expect(detectBoard('https://nvidia.wd5.myworkdayjobs.com/Site'), 'workday');
    });

    test('says unsupported for anything else', () {
      expect(detectBoard('https://example.com/careers'), 'unsupported');
    });
  });

  group('htmlToText', () {
    test('turns HTML into plain readable text', () {
      const html =
          '<p>Hello&nbsp;<b>world</b></p><ul><li>One</li><li>Two</li></ul>';
      expect(JobFetcher.htmlToText(html), 'Hello world\n• One\n• Two');
    });
  });

  group('SyncService.isFresh', () {
    test('a job posted yesterday is fresh', () {
      expect(SyncService.isFresh(makeJob(daysAgo: 1)), true);
    });

    test('a job posted today is fresh', () {
      expect(SyncService.isFresh(makeJob()), true);
    });

    test('a job posted 30 days ago is not fresh', () {
      expect(SyncService.isFresh(makeJob(daysAgo: 30)), false);
    });
  });

  group('duplicateKey', () {
    test('ignores capitals, punctuation and anything after the first comma', () {
      final a = makeJob(title: 'Senior Animator', location: 'San Francisco, CA');
      final b = makeJob(title: 'senior  animator!', location: 'san francisco, California');
      expect(duplicateKey(a), duplicateKey(b));
    });

    test('different cities give different keys', () {
      final a = makeJob(title: 'Animator', location: 'London, UK');
      final b = makeJob(title: 'Animator', location: 'Mumbai, India');
      expect(duplicateKey(a), isNot(duplicateKey(b)));
    });

    test('different titles give different keys', () {
      final a = makeJob(title: 'Animator');
      final b = makeJob(title: 'Compositor');
      expect(duplicateKey(a), isNot(duplicateKey(b)));
    });
  });

}