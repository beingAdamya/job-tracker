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

// Choices for "show jobs posted within": days → label (0 = any age)
const Map<int, String> jobAgeOptions = {
  7: '7 days',
  14: '14 days',
  30: '30 days',
  90: '3 months',
  180: '6 months',
  365: '1 year',
  0: 'Any age',
};

class AppSettings {
  int syncHours;
  int notifyHours;
  String keywords; // as typed: "python, remote, animator"
  int maxJobs;
  int maxAgeDays; // 0 = any age

  String themeMode; // 'system', 'light' or 'dark'
  bool customEnabled; // custom colours on top of the theme above
  int? customBg; // colours stored as numbers (null = not chosen)
  int? customText;
  int? customAccent;

  AppSettings({
    this.syncHours = 24,
    this.notifyHours = 24,
    this.keywords = '',
    this.maxJobs = 100,
    this.maxAgeDays = 0,
    this.themeMode = 'system',
    this.customEnabled = false,
    this.customBg,
    this.customText,
    this.customAccent,
  });

  // "Python, Remote" → ["python", "remote"]
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
      'maxAgeDays': maxAgeDays,
      'themeMode': themeMode,
      'customEnabled': customEnabled,
      'customBg': customBg,
      'customText': customText,
      'customAccent': customAccent,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Accept a saved value only if it is still one of the allowed options
    int pick(dynamic value, Iterable<int> allowed, int fallback) {
      return (value is int && allowed.contains(value)) ? value : fallback;
    }

    final mode = json['themeMode'];

    return AppSettings(
      syncHours: pick(json['syncHours'], frequencyOptions.keys, 24),
      notifyHours: pick(json['notifyHours'], frequencyOptions.keys, 24),
      keywords: (json['keywords'] ?? '').toString(),
      maxJobs: pick(json['maxJobs'], jobLimitOptions, 100),
      maxAgeDays: pick(json['maxAgeDays'], jobAgeOptions.keys, 0),
      themeMode: (mode == 'light' || mode == 'dark') ? mode : 'system',
      customEnabled: json['customEnabled'] == true,
      customBg: json['customBg'] is int ? json['customBg'] : null,
      customText: json['customText'] is int ? json['customText'] : null,
      customAccent: json['customAccent'] is int ? json['customAccent'] : null,
    );
  }
}