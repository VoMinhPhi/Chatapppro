import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    context.read<ChatProvider>().getUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách bạn bè'),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          final currentUser = provider.users.firstWhere(
            (u) => u.id == provider.userId,
            orElse: () => User(
              id: '',
              name: '',
              password: '',
              isOnline: false,
              lastSeen: DateTime.now(),
            ),
          );

          final friends = provider.users.where(
            (user) => currentUser.friendIds.contains(user.id),
          ).toList();

          if (friends.isEmpty) {
            return const Center(
              child: Text('Chưa có bạn bè nào'),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: friend.isOnline ? Colors.green : Colors.grey,
                  child: Text(
                    friend.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(friend.name),
                subtitle: Text(
                  friend.isOnline ? 'Online' : 'Last seen: ${_formatLastSeen(friend.lastSeen)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          receiverId: friend.id,
                          receiverName: friend.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 