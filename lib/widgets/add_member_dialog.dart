import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/chat_provider.dart';

class AddMemberDialog extends StatelessWidget {
  final Group group;

  const AddMemberDialog({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mời thêm thành viên',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  final nonMembers = provider.getFriends().where((user) =>
                    !group.memberIds.contains(user.id)
                  ).toList();

                  if (nonMembers.isEmpty) {
                    return const Center(
                      child: Text('Không có bạn bè nào để mời'),
                    );
                  }

                  return ListView.builder(
                    itemCount: nonMembers.length,
                    itemBuilder: (context, index) {
                      final user = nonMembers[index];
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
                        trailing: ElevatedButton(
                          onPressed: () {
                            provider.addGroupMember(group.id, user.id).then((_) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã mời ${user.name} vào nhóm'),
                                ),
                              );
                            });
                          },
                          child: const Text('Mời'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 