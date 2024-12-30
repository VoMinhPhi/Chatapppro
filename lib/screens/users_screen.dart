import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../widgets/notification_badge.dart';
import '../widgets/notification_list.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'find_friends_screen.dart';
import 'friends_list_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  void _loadData() {
    final provider = context.read<ChatProvider>();
    provider.getUsers();
    provider.getGroups();
    provider.getNotifications();
    provider.getPendingMessages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    context.read<ChatProvider>().updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      context.read<ChatProvider>().updateOnlineStatus(false);
    } else if (state == AppLifecycleState.resumed) {
      context.read<ChatProvider>().updateOnlineStatus(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<ChatProvider>(
            builder: (context, provider, child) => Text('Xin chào, ${provider.userName}'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsListScreen()),
                );
              },
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => _showNotifications(context),
                ),
                const Positioned(
                  right: 8,
                  top: 8,
                  child: NotificationBadge(),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FindFriendsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                try {
                  await context.read<ChatProvider>().logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Có lỗi xảy ra khi đăng xuất')),
                    );
                  }
                }
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bạn bè'),
              Tab(text: 'Nhóm'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsList(),
            _buildGroupsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return Consumer<ChatProvider>(
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Chưa có bạn bè nào'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FindFriendsScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Tìm bạn mới'),
                ),
              ],
            ),
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
              trailing: const Icon(Icons.chat),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      receiverId: friend.id,
                      receiverName: friend.name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsList() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final groups = provider.groups;

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Chưa có nhóm nào'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                    );
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text('Tạo nhóm mới'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final memberCount = group.memberIds.length;
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  group.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(group.name),
              subtitle: Text('$memberCount thành viên'),
              trailing: const Icon(Icons.chat),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(group: group),
                  ),
                );
              },
            );
          },
        );
      },
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const NotificationList(),
    );
  }
} 