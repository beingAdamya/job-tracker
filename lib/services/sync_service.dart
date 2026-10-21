import 'dart:async';
import '../models/job.dart';
import 'job_fetcher.dart';
import 'settings_service.dart';
import 'storage_service.dart';

class SyncResult {
  final List<Job> newJobs; // every job we had not seen before
  final List<Job> notifiable; // the new jobs worth a notification
  final List<String> errors; // e.g. "Stripe: Server replied 404"

  SyncResult(this.newJobs, this.notifiable, this.errors);
}

class SyncService {
  // A "new" job posted longer ago than this probably just slid back into
  // the window: no notification
  static const int freshDays = 14;

  // Jobs the website stopped listing stay this long (favourites stay)
  static const int unavailableKeepDays = 7;

  // At most this many job pages are opened per company per sync
  static const int maxPageChecks = 10;

  static bool isFresh(Job job) {
    return DateTime.now().difference(job.postedDate).inDays <= freshDays;
  }

  static Future<SyncResult> syncAll() async {
    final settings = await SettingsService.load();
    JobFetcher.maxJobsPerCompany = settings.maxJobs;

    final companies = await StorageService.loadCompanies();
    final savedJobs = await StorageService.loadJobs();
    final savedById = {for (final j in savedJobs) j.id: j};
    final now = DateTime.now();

    final List<Job> finalList = [];
    final List<Job> newJobs = [];
    final List<Job> notifiable = [];
    final List<String> errors = [];

    for (final company in companies) {
      // A company's very first sync makes every job "new": stay silent
      final hadJobsBefore = savedJobs.any((j) => j.companyId == company.id);

      try {
        final result = await JobFetcher.fetch(company,
            known: savedById, maxAgeDays: settings.maxAgeDays);
        final fetched = result.jobs;

        for (final job in fetched) {
          final old = savedById[job.id];
          if (old == null) {
            newJobs.add(job);
            if (hadJobsBefore && !company.isMuted && isFresh(job)) {
              notifiable.add(job);
            }
          } else {
            job.isFavourite = old.isFavourite; // keep the user's choices
            job.isRemoved = old.isRemoved;
          }
          job.unavailableSince = null; // it is listed right now
          finalList.add(job);
        }

        // An empty list is more likely an outage than a company closing
        // every job, so then we never mark anything as unavailable
        final trustList = result.complete && result.seenIds.isNotEmpty;

        // Saved jobs of this company that are not in the new list
        final keptIds = fetched.map((j) => j.id).toSet();
        var checks = 0;

        for (final old in savedJobs) {
          if (old.companyId != company.id || keptIds.contains(old.id)) continue;
          if (old.isRemoved) continue; // you removed it: no need to keep

          // Still on the website, only outside your age window or job limit
          if (result.seenIds.contains(old.id)) {
            if (old.isFavourite) {
              old.unavailableSince = null;
              finalList.add(old);
            }
            continue;
          }

          // Not on the website any more?
          var gone = trustList;
          if (!gone && old.isFavourite && checks < maxPageChecks) {
            checks++;
            gone = await JobFetcher.pageIsGone(old.url);
          }

          if (gone) {
            old.unavailableSince ??= now;
            final expired = !old.isFavourite &&
                now.difference(old.unavailableSince!).inDays >=
                    unavailableKeepDays;
            if (!expired) finalList.add(old);
          } else if (old.isFavourite) {
            finalList.add(old); // cannot tell: keep favourites as they are
          }
        }
      } catch (e) {
        String message;
        if (e is TimeoutException) {
          message = 'Took too long to respond. Check your internet and try again.';
        } else {
          message = e.toString().replaceFirst('Exception: ', '');
        }
        errors.add('${company.name}: $message');

        // Fetch failed → keep what we already had for this company
        finalList.addAll(savedJobs.where((j) => j.companyId == company.id));
      }
    }

    await StorageService.saveJobs(finalList);
    return SyncResult(newJobs, notifiable, errors);
  }
}