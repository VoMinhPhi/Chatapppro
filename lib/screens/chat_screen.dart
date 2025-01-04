import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/message.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Timer? _timer;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    
    // Đánh dấu tất cả tin nhắn là đã đọc khi mở chat
    final provider = context.read<ChatProvider>();
    provider.markAllMessagesAsRead(widget.receiverId);
    
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadMessages();
      }
    });
  }

  void _loadMessages() {
    context.read<ChatProvider>().getMessages(widget.receiverId);
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      context.read<ChatProvider>().sendMessage(
        _messageController.text,
        widget.receiverId,
      );
      _messageController.clear();
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await context.read<ChatProvider>().deleteMessage(messageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa tin nhắn: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.receiverName[0].toUpperCase(),
                style: TextStyle(color: Colors.blue[700]),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName),
                Consumer<ChatProvider>(
                  builder: (context, provider, child) {
                    final receiver = provider.users.firstWhere(
                      (u) => u.id == widget.receiverId,
                    );
                    return Text(
                      receiver.isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      final isMyMessage = message.senderId == chatProvider.userId;
                      return MessageBubble(
                        message: message,
                        senderName: isMyMessage ? 'Bạn' : widget.receiverName,
                        isMyMessage: isMyMessage,
                        onDelete: isMyMessage ? () => _deleteMessage(message.id) : null,
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue[700],
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMyMessage;
  final VoidCallback? onDelete;
  final String senderName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.onDelete,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
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
              if (!isMyMessage) ...[
                Text(
                  senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message.content,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isMyMessage) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 16,
                      color: message.isRead ? Colors.blue : Colors.grey[600],
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red[400],
                        ),
                      ),
                    ],
                  ],
                ],
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