const express = require('express');
const app = express();
const port = 3000;
const server = require('http').createServer(app);
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

// Khởi tạo WebSocket server
const wss = new WebSocket.Server({ server: server });

// Lưu trữ kết nối WebSocket theo nhóm
const groupConnections = new Map(); // groupId -> Set of WebSocket connections

wss.on('connection', (ws) => {
  console.log('Client connected');

  ws.on('message', (rawMessage) => {
    try {
      const message = JSON.parse(rawMessage);
      console.log('Received:', message);

      switch (message.type) {
        case 'join_group':
          // Thêm connection vào nhóm
          if (!groupConnections.has(message.groupId)) {
            groupConnections.set(message.groupId, new Set());
          }
          groupConnections.get(message.groupId).add(ws);
          console.log(`User ${message.userId} joined group ${message.groupId}`);
          break;

        case 'leave_group':
          // Xóa connection khỏi nhóm
          if (groupConnections.has(message.groupId)) {
            groupConnections.get(message.groupId).delete(ws);
          }
          console.log(`User ${message.userId} left group ${message.groupId}`);
          break;

        case 'group_message':
          // Lưu tin nhắn
          const newMessage = {
            id: Date.now().toString(),
            content: message.content,
            timestamp: new Date().toISOString(),
            senderId: message.senderId,
            groupId: message.groupId
          };
          messages.push(newMessage);
          saveData();

          // Gửi tin nhắn cho tất cả thành viên trong nhóm
          const connections = groupConnections.get(message.groupId);
          if (connections) {
            const broadcastMessage = JSON.stringify({
              type: 'new_message',
              message: newMessage
            });
            connections.forEach((client) => {
              if (client.readyState === WebSocket.OPEN) {
                client.send(broadcastMessage);
              }
            });
          }
          break;
      }
    } catch (error) {
      console.error('Error processing message:', error);
    }
  });

  ws.on('close', () => {
    // Xóa connection khỏi tất cả nhóm khi disconnect
    groupConnections.forEach((connections) => {
      connections.delete(ws);
    });
    console.log('Client disconnected');
  });
});

// Thay đổi app.listen thành server.listen
server.listen(3000, () => {
  console.log('Server running on port 3000');
});

// Đường dẫn file lưu dữ liệu
const dataFile = path.join(__dirname, 'data.json');

// Khởi tạo dữ liệu mới mỗi khi server khởi động
let users = [];
let messages = [];
let friendRequests = [];
let notifications = [];
let groups = [];

// Hàm lưu dữ liệu
function saveData() {
  // Log trước khi lưu để kiểm tra
  console.log('Saving messages:', messages);
  fs.writeFileSync(
    path.join(__dirname, 'data.json'),
    JSON.stringify({ messages, users, groups, notifications }),
    'utf8'
  );
}

// Hàm để kiểm tra và xóa dữ liệu trùng lặp
function removeDuplicateUsers() {
  const uniqueUsers = new Map();
  
  // Lấy user mới nhất cho mỗi tên
  users.forEach(user => {
    const existingUser = uniqueUsers.get(user.name);
    if (!existingUser || new Date(user.lastSeen) > new Date(existingUser.lastSeen)) {
      uniqueUsers.set(user.name, user);
    }
  });
  
  // Cập nhật lại danh sách users
  users = Array.from(uniqueUsers.values());
  saveData();
}

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  next();
});

app.use(express.json());

// API đăng ký người dùng mới
app.post('/register', (req, res) => {
  const { name, password } = req.body;
  
  // Kiểm tra user đã tồn tại
  const existingUser = users.find(u => u.name === name);
  if (existingUser) {
    return res.status(400).json({ error: 'Tên người dùng đã tồn tại' });
  }
  
  const user = {
    id: Date.now().toString(),
    name: name,
    password: password, // Trong thực tế nên mã hóa password
    isOnline: true,
    lastSeen: new Date().toISOString(),
    friendIds: [],
  };
  users.push(user);
  
  saveData();
  res.json(user);
});

// API đăng nhập
app.post('/login', (req, res) => {
  const { name, password } = req.body;
  
  const user = users.find(u => u.name === name && u.password === password);
  if (!user) {
    return res.status(401).json({ error: 'Tên đăng nhập hoặc mật khẩu không đúng' });
  }
  
  // Cập nhật trạng thái online
  user.isOnline = true;
  user.lastSeen = new Date().toISOString();
  saveData();
  
  res.json(user);
});

