import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final String senderName;
  final bool isMyMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.senderName,
    required this.isMyMessage,
  });

  @override
  Widget build(BuildContext context) {
    print('Building message bubble - Content: ${message.content}, SenderId: ${message.senderId}, GroupId: ${message.groupId}');
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMyMessage ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isMyMessage ? Colors.blue[900] : Colors.grey[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.content,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
} 