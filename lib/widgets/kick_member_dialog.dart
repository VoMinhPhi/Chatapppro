import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/chat_provider.dart';

class KickMemberDialog extends StatelessWidget {
  final Group group;
  final String memberId;
  final VoidCallback onKicked;

  const KickMemberDialog({
    super.key,
    required this.group,
    required this.memberId,
    required this.onKicked,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác nhận'),
      content: const Text('Bạn có chắc muốn xóa thành viên này khỏi nhóm?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await context.read<ChatProvider>().kickMember(
                group.id,
                memberId,
              );
              if (context.mounted) {
                Navigator.pop(context);
                onKicked();
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không thể xóa thành viên: $e')),
                );
              }
            }
          },
          child: const Text(
            'Xóa',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
} 