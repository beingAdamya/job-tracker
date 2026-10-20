import '../models/job.dart';

// "Senior Animator" in "San Francisco, CA" → "senioranimator|sanfrancisco"
// Two listings with the same key count as the same job.
String duplicateKey(Job j) {
  String clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  final city = j.location.split(',').first; // city only
  return '${clean(j.title)}|${clean(city)}';
}