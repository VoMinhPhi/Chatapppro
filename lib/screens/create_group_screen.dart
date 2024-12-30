import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final List<String> _selectedMembers = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo nhóm mới'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên nhóm',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final friends = provider.getFriends();
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return CheckboxListTile(
                      title: Text(friend.name),
                      value: _selectedMembers.contains(friend.id),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedMembers.add(friend.id);
                          } else {
                            _selectedMembers.remove(friend.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _selectedMembers.isNotEmpty) {
                  context.read<ChatProvider>().createGroup(
                    _nameController.text,
                    _selectedMembers,
                  ).then((_) {
                    Navigator.pop(context);
                  });
                }
              },
              child: const Text('Tạo nhóm'),
            ),
          ),
        ],
      ),
    );
  }
} 