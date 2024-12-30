import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/notification.dart';
import '../models/group.dart';
import 'dart:convert';
import 'dart:io';

class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  final List<User> _users = [];
  final Dio _dio = Dio();
  final String _baseUrl = 'http://10.0.2.2:3000';
  String userName = '';
  String? userId;
  final List<UserNotification> _notifications = [];
  final List<Message> _pendingMessages = [];
  final List<Group> _groups = [];
  final Map<String, List<Message>> _groupMessages = {};
  String? _currentGroupId;
  WebSocket? _socket;
  final String _wsUrl = 'ws://10.0.2.2:3000';
  
  List<Message> get messages => _messages;
  List<User> get users => _users;
  List<UserNotification> get notifications => _notifications;
  List<Message> get pendingMessages => _pendingMessages;
  List<Group> get groups => _groups;

  Future<void> getUsers() async {
    try {
      print('Fetching users...');
      final response = await _dio.get('$_baseUrl/users');
      
      if (response.statusCode == 200) {
        print('Received users: ${response.data}');
        _users.clear();
        _users.addAll(
          (response.data as List).map((u) => User.fromJson(u)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi lấy danh sách người dùng: $e');
    }
  }

  Future<void> setUserName(String name) async {
    try {
      print('Setting username: $name');
      final response = await _dio.post(
        '$_baseUrl/users',
        data: {
          'name': name.trim(),
          'isOnline': true,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        userName = user.name;
        userId = user.id;
        print('User registered - Name: $userName, ID: $userId');
        notifyListeners();
        
        await getUsers();
      }
    } catch (e) {
      print('Lỗi khi đăng ký người dùng: $e');
    }
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (userId == null) return;
    
    try {
      await _dio.put(
        '$_baseUrl/users/$userId',
        data: {
          'isOnline': isOnline,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Lỗi khi cập nhật trạng thái: $e');
    }
  }

  Future<void> sendMessage(String content, String receiverId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/messages',
        data: {
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
          'senderId': userId,
          'receiverId': receiverId,
        },
      );

      if (response.statusCode == 200) {
        final message = Message.fromJson(response.data);
        _messages.add(message);
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi gửi tin nhắn: $e');
    }
  }

  Future<void> getMessages(String otherUserId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/messages/$userId/$otherUserId',
      );
      
      if (response.statusCode == 200) {
        _messages.clear();
        _messages.addAll(
          (response.data as List).map((m) => Message.fromJson(m)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi lấy tin nhắn: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final response = await _dio.delete('$_baseUrl/messages/$messageId');
      
      if (response.statusCode == 200) {
        _messages.removeWhere((message) => message.id == messageId);
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi xóa tin nhắn: $e');
    }
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/friend-requests',
        data: {
          'fromUserId': userId,
          'toUserId': targetUserId,
        },
      );

      if (response.statusCode == 200) {
        // Cập nhật danh sách users từ response
        final fromUser = User.fromJson(response.data['fromUser']);
        final toUser = User.fromJson(response.data['toUser']);
        
        // Cập nhật danh sách users
        _users.removeWhere((u) => u.id == fromUser.id || u.id == toUser.id);
        _users.addAll([fromUser, toUser]);
        
        // Thông báo UI cập nhật
        notifyListeners();
        
        print('Đã kết bạn thành công');
      }
    } catch (e) {
      print('Lỗi khi kết bạn: $e');
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    try {
      final response = await _dio.put('$_baseUrl/friend-requests/$requestId/reject');
      
      if (response.statusCode == 200) {
        await getUsers();
        notifyListeners();
        print('Đã từ chối lời mời kết bạn');
      }
    } catch (e) {
      print('Lỗi khi từ chối lời mời kết bạn: $e');
    }
  }

  Future<void> register(String name, String password) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/register',
        data: {
          'name': name.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Đăng ký thành công
        print('Registered successfully');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        throw 'Tên người dùng đã tồn tại';
      }
      throw 'Lỗi khi đăng ký: $e';
    }
  }

  Future<void> login(String name, String password) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/login',
        data: {
          'name': name.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        userName = user.name;
        userId = user.id;
        notifyListeners();
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        throw 'Tên đăng nhập hoặc mật khẩu không đúng';
      }
      throw 'Lỗi khi đăng nhập: $e';
    }
  }

  Future<void> getNotifications() async {
    try {
      final response = await _dio.get('$_baseUrl/notifications/$userId');
      
      if (response.statusCode == 200) {
        _notifications.clear();
        _notifications.addAll(
          (response.data as List).map((n) => UserNotification.fromJson(n)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi lấy thông báo: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _dio.put('$_baseUrl/notifications/$notificationId/read');
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      print('Lỗi khi đánh dấu đã đọc thông báo: $e');
    }
  }

  Future<void> getPendingMessages() async {
    try {
      final response = await _dio.get('$_baseUrl/messages/pending/$userId');
      
      if (response.statusCode == 200) {
        _pendingMessages.clear();
        _pendingMessages.addAll(
          (response.data as List).map((m) => Message.fromJson(m)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi lấy tin nhắn chờ: $e');
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final response = await _dio.put(
        '$_baseUrl/friend-requests/$requestId/accept',
      );

      if (response.statusCode == 200) {
        // Cập nhật danh sách users từ response
        final fromUser = User.fromJson(response.data['fromUser']);
        final toUser = User.fromJson(response.data['toUser']);
        
        // Cập nhật danh sách users
        _users.removeWhere((u) => u.id == fromUser.id || u.id == toUser.id);
        _users.addAll([fromUser, toUser]);
        
        // Cập nhật lại toàn bộ danh sách users
        await getUsers();
        
        // Thông báo UI cập nhật
        notifyListeners();
        
        print('Đã chấp nhận lời mời kết bạn thành công');
      }
    } catch (e) {
      print('Lỗi khi chấp nhận lời mời kết bạn: $e');
    }
  }

  List<User> getFriends() {
    final currentUser = _users.firstWhere(
      (u) => u.id == userId,
      orElse: () => User(
        id: '',
        name: '',
        password: '',
        isOnline: false,
        lastSeen: DateTime.now(),
      ),
    );

    return _users.where(
      (user) => currentUser.friendIds.contains(user.id),
    ).toList();
  }

  Future<void> createGroup(String name, List<String> memberIds) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/groups',
        data: {
          'name': name,
          'creatorId': userId,
          'memberIds': [...memberIds, userId], // Thêm cả người tạo vào nhóm
        },
      );

      if (response.statusCode == 200) {
        final group = Group.fromJson(response.data);
        _groups.add(group);
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi tạo nhóm: $e');
    }
  }

  Future<void> getGroups() async {
    try {
      final response = await _dio.get('$_baseUrl/groups/user/$userId');
      
      if (response.statusCode == 200) {
        _groups.clear();
        _groups.addAll(
          (response.data as List).map((g) => Group.fromJson(g)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi lấy danh sách nhóm: $e');
    }
  }

  Future<void> addGroupMember(String groupId, String memberId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/groups/$groupId/members',
        data: {
          'memberId': memberId,
        },
      );

      if (response.statusCode == 200) {
        final updatedGroup = Group.fromJson(response.data);
        final index = _groups.indexWhere((g) => g.id == groupId);
        if (index != -1) {
          _groups[index] = updatedGroup;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Lỗi khi thêm thành viên: $e');
    }
  }

  void setCurrentGroup(String groupId) {
    _currentGroupId = groupId;
    getGroupMessages(groupId); // Load tin nhắn khi chuyển nhóm
  }

  void clearCurrentGroup() {
    _currentGroupId = null;
  }

  Future<void> sendGroupMessage(String content, String groupId) async {
    try {
      _socket?.add(jsonEncode({
        'type': 'group_message',
        'content': content,
        'senderId': userId,
        'groupId': groupId,
      }));
    } catch (e) {
      print('Error sending group message: $e');
      rethrow;
    }
  }

  void _addGroupMessage(String groupId, Message message) {
    if (!_groupMessages.containsKey(groupId)) {
      _groupMessages[groupId] = [];
    }
    
    if (!_groupMessages[groupId]!.any((m) => m.id == message.id)) {
      _groupMessages[groupId]!.add(message);
      _groupMessages[groupId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }
  }

  Future<void> getGroupMessages(String groupId) async {
    try {
      final response = await _dio.get('$_baseUrl/messages/group/$groupId');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final List<Message> messages = data.map((m) => Message.fromJson(m)).toList();
        
        _groupMessages[groupId] = messages;
        notifyListeners();
      }
    } catch (e) {
      print('Error getting group messages: $e');
    }
  }

  List<Message> getGroupMessagesById(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  void connectWebSocket() async {
    try {
      _socket = await WebSocket.connect(_wsUrl);
      _socket!.listen(
        _handleWebSocketMessage,
        onError: (error) => print('WebSocket error: $error'),
        onDone: () {
          print('WebSocket connection closed');
          _socket = null;
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      if (data['type'] == 'new_message') {
        final newMessage = Message.fromJson(data['message']);
        _addGroupMessage(newMessage.groupId!, newMessage);
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void joinGroup(String groupId) {
    _socket?.add(jsonEncode({
      'type': 'join_group',
      'userId': userId,
      'groupId': groupId,
    }));
  }

  void leaveGroup(String groupId) {
    _socket?.add(jsonEncode({
      'type': 'leave_group',
      'userId': userId,
      'groupId': groupId,
    }));
  }

  Future<void> logout() async {
    try {
      // Đóng WebSocket connection
      _socket?.close();
      _socket = null;

      // Cập nhật trạng thái offline
      await updateOnlineStatus(false);
      
      // Reset tất cả dữ liệu
      _messages.clear();
      _groupMessages.clear();
      _users.clear();
      _groups.clear();
      _notifications.clear();
      _pendingMessages.clear();
      _currentGroupId = null;
      userName = '';
      userId = null;

      notifyListeners();
    } catch (e) {
      print('Error logging out: $e');
      rethrow;
    }
  }
} 