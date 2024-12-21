import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/message.dart';

class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  final Dio _dio = Dio();
  final String _baseUrl = 'http://10.0.2.2:3000'; // Thay thế bằng API của bạn
  
  List<Message> get messages => _messages;

  Future<void> sendMessage(String content) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/messages',
        data: {
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        _messages.add(Message.fromJson(response.data));
        notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi gửi tin nhắn: $e');
    }
  }

  Future<void> getMessages() async {
    try {
      final response = await _dio.get('$_baseUrl/messages');
      
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
} 