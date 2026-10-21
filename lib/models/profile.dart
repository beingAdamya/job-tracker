class ProfileField {
  final String id;
  String label;
  String value;
  final String kind; // text, email, phone, url, multiline
  final bool isCustom; // added by the user (can be renamed and deleted)

  ProfileField({
    required this.id,
    required this.label,
    this.value = '',
    this.kind = 'text',
    this.isCustom = false,
  });
}

// The ready-made fields most application forms ask for
List<ProfileField> defaultProfileFields() => [
      ProfileField(id: 'fullName', label: 'Full name'),
      ProfileField(id: 'email', label: 'Email', kind: 'email'),
      ProfileField(id: 'phone', label: 'Phone', kind: 'phone'),
      ProfileField(id: 'location', label: 'Current location'),
      ProfileField(id: 'linkedin', label: 'LinkedIn', kind: 'url'),
      ProfileField(id: 'github', label: 'GitHub', kind: 'url'),
      ProfileField(id: 'portfolio', label: 'Portfolio / website', kind: 'url'),
      ProfileField(id: 'currentRole', label: 'Current role'),
      ProfileField(id: 'currentCompany', label: 'Current company'),
      ProfileField(id: 'experience', label: 'Total experience'),
      ProfileField(id: 'noticePeriod', label: 'Notice period'),
      ProfileField(id: 'currentSalary', label: 'Current salary'),
      ProfileField(id: 'expectedSalary', label: 'Expected salary'),
      ProfileField(id: 'education', label: 'Education', kind: 'multiline'),
      ProfileField(id: 'skills', label: 'Skills', kind: 'multiline'),
      ProfileField(id: 'about', label: 'About me', kind: 'multiline'),
    ];

class Profile {
  List<ProfileField> fields;
  String? cvPath; // the copy inside the app's private storage
  String? cvName; // original file name, for display
  DateTime? cvAdded;

  Profile({required this.fields, this.cvPath, this.cvName, this.cvAdded});

  factory Profile.empty() => Profile(fields: defaultProfileFields());

  Map<String, dynamic> toJson() {
    return {
      // ready-made fields: only the typed values are saved
      'values': {
        for (final f in fields.where((f) => !f.isCustom)) f.id: f.value
      },
      // user-made fields: saved completely
      'custom': [
        for (final f in fields.where((f) => f.isCustom))
          {'id': f.id, 'label': f.label, 'value': f.value}
      ],
      'cvPath': cvPath,
      'cvName': cvName,
      'cvAdded': cvAdded?.toIso8601String(),
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    final values = Map<String, dynamic>.from(json['values'] ?? {});

    // Start from the current ready-made list, so fields added in a future
    // version of the app appear automatically
    final fields = defaultProfileFields();
    for (final f in fields) {
      f.value = (values[f.id] ?? '').toString();
    }

    final List custom = json['custom'] ?? [];
    for (final c in custom) {
      fields.add(ProfileField(
        id: c['id'].toString(),
        label: (c['label'] ?? '').toString(),
        value: (c['value'] ?? '').toString(),
        isCustom: true,
      ));
    }

    return Profile(
      fields: fields,
      cvPath: json['cvPath'],
      cvName: json['cvName'],
      cvAdded: DateTime.tryParse((json['cvAdded'] ?? '').toString()),
    );
  }
}