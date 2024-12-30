class UserNotification {
  final String id;
  final String type; // 'friend_request' hoặc 'message'
  final String fromUserId;
  final String toUserId;
  final DateTime timestamp;
  final bool isRead;

  UserNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.toUserId,
    required this.timestamp,
    this.isRead = false,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'],
      type: json['type'],
      fromUserId: json['fromUserId'],
      toUserId: json['toUserId'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }
} 