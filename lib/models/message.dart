class Message {
  final String id;
  final String content;
  final DateTime timestamp;
  final String senderId;
  final String? receiverId;
  final String? groupId;
  final bool isRead;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.senderId,
    this.receiverId,
    this.groupId,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      groupId: json['groupId'],
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'senderId': senderId,
      'receiverId': receiverId,
      'groupId': groupId,
      'isRead': isRead,
    };
  }
} 