import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../screens/friends_list_screen.dart';

class FindFriendsScreen extends StatefulWidget {
  const FindFriendsScreen({super.key});

  @override
  State<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends State<FindFriendsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadUsers();
      }
    });
  }

  void _loadUsers() {
    print('Loading users...');
    context.read<ChatProvider>().getUsers();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[700],
        title: const Text(
          'Tìm bạn mới',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên...',
                prefixIcon: const Icon(Icons.search),
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: Consumer<ChatProvider>(
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

                final filteredUsers = provider.users.where((user) {
                  if (user.id == provider.userId) return false;
                  
                  if (currentUser.friendIds.contains(user.id)) return false;
                  
                  if (_searchQuery.isNotEmpty) {
                    return user.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                  }
                  return true;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy người dùng mới'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return UserRequestTile(user: user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UserRequestTile extends StatelessWidget {
  final User user;

  const UserRequestTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isOnline ? Colors.green : Colors.grey,
          child: Text(
            user.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          user.isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            color: user.isOnline ? Colors.green : Colors.grey,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            context.read<ChatProvider>().sendFriendRequest(user.id).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã kết bạn với ${user.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
          ),
          child: const Text('Kết bạn'),
        ),
      ),
    );
  }
} 