// API cập nhật trạng thái người dùng
app.put('/users/:id', (req, res) => {
  const userId = req.params.id;
  const userIndex = users.findIndex(u => u.id === userId);
  
  if (userIndex !== -1) {
    users[userIndex] = {
      ...users[userIndex],
      isOnline: req.body.isOnline,
      lastSeen: req.body.lastSeen,
    };
    saveData();
    res.json(users[userIndex]);
  } else {
    res.status(404).json({ error: 'User not found' });
  }
});

// API lấy danh sách người dùng
app.get('/users', (req, res) => {
  console.log('GET /users - Current users:', users);
  res.json(users);
});

app.get('/messages', (req, res) => {
  console.log('Current messages:', messages);
  res.json(messages);
});

app.get('/messages/:userId1/:userId2', (req, res) => {
  const { userId1, userId2 } = req.params;
  
  // Lấy tin nhắn giữa 2 user
  const conversationMessages = messages.filter(msg => 
    (msg.senderId === userId1 && msg.receiverId === userId2) ||
    (msg.senderId === userId2 && msg.receiverId === userId1)
  );
  
  res.json(conversationMessages);
});

// Middleware kiểm tra token
const validateToken = (req, res, next) => {
  const { senderId, groupId } = req.body;

  // Kiểm tra token người dùng
  if (senderId) {
    const user = users.find(u => u.id === senderId);
    if (!user) {
      return res.status(401).json({ error: 'Invalid user token' });
    }
  }

  // Kiểm tra token nhóm
  if (groupId) {
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(401).json({ error: 'Invalid group token' });
    }
  }

  next();
};

// Áp dụng middleware
app.post('/messages', validateToken, (req, res) => {
  try {
    console.log('Received message:', req.body);
    
    // Validate các token bắt buộc
    const { content, senderId, groupId } = req.body;
    if (!content || !senderId) {
      return res.status(400).json({ error: 'Missing required tokens' });
    }

    // Tạo message với token
    const message = {
      id: Date.now().toString(),
      content,
      timestamp: req.body.timestamp,
      senderId,
      receiverId: req.body.receiverId || null,
      groupId: groupId || null,
    };

    // Kiểm tra token nhóm nếu là tin nhắn nhóm
    if (groupId) {
      const group = groups.find(g => g.id === groupId);
      if (!group) {
        return res.status(404).json({ error: 'Invalid group token' });
      }
      // Kiểm tra token người gửi có trong nhóm không
      if (!group.memberIds.includes(senderId)) {
        return res.status(403).json({ error: 'User token not in group' });
      }
    }

    messages.push(message);
    saveData();
    res.json(message);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/messages/:id', (req, res) => {
  const messageId = req.params.id;
  messages = messages.filter(message => message.id !== messageId);
  res.json({ success: true });
});

// API gửi lời mời kết bạn và tự động chấp nhận
app.post('/friend-requests', (req, res) => {
  const { fromUserId, toUserId } = req.body;
  
  // Thêm vào danh sách bạn bè của cả hai người
  const fromUser = users.find(u => u.id === fromUserId);
  const toUser = users.find(u => u.id === toUserId);
  
  if (fromUser && toUser) {
    // Khởi tạo mảng friendIds nếu chưa có
    if (!fromUser.friendIds) fromUser.friendIds = [];
    if (!toUser.friendIds) toUser.friendIds = [];
    
    // Thêm ID của nhau vào danh sách bạn bè
    if (!fromUser.friendIds.includes(toUser.id)) {
      fromUser.friendIds.push(toUser.id);
    }
    if (!toUser.friendIds.includes(fromUser.id)) {
      toUser.friendIds.push(fromUser.id);
    }
    
    saveData();
    res.json({ 
      success: true,
      fromUser,
      toUser,
    });
  } else {
    res.status(404).json({ error: 'User not found' });
  }
});

// API từ chối lời mời kết bạn
app.put('/friend-requests/:requestId/reject', (req, res) => {
  const requestId = req.params.requestId;
  const request = friendRequests.find(r => r.id === requestId);
  
  if (request) {
    request.status = 'rejected';
    
    // Xóa thông báo liên quan
    notifications = notifications.filter(n => 
      !(n.fromUserId === request.fromUserId && 
        n.toUserId === request.toUserId && 
        n.type === 'friend_request')
    );
    
    saveData();
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Request not found' });
  }
});

// API lấy thông báo của user
app.get('/notifications/:userId', (req, res) => {
  const userId = req.params.userId;
  const userNotifications = notifications.filter(n => 
    n.toUserId === userId && !n.isRead
  );
  res.json(userNotifications);
});

// API đánh dấu đã đọc thông báo
app.put('/notifications/:notificationId/read', (req, res) => {
  const notificationId = req.params.notificationId;
  const notification = notifications.find(n => n.id === notificationId);
  
  if (notification) {
    notification.isRead = true;
    saveData();
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'Notification not found' });
  }
});

