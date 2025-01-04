import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';

class MemberListDialog extends StatelessWidget {
  final Group group;

  const MemberListDialog({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thành viên trong nhóm',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final members = provider.users.where((user) =>
                  group.memberIds.contains(user.id)
                ).toList();

                if (members.isEmpty) {
                  return const Center(
                    child: Text('Không có thành viên nào'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final user = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user.isOnline ? Colors.green : Colors.grey,
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                        user.isOnline ? 'Online' : 'Offline',
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 