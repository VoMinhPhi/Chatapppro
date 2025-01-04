import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/notification.dart';
import '../models/group.dart';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  final List<User> _users = [];
  late final Dio _dio;
  final String _baseUrl = 'http://10.0.2.2:3000';
  String userName = '';
  String? userId;
  final List<UserNotification> _notifications = [];
  final List<Message> _pendingMessages = [];
  final List<Group> _groups = [];
  final Map<String, List<Message>> _groupMessages = {};
  String? _currentGroupId;
  WebSocketChannel? _channel;
  final String _wsUrl = 'ws://10.0.2.2:3000';
  final Map<String, int> _unreadCounts = {};
  String? _token;
  
  ChatProvider() {
    _dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (_token != null) {
              options.headers['Authorization'] = 'Bearer $_token';
            }
            return handler.next(options);
          },
        ),
      );
  }
  
  List<Message> get messages => _messages;
  List<User> get users => _users;
  List<UserNotification> get notifications => _notifications;
  List<Message> get pendingMessages => _pendingMessages;
  List<Group> get groups => _groups;
  Map<String, int> get unreadCounts => _unreadCounts;
  String? get token => _token;

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
        // Xóa tin nhắn khỏi danh sách tin nhắn cá nhân
        _messages.removeWhere((message) => message.id == messageId);
        
        // Xóa tin nhắn khỏi danh sách tin nhắn nhóm
        _groupMessages.forEach((groupId, messages) {
          messages.removeWhere((message) => message.id == messageId);
        });
        
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi xóa tin nhắn: $e');
      rethrow;
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
        // Gửi thông báo qua WebSocket
        _channel?.sink.add(jsonEncode({
          'type': 'friend_request',
          'fromUserId': userId,
          'toUserId': targetUserId,
        }));
        
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi kết bạn: $e');
      rethrow;
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
        final data = response.data;
        final user = User.fromJson(data['user']);
        _token = data['token'];
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

  Future<void> markMessageAsRead(String messageId, String senderId) async {
    try {
      await _dio.put('$_baseUrl/messages/$messageId/read');
      
      // Cập nhật local state
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final message = _messages[messageIndex];
        _messages[messageIndex] = Message(
          id: message.id,
          content: message.content,
          timestamp: message.timestamp,
          senderId: message.senderId,
          receiverId: message.receiverId,
          groupId: message.groupId,
          isRead: true,
        );
      }
      
      // Cập nhật số tin nhắn chưa đọc
      if (_unreadCounts.containsKey(senderId)) {
        _unreadCounts[senderId] = (_unreadCounts[senderId] ?? 1) - 1;
        if (_unreadCounts[senderId]! <= 0) {
          _unreadCounts.remove(senderId);
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Lỗi khi đánh dấu tin nhắn đã đọc: $e');
    }
  }

  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    try {
      final response = await _dio.put(
        '$_baseUrl/friend-requests/$requestId/accept',
      );

      if (response.statusCode == 200) {
        // Gửi thông báo qua WebSocket
        _channel?.sink.add(jsonEncode({
          'type': 'friend_accepted',
          'requestId': fromUserId,
          'userId': userId,
        }));

        // Xóa thông báo lời mời kết bạn
        _notifications.removeWhere((n) => n.id == requestId);
        
        await getUsers(); // Cập nhật danh sách bạn bè
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi chấp nhận lời mời kết bạn: $e');
      rethrow;
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
    if (_groupMessages[groupId] == null || _groupMessages[groupId]!.isEmpty) {
      getGroupMessages(groupId);
    }
  }

  void clearCurrentGroup() {
    _currentGroupId = null;
    notifyListeners();
  }

  Future<void> sendGroupMessage(String content, String groupId) async {
    try {
      // Đảm bảo WebSocket được kết nối
      connectWebSocket();

      if (_channel == null) {
        // Thử kết nối lại nếu chưa có kết nối
        await Future.delayed(const Duration(seconds: 1));
        if (_channel == null) {
          throw Exception('Không thể kết nối tới server');
        }
      }

      print('Sending group message: $content to group: $groupId');
      _channel!.sink.add(jsonEncode({
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
    _groupMessages[groupId] ??= [];
    
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
        final List<Message> newMessages = data.map((m) => Message.fromJson(m)).toList();
        
        _groupMessages[groupId] ??= [];
        
        for (final newMsg in newMessages) {
          if (!_groupMessages[groupId]!.any((existingMsg) => existingMsg.id == newMsg.id)) {
            _groupMessages[groupId]!.add(newMsg);
          }
        }
        
        _groupMessages[groupId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        notifyListeners();
      }
    } catch (e) {
      print('Error getting group messages: $e');
    }
  }

  List<Message> getGroupMessagesById(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  void connectWebSocket() {
    try {
      if (_channel != null) return;

      final wsUrl = '$_wsUrl${_token != null ? '?token=$_token' : ''}';
      print('Connecting to WebSocket: $wsUrl');
      _channel = IOWebSocketChannel.connect(wsUrl);
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print('WebSocket error: $error');
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket connection closed');
          _reconnectWebSocket();
        },
      );
      
      if (userId != null) {
        _channel!.sink.add(jsonEncode({
          'type': 'identify',
          'userId': userId,
        }));
      }
      
      print('WebSocket connected successfully');
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _reconnectWebSocket();
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_channel == null) {
        print('Attempting to reconnect WebSocket...');
        connectWebSocket();
      }
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      print('Received WebSocket message: $data');

      switch (data['type']) {
        case 'new_message':
          final newMessage = Message.fromJson(data['message']);
          if (newMessage.groupId != null) {
            _addGroupMessage(newMessage.groupId!, newMessage);
          }
          break;
          
        case 'new_notification':
          // Xử lý thông báo mới
          final notification = UserNotification.fromJson(data['notification']);
          if (!_notifications.any((n) => n.id == notification.id)) {
            _notifications.add(notification);
            notifyListeners();
          }
          break;
          
        case 'friend_request':
          // Xử lý lời mời kết bạn
          final notification = UserNotification.fromJson(data['notification']);
          _notifications.add(notification);
          notifyListeners();
          break;
          
        case 'friend_accepted':
          // Xử lý chấp nhận kết bạn
          final notification = UserNotification.fromJson(data['notification']);
          _notifications.add(notification);
          // Cập nhật danh sách bạn bè
          getUsers();
          notifyListeners();
          break;
          
        case 'message_deleted':
          final messageId = data['messageId'];
          final groupId = data['groupId'];
          
          if (groupId != null) {
            // Xóa tin nhắn nhóm
            if (_groupMessages.containsKey(groupId)) {
              _groupMessages[groupId]!.removeWhere((m) => m.id == messageId);
            }
          } else {
            // Xóa tin nhắn cá nhân
            _messages.removeWhere((m) => m.id == messageId);
          }
          notifyListeners();
          break;
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void joinGroup(String groupId) {
    if (_channel != null) {
      print('Joining group: $groupId');
      _channel!.sink.add(jsonEncode({
        'type': 'join_group',
        'userId': userId,
        'groupId': groupId,
      }));
    }
  }

  void leaveGroup(String groupId) {
    if (_channel != null) {
      print('Leaving group: $groupId');
      _channel!.sink.add(jsonEncode({
        'type': 'leave_group',
        'userId': userId,
        'groupId': groupId,
      }));
    }
  }

  Future<void> logout() async {
    try {
      _channel?.sink.close();
      _channel = null;
      await updateOnlineStatus(false);
      
      // Reset tất cả dữ liệu
      _token = null;
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

  Future<void> updateProfile(String newName) async {
    try {
      final response = await _dio.put(
        '$_baseUrl/users/$userId',
        data: {
          'name': newName,
          'isOnline': true,
          'lastSeen': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        userName = newName;
        // Cập nhật user trong danh sách users
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          final updatedUser = User.fromJson(response.data);
          _users[userIndex] = updatedUser;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> getUnreadCounts() async {
    try {
      final response = await _dio.get('$_baseUrl/messages/unread-count/$userId');
      
      if (response.statusCode == 200) {
        _unreadCounts.clear();
        final Map<String, dynamic> data = response.data;
        data.forEach((key, value) {
          _unreadCounts[key] = value as int;
        });
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi lấy số tin nhắn chưa đọc: $e');
    }
  }

  Future<void> markAllMessagesAsRead(String senderId) async {
    try {
      // Gọi API để đánh dấu tất cả tin nhắn là đã đọc
      await _dio.put('$_baseUrl/messages/read-all/$senderId/$userId');
      
      // Cập nhật local state
      _messages.where((m) => m.senderId == senderId).forEach((m) {
        final index = _messages.indexOf(m);
        _messages[index] = Message(
          id: m.id,
          content: m.content,
          timestamp: m.timestamp,
          senderId: m.senderId,
          receiverId: m.receiverId,
          groupId: m.groupId,
          isRead: true,
        );
      });

      // Xóa số tin nhắn chưa đọc của người gửi này
      _unreadCounts.remove(senderId);
      
      notifyListeners();
    } catch (e) {
      print('Lỗi khi đánh dấu tất cả tin nhắn đã đọc: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _channel = null;
    super.dispose();
  }
} 