class Job {
  final String id;
  final String companyId;
  String companyName;
  final String title;
  final String role;
  final String location;
  final String mode;
  final String description;
  final String url;
  final DateTime postedDate;
  bool isFavourite;
  bool isRemoved;
  DateTime? unavailableSince; // when we noticed the website stopped listing it

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
    this.unavailableSince,
  });

  // true = the website no longer lists this job
  bool get noLongerListed => unavailableSince != null;

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
      'postedDate': postedDate.toIso8601String(),
      'isFavourite': isFavourite,
      'isRemoved': isRemoved,
      'unavailableSince': unavailableSince?.toIso8601String(),
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
      postedDate: DateTime.parse(json['postedDate']),
      isFavourite: json['isFavourite'] ?? false,
      isRemoved: json['isRemoved'] ?? false,
      unavailableSince:
          DateTime.tryParse((json['unavailableSince'] ?? '').toString()),
    );
  }
}