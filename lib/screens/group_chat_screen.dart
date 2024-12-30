import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/group.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/add_member_dialog.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Kết nối WebSocket và join group
    final provider = context.read<ChatProvider>();
    provider.connectWebSocket();
    provider.joinGroup(widget.group.id);
    
    // Load tin nhắn cũ
    _loadInitialMessages();
  }

  Future<void> _loadInitialMessages() async {
    if (!mounted) return;
    await context.read<ChatProvider>().getGroupMessages(widget.group.id);
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      _messageController.clear();
      try {
        await context.read<ChatProvider>().sendGroupMessage(
          content,
          widget.group.id,
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  final messages = provider.getGroupMessagesById(widget.group.id);

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Chưa có tin nhắn nào'),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMyMessage = message.senderId == provider.userId;
                      final sender = provider.users.firstWhere(
                        (u) => u.id == message.senderId,
                        orElse: () => User(
                          id: message.senderId,
                          name: 'Unknown User',
                          password: '',
                          isOnline: false,
                          lastSeen: DateTime.now(),
                        ),
                      );

                      return MessageBubble(
                        message: message,
                        senderName: sender.name,
                        isMyMessage: isMyMessage,
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Rời khỏi group khi thoát màn hình
    context.read<ChatProvider>().leaveGroup(widget.group.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 