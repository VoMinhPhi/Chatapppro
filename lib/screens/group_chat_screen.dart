import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/group.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/add_member_dialog.dart';
import '../widgets/member_list_dialog.dart';
import '../widgets/kick_member_dialog.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<ChatProvider>();
    provider.connectWebSocket();
    provider.setCurrentGroup(widget.group.id);
    
    _loadInitialMessages();
    
    provider.joinGroup(widget.group.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Chỉ rời khỏi nhóm WebSocket, không xóa tin nhắn
    context.read<ChatProvider>().leaveGroup(widget.group.id);
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    if (!mounted) return;
    
    try {
      await context.read<ChatProvider>().getGroupMessages(widget.group.id);
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải tin nhắn: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      try {
        final provider = context.read<ChatProvider>();
        await provider.sendGroupMessage(content, widget.group.id);
        _messageController.clear();
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi gửi tin nhắn: $e')),
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

  Widget _buildSystemMessage(Message message) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        message.content,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final isCreator = widget.group.creatorId == provider.userId;
    final canSendMessage = provider.canSendMessageInGroup(widget.group.id);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[700],
        title: Text(
          widget.group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'members':
                  showDialog(
                    context: context,
                    builder: (context) => MemberListDialog(
                      group: widget.group,
                      onKickMember: isCreator ? _showKickMemberDialog : null,
                    ),
                  );
                  break;
                case 'add':
                  showDialog(
                    context: context,
                    builder: (context) => AddMemberDialog(group: widget.group),
                  );
                  break;
                case 'leave':
                  await _leaveGroup();
                  break;
                case 'delete':
                  await _showDeleteGroupDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'members',
                child: ListTile(
                  leading: Icon(Icons.group, color: Colors.blue[700]),
                  title: Text(
                    'Xem thành viên${isCreator ? ' (Quản lý)' : ''}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (!isCreator) // Chỉ hiển thị nút rời nhóm cho thành viên không phải người tạo
                const PopupMenuItem(
                  value: 'leave',
                  child: ListTile(
                    leading: Icon(Icons.exit_to_app, color: Colors.red),
                    title: Text(
                      'Rời nhóm',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              if (isCreator) // Chỉ người tạo nhóm mới thấy nút thêm thành viên
                PopupMenuItem(
                  value: 'add',
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: Colors.blue[700]),
                    title: const Text(
                      'Thêm thành viên',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              if (isCreator) // Chỉ hiển thị nút xóa nhóm cho người tạo
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text(
                      'Xóa nhóm',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
            ],
          ),
        ],
      ),
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
                      
                      // Hiển thị tin nhắn hệ thống
                      if (message.senderId == 'system') {
                        return _buildSystemMessage(message);
                      }
                      
                      // Hiển thị tin nhắn thông thường
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
                        onDelete: isMyMessage ? () => _deleteMessage(message.id) : null,
                      );
                    },
                  );
                },
              ),
            ),
            if (canSendMessage) // Chỉ hiển thị input khi có quyền gửi tin nhắn
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
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!canSendMessage) // Hiển thị thông báo khi không có quyền
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: const Text(
                  'Bạn không thể gửi tin nhắn trong nhóm này',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showKickMemberDialog(String memberId) {
    showDialog(
      context: context,
      builder: (context) => KickMemberDialog(
        group: widget.group,
        memberId: memberId,
        onKicked: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa thành viên khỏi nhóm')),
          );
          Navigator.of(context).pop(); // Đóng dialog member list
        },
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn rời khỏi nhóm này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Rời nhóm',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<ChatProvider>().leaveGroup(widget.group.id, true);
        if (mounted) {
          Navigator.of(context).pop(); // Trở về màn hình trước
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể rời nhóm: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteGroupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa nhóm'),
        content: const Text(
          'Bạn có chắc muốn xóa nhóm này? Hành động này không thể hoàn tác và tất cả tin nhắn sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa nhóm',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<ChatProvider>().deleteGroup(widget.group.id);
        if (mounted) {
          Navigator.of(context).pop(); // Trở về màn hình trước
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xóa nhóm: $e')),
          );
        }
      }
    }
  }
} 