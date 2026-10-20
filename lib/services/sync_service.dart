import 'dart:async';
import '../models/job.dart';
import 'job_fetcher.dart';
import 'settings_service.dart';
import 'storage_service.dart';

// What happened during a sync
class SyncResult {
  final List<Job> newJobs;     // every job we had not seen before
  final List<Job> notifiable;  // the new jobs worth a notification
  final List<String> errors;   // e.g. "Stripe: Server replied 404"

  SyncResult(this.newJobs, this.notifiable, this.errors);
}

class SyncService {
  // A "new" job posted longer ago than this probably just slid back into
  // the window (for example after raising the job limit): no notification
  static const int freshDays = 14;

  static bool _isFresh(Job job) {
    return DateTime.now().difference(job.postedDate).inDays <= freshDays;
  }

  static Future<SyncResult> syncAll() async {
    // Use the "jobs per company" chosen in Settings
    final settings = await SettingsService.load();
    JobFetcher.maxJobsPerCompany = settings.maxJobs;

    final companies = await StorageService.loadCompanies();
    final savedJobs = await StorageService.loadJobs();

    final savedById = {for (final j in savedJobs) j.id: j};

    final List<Job> finalList = [];
    final List<Job> newJobs = [];
    final List<Job> notifiable = [];
    final List<String> errors = [];

    for (final company in companies) {
      // A company's very first sync makes every job "new": stay silent
      final hadJobsBefore = savedJobs.any((j) => j.companyId == company.id);

      try {
        final fetched = await JobFetcher.fetch(company, known: savedById);

        for (final job in fetched) {
          final old = savedById[job.id];
          if (old == null) {
            newJobs.add(job); // never seen before
            if (hadJobsBefore && !company.isMuted && _isFresh(job)) {
              notifiable.add(job);
            }
          } else {
            job.isFavourite = old.isFavourite; // keep the user's choices
            job.isRemoved = old.isRemoved;
          }
          job.noLongerListed = false;
          finalList.add(job);
        }

        // Starred jobs that are no longer listed: keep them, marked
        final fetchedIds = fetched.map((j) => j.id).toSet();
        for (final old in savedJobs) {
          if (old.companyId == company.id &&
              old.isFavourite &&
              !fetchedIds.contains(old.id)) {
            old.noLongerListed = true;
            finalList.add(old);
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