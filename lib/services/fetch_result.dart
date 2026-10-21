import '../models/job.dart';

// What one check of a company's page returns
class FetchResult {
  final List<Job> jobs; // kept: inside your age window and job limit
  final Set<String> seenIds; // every job the page listed, before filtering
  final bool complete; // true = seenIds is the page's whole list

  FetchResult({
    required this.jobs,
    required this.seenIds,
    required this.complete,
  });
}