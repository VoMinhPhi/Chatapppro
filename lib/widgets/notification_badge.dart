import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final totalNotifications = provider.notifications.length + 
                                 provider.pendingMessages.length;
        
        if (totalNotifications == 0) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Text(
            totalNotifications.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
} 