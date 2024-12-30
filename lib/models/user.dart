class User {
  final String id;
  final String name;
  final String password;
  final bool isOnline;
  final DateTime lastSeen;
  final List<String> friendIds;

  User({
    required this.id,
    required this.name,
    required this.password,
    required this.isOnline,
    required this.lastSeen,
    this.friendIds = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      password: json['password'],
      isOnline: json['isOnline'],
      lastSeen: DateTime.parse(json['lastSeen']),
      friendIds: List<String>.from(json['friendIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'friendIds': friendIds,
    };
  }
} 