// API lấy tin nhắn chờ
app.get('/messages/pending/:userId', (req, res) => {
  const userId = req.params.userId;
  const pendingMessages = messages.filter(msg => 
    msg.receiverId === userId && !msg.isRead
  );
  res.json(pendingMessages);
});

// API chấp nhận lời mời kết bạn
app.put('/friend-requests/:requestId/accept', (req, res) => {
  const requestId = req.params.requestId;
  const request = friendRequests.find(r => r.id === requestId);
  
  if (request) {
    request.status = 'accepted';
    
    // Thêm vào danh sách bạn bè của cả hai người
    const fromUser = users.find(u => u.id === request.fromUserId);
    const toUser = users.find(u => u.id === request.toUserId);
    
    if (fromUser && toUser) {
      // Khởi tạo mảng friendIds nếu chưa có
      if (!fromUser.friendIds) fromUser.friendIds = [];
      if (!toUser.friendIds) toUser.friendIds = [];
      
      // Thêm ID của nhau vào danh sách bạn bè
      if (!fromUser.friendIds.includes(toUser.id)) {
        fromUser.friendIds.push(toUser.id);
      }
      if (!toUser.friendIds.includes(fromUser.id)) {
        toUser.friendIds.push(fromUser.id);
      }
      
      // Xóa thông báo lời mời kết bạn cũ
      notifications = notifications.filter(n => 
        !(n.fromUserId === request.fromUserId && 
          n.toUserId === request.toUserId && 
          n.type === 'friend_request')
      );
      
      // Tạo thông báo cho người gửi lời mời
      const notification = {
        id: `notif_${Date.now()}`,
        type: 'friend_accepted',
        fromUserId: toUser.id,
        toUserId: fromUser.id,
        timestamp: new Date().toISOString(),
        isRead: false,
      };
      notifications.push(notification);
      
      saveData();
      
      // Trả về cả hai user đã được cập nhật
      res.json({ 
        success: true,
        fromUser,
        toUser,
      });
      
      console.log('Friend request accepted:', {
        fromUser: fromUser.name,
        toUser: toUser.name,
        fromUserFriends: fromUser.friendIds,
        toUserFriends: toUser.friendIds
      });
    } else {
      res.status(404).json({ error: 'User not found' });
    }
  } else {
    res.status(404).json({ error: 'Friend request not found' });
  }
});

// API tạo nhóm mới
app.post('/groups', (req, res) => {
  const group = {
    id: Date.now().toString(),
    name: req.body.name,
    creatorId: req.body.creatorId,
    memberIds: req.body.memberIds,
    createdAt: new Date().toISOString(),
  };
  groups.push(group);
  saveData();
  res.json(group);
});

// API lấy danh sách nhóm của user
app.get('/groups/user/:userId', (req, res) => {
  const userId = req.params.userId;
  const userGroups = groups.filter(g => g.memberIds.includes(userId));
  res.json(userGroups);
});

// API thêm thành viên vào nhóm
app.post('/groups/:groupId/members', (req, res) => {
  const groupId = req.params.groupId;
  const memberId = req.body.memberId;
  
  const group = groups.find(g => g.id === groupId);
  if (group) {
    if (!group.memberIds.includes(memberId)) {
      group.memberIds.push(memberId);
      saveData();
    }
    res.json(group);
  } else {
    res.status(404).json({ error: 'Group not found' });
  }
});

// API lấy tin nhắn của nhóm
app.get('/messages/group/:groupId', (req, res) => {
  try {
    const groupId = req.params.groupId;
    
    // Kiểm tra token nhóm
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(404).json({ error: 'Invalid group token' });
    }

    const groupMessages = messages
      .filter(m => m.groupId === groupId)
      .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    res.json(groupMessages);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Chạy removeDuplicateUsers mỗi phút đ tránh trùng lặp
setInterval(removeDuplicateUsers, 60 * 1000);