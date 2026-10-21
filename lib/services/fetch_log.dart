import '../models/company.dart';

// A short diary of one check: what was tried and what was found
class FetchLog {
  final String companyName;
  final String link;
  final List<String> lines = [];

  FetchLog(this.companyName, this.link);

  // The log of the check running right now (checks run one at a time)
  static FetchLog current = FetchLog('', '');

  static FetchLog start(Company c) {
    current = FetchLog(c.name, c.link);
    return current;
  }

  // Add a line to the current log from anywhere
  static void note(String line) => current.add(line);

  void add(String line) {
    if (lines.length < 60) lines.add(line);
  }
}