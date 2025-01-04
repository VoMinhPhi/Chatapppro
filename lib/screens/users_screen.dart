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
import 'profile_screen.dart';

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
    provider.getUnreadCounts();
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
            builder: (context, provider, child) => Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 16,
                  child: Text(
                    provider.userName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.userName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Thông báo',
                  onPressed: () => _showNotifications(context),
                ),
                const Positioned(
                  right: 8,
                  top: 8,
                  child: NotificationBadge(),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Menu',
              onSelected: (value) {
                switch (value) {
                  case 'create_group':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                    );
                    break;
                  case 'friends':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FriendsListScreen()),
                    );
                    break;
                  case 'add_friend':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FindFriendsScreen()),
                    );
                    break;
                  case 'profile':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                    break;
                  case 'logout':
                    _handleLogout(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create_group',
                  child: ListTile(
                    leading: Icon(Icons.group_add),
                    title: Text('Tạo nhóm mới'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'friends',
                  child: ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Danh sách bạn bè'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_friend',
                  child: ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Thêm bạn'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.account_circle),
                    title: Text('Hồ sơ'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
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

  Future<void> _handleLogout(BuildContext context) async {
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
            final unreadCount = provider.unreadCounts[friend.id] ?? 0;

            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: friend.isOnline ? Colors.green : Colors.grey,
                    child: Text(
                      friend.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      friend.name,
                      style: TextStyle(
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount tin nhắn mới',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.isOnline ? 'Online' : 'Last seen: ${_formatLastSeen(friend.lastSeen)}',
                  ),
                  if (unreadCount > 0)
                    Text(
                      'Bạn có tin nhắn chưa đọc',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
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