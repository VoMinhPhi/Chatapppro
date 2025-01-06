import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';

class MemberListDialog extends StatelessWidget {
  final Group group;
  final Function(String)? onKickMember;

  const MemberListDialog({
    super.key,
    required this.group,
    this.onKickMember,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          final members = provider.users
              .where((u) => group.memberIds.contains(u.id))
              .toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Thành viên nhóm'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isCreator = member.id == group.creatorId;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: member.isOnline ? Colors.green : Colors.grey,
                        child: Text(
                          member.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        member.name + (isCreator ? ' (Người tạo)' : ''),
                        style: TextStyle(
                          fontWeight: isCreator ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        member.isOnline ? 'Online' : 'Offline',
                      ),
                      trailing: !isCreator && onKickMember != null && member.id != provider.userId
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.red,
                              onPressed: () {
                                Navigator.pop(context);
                                onKickMember!(member.id);
                              },
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 