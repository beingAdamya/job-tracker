class Job {
  final String id;
  final String companyId;    // which company this job belongs to
  String companyName;
  final String title;        // e.g. "Software Engineer"
  final String role;         // e.g. "Engineering" (department)
  final String location;     // e.g. "Bengaluru"
  final String mode;         // "On-site", "Remote" or "Hybrid"
  final String description;  // full details + requirements
  final String url;          // link to open in browser
  final DateTime postedDate;
  bool isFavourite;
  bool isRemoved;
  bool noLongerListed;
    
    Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'companyName': companyName,
      'title': title,
      'role': role,
      'location': location,
      'mode': mode,
      'description': description,
      'url': url,
      'postedDate': postedDate.toIso8601String(), // date → text
      'isFavourite': isFavourite,
      'isRemoved': isRemoved,
      'noLongerListed': noLongerListed,
    };
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      companyId: json['companyId'],
      companyName: json['companyName'],
      title: json['title'],
      role: json['role'],
      location: json['location'],
      mode: json['mode'],
      description: json['description'],
      url: json['url'],
      postedDate: DateTime.parse(json['postedDate']), // text → date
      isFavourite: json['isFavourite'] ?? false,
      isRemoved: json['isRemoved'] ?? false,
      noLongerListed: json['noLongerListed'] ?? false,
    );
  }

  Job({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.role,
    required this.location,
    required this.mode,
    required this.description,
    required this.url,
    required this.postedDate,
    this.isFavourite = false,
    this.isRemoved = false,
    this.noLongerListed = false,
  });
}