import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_screen.dart';
import '../screens/friends_list_screen.dart';

class NotificationList extends StatelessWidget {
  const NotificationList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        if (provider.notifications.isEmpty && provider.pendingMessages.isEmpty) {
          return const Center(
            child: Text('Không có thông báo mới'),
          );
        }

        return ListView(
          children: [
            ...provider.notifications.map((notification) {
              final fromUser = provider.users.firstWhere(
                (u) => u.id == notification.fromUserId,
                orElse: () => User(
                  id: '',
                  name: 'Unknown',
                  password: '',
                  isOnline: false,
                  lastSeen: DateTime.now(),
                ),
              );

              if (notification.type == 'friend_request') {
                return ListTile(
                  leading: const Icon(Icons.person_add),
                  title: Text('${fromUser.name} muốn kết bạn với bạn'),
                  subtitle: Text(_formatTime(notification.timestamp)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          await provider.acceptFriendRequest(notification.id);
                          await provider.markNotificationAsRead(notification.id);
                          await provider.getUsers();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã chấp nhận lời mời kết bạn từ ${fromUser.name}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FriendsListScreen()),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await provider.rejectFriendRequest(notification.id);
                          await provider.markNotificationAsRead(notification.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã từ chối lời mời kết bạn từ ${fromUser.name}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                );
              } else if (notification.type == 'friend_accepted') {
                return ListTile(
                  leading: const Icon(Icons.person, color: Colors.green),
                  title: Text('${fromUser.name} đã chấp nhận lời mời kết bạn của bạn'),
                  subtitle: Text(_formatTime(notification.timestamp)),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle),
                    onPressed: () {
                      provider.markNotificationAsRead(notification.id);
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            ...provider.pendingMessages.map((message) {
              final fromUser = provider.users.firstWhere(
                (u) => u.id == message.senderId,
                orElse: () => User(
                  id: '',
                  name: 'Unknown',
                  password: '',
                  isOnline: false,
                  lastSeen: DateTime.now(),
                ),
              );

              return ListTile(
                leading: const Icon(Icons.message),
                title: Text('Tin nhắn mới từ ${fromUser.name}'),
                subtitle: Text(message.content),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: message.senderId,
                        receiverName: fromUser.name,
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
} 