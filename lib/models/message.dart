class Message {
  final String id;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
} 