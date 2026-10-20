// Choices for the two frequency dropdowns: hours → label shown to the user
const Map<int, String> frequencyOptions = {
  1: '1 hour',
  12: '12 hours',
  24: '1 day',
  360: '15 days',
  720: '1 month',
};

// Choices for "jobs per company"
const List<int> jobLimitOptions = [50, 100, 200];

class AppSettings {
  int syncHours;
  int notifyHours;
  String keywords; // as typed: "python, remote, animator"
  int maxJobs;

  AppSettings({
    this.syncHours = 24,
    this.notifyHours = 24,
    this.keywords = '',
    this.maxJobs = 100,
  });

  // "Python, Remote" → ["python", "remote"]  (Lesson 7 uses this)
  List<String> get keywordList {
    return keywords
        .split(',')
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'syncHours': syncHours,
      'notifyHours': notifyHours,
      'keywords': keywords,
      'maxJobs': maxJobs,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Accept a saved value only if it is still one of the allowed options
    int pick(dynamic value, Iterable<int> allowed, int fallback) {
      return (value is int && allowed.contains(value)) ? value : fallback;
    }

    return AppSettings(
      syncHours: pick(json['syncHours'], frequencyOptions.keys, 24),
      notifyHours: pick(json['notifyHours'], frequencyOptions.keys, 24),
      keywords: (json['keywords'] ?? '').toString(),
      maxJobs: pick(json['maxJobs'], jobLimitOptions, 100),
    );
  }
}