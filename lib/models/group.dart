class Group {
  final String id;
  final String name;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.memberIds,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      creatorId: json['creatorId'],
      memberIds: List<String>.from(json['memberIds']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creatorId': creatorId,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }
} 