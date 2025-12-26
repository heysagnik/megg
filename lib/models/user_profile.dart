class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final Map<String, dynamic> metadata;

  UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.metadata = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? json['full_name'],
      photoUrl: json['photo_url'] ?? json['avatar_url'] ?? json['picture'],
      metadata: json['metadata'] ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photo_url': photoUrl,
      'metadata': metadata,
    };
  }

  // Compatibility getter
  Map<String, dynamic> get userMetadata {
    final Map<String, dynamic> combined = Map.from(metadata);
    if (!combined.containsKey('name') && name != null) {
      combined['name'] = name;
    }
    if (!combined.containsKey('email') && email.isNotEmpty) {
      combined['email'] = email;
    }
    if (!combined.containsKey('avatar_url') && photoUrl != null) {
      combined['avatar_url'] = photoUrl;
    }
    return combined;
  }
}
