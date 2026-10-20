class Company {
  final String id;      // unique ID, never changes
  String name;    // e.g. "Stripe"
  String link;    // career page link
  bool isMuted;         // true = don't show its jobs
    
    // Object → Map (packing)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'link': link,
      'isMuted': isMuted,
    };
  }

  // Map → Object (unpacking)
  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'],
      link: json['link'],
      isMuted: json['isMuted'] ?? false,
    );
  }

  // Constructor: how to create a Company
  Company({
    required this.id,
    required this.name,
    required this.link,
    this.isMuted = false,   // default value if not given
  });
}