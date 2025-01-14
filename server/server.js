const express = require('express');
const app = express();
const port = 3000;
const server = require('http').createServer(app);
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const SECRET_KEY = 'your-secret-key'; // Trong thực tế nên lưu trong env

// Middleware xác thực token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token không tồn tại' });
  }

  jwt.verify(token, SECRET_KEY, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Token không hợp lệ' });
    }
    req.user = user;
    next();
  });
};

// Áp dụng middleware cho các API cần xác thực
app.use('/messages', authenticateToken);
app.use('/groups', authenticateToken);
app.use('/friend-requests', authenticateToken);
app.use('/notifications', authenticateToken);

// Khởi tạo WebSocket server
const wss = new WebSocket.Server({ server: server });

// Lưu trữ kết nối WebSocket theo nhóm
const groupConnections = new Map(); // groupId -> Set of WebSocket connections

wss.on('connection', (ws, req) => {
  try {
    // Lấy token từ URL query
    const url = new URL(req.url, 'ws://localhost');
    const token = url.searchParams.get('token');

    if (!token) {
      ws.close(1008, 'Token không tồn tại');
      return;
    }

    // Xác thực token
    jwt.verify(token, SECRET_KEY, (err, decoded) => {
      if (err) {
        ws.close(1008, 'Token không hợp lệ');
        return;
      }
      ws.userId = decoded.id;
    });

    console.log('Client connected');

    // Gửi ping để giữ kết nối
    const pingInterval = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.ping();
      }
    }, 30000);

    ws.on('message', (rawMessage) => {
      try {
        const message = JSON.parse(rawMessage);
        console.log('Received:', message);

        switch (message.type) {
          case 'identify':
            ws.userId = message.userId;
            console.log(`Client identified with userId: ${message.userId}`);
            break;
          
          case 'join_group':
            if (!groupConnections.has(message.groupId)) {
              groupConnections.set(message.groupId, new Set());
            }
            groupConnections.get(message.groupId).add(ws);
            console.log(`User ${message.userId} joined group ${message.groupId}`);
            break;

          case 'leave_group':
            const leaveGroupId = message.groupId;
            const leaveUserId = message.userId;
            if (groupConnections.has(leaveGroupId)) {
              groupConnections.get(leaveGroupId).delete(ws);
            }
            // Broadcast to all members except the one leaving
            wss.clients.forEach(client => {
              if (client.readyState === WebSocket.OPEN && 
                  client.userId !== leaveUserId) {
                client.send(JSON.stringify({
                  type: 'leave_group',
                  groupId: leaveGroupId,
                  userId: leaveUserId
                }));
              }
            });
            break;

          case 'member_kicked':
            const kickGroupId = message.groupId;
            const kickedMemberId = message.memberId;
            wss.clients.forEach(client => {
              if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                  type: 'member_kicked',
                  groupId: kickGroupId,
                  memberId: kickedMemberId
                }));
              }
            });
            break;

          case 'group_message':
            try {
              // Lưu tin nhắn
              const newMessage = {
                id: Date.now().toString(),
                content: message.content,
                timestamp: new Date().toISOString(),
                senderId: message.senderId,
                groupId: message.groupId,
                isRead: false,
              };
              
              // Kiểm tra group tồn tại
              const group = groups.find(g => g.id === message.groupId);
              if (!group) {
                throw new Error('Group not found');
              }

              // Kiểm tra người gửi có trong nhóm không
              if (!group.memberIds.includes(message.senderId)) {
                throw new Error('User not in group');
              }

              messages.push(newMessage);
              saveData();

              // Gửi tin nhắn cho tất cả thành viên trong nhóm
              const connections = groupConnections.get(message.groupId);
              if (connections) {
                const broadcastMessage = JSON.stringify({
                  type: 'new_message',
                  message: newMessage
                });
                connections.forEach(client => {
                  if (client.readyState === WebSocket.OPEN) {
                    client.send(broadcastMessage);
                  }
                });
              }
            } catch (error) {
              console.error('Error handling group message:', error);
            }
            break;

          case 'friend_request':
            const notification = {
              id: `notif_${Date.now()}`,
              type: 'friend_request',
              fromUserId: message.fromUserId,
              toUserId: message.toUserId,
              timestamp: new Date().toISOString(),
              isRead: false,
            };
            notifications.push(notification);
            saveData();
            
            // Gửi thông báo cho người nhận
            const receiverConnection = [...wss.clients].find(client => 
              client.userId === message.toUserId
            );
            if (receiverConnection) {
              receiverConnection.send(JSON.stringify({
                type: 'new_notification',
                notification,
              }));
            }
            break;
            
          case 'friend_accepted':
            // Cập nhật danh sách bạn bè
            const fromUser = users.find(u => u.id === message.requestId);
            const toUser = users.find(u => u.id === message.userId);
            
            if (fromUser && toUser) {
              if (!fromUser.friendIds) fromUser.friendIds = [];
              if (!toUser.friendIds) toUser.friendIds = [];
              
              fromUser.friendIds.push(toUser.id);
              toUser.friendIds.push(fromUser.id);
              
              saveData();
              
              // Gửi thông báo cho người gửi lời mời ban đầu
              const senderConnection = [...wss.clients].find(client => 
                client.userId === message.requestId
              );
              if (senderConnection) {
                senderConnection.send(JSON.stringify({
                  type: 'friend_accepted',
                  fromUser,
                  toUser,
                }));
              }
            }
            break;
        }
      } catch (error) {
        console.error('Error processing message:', error);
      }
    });

    ws.on('close', () => {
      clearInterval(pingInterval);
      groupConnections.forEach(connections => {
        connections.delete(ws);
      });
      console.log('Client disconnected');
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
      ws.close();
    });
  } catch (error) {
    console.error('WebSocket connection error:', error);
    ws.close(1011, 'Internal Server Error');
  }
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
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  next();
});

app.options('*', (req, res) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.sendStatus(200);
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
  
  // Tạo token
  const token = jwt.sign({ id: user.id, name: user.name }, SECRET_KEY);
  
  // Cập nhật trạng thái online
  user.isOnline = true;
  user.lastSeen = new Date().toISOString();
  saveData();
  
  res.json({ user, token });
});

// API cập nhật trạng thái người dùng
app.put('/users/:id', (req, res) => {
  try {
    const userId = req.params.id;
    const userIndex = users.findIndex(u => u.id === userId);
    
    if (userIndex !== -1) {
      // Giữ lại các thông tin cũ
      const oldUser = users[userIndex];
      
      // Cập nhật user với dữ liệu mới
      users[userIndex] = {
        ...oldUser,
        name: req.body.name || oldUser.name,
        isOnline: req.body.isOnline ?? oldUser.isOnline,
        lastSeen: req.body.lastSeen || oldUser.lastSeen,
      };
      
      saveData();
      res.json(users[userIndex]);
    } else {
      res.status(404).json({ error: 'User not found' });
    }
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: 'Internal server error' });
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

// API gửi tin nhắn
app.post('/messages', authenticateToken, (req, res) => {
  try {
    console.log('Received message:', req.body);
    
    // Validate dữ liệu bắt buộc
    const { content, senderId, groupId } = req.body;
    if (!content || !senderId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Tạo message mới
    const message = {
      id: Date.now().toString(),
      content,
      timestamp: req.body.timestamp || new Date().toISOString(),
      senderId,
      receiverId: req.body.receiverId || null,
      groupId: groupId || null,
      isRead: false,
    };

    // Kiểm tra quyền gửi tin nhắn trong nhóm
    if (groupId) {
      const group = groups.find(g => g.id === groupId);
      if (!group) {
        return res.status(404).json({ error: 'Group not found' });
      }
      // Kiểm tra người gửi có trong nhóm không
      if (!group.memberIds.includes(senderId)) {
        return res.status(403).json({ error: 'User not in group' });
      }
    }

    messages.push(message);
    saveData();

    // Gửi tin nhắn qua WebSocket nếu là tin nhắn nhóm
    if (groupId) {
      const connections = groupConnections.get(groupId);
      if (connections) {
        const broadcastMessage = JSON.stringify({
          type: 'new_message',
          message
        });
        connections.forEach(client => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(broadcastMessage);
          }
        });
      }
    }

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
  try {
    const { fromUserId, toUserId } = req.body;
    
    // Tạo thông báo lời mời kết bạn
    const notification = {
      id: `notif_${Date.now()}`,
      type: 'friend_request',
      fromUserId,
      toUserId,
      timestamp: new Date().toISOString(),
      isRead: false,
    };
    
    notifications.push(notification);
    saveData();

    // Gửi thông báo qua WebSocket cho người nhận
    const receiverConnection = [...wss.clients].find(client => 
      client.userId === toUserId
    );
    if (receiverConnection) {
      receiverConnection.send(JSON.stringify({
        type: 'new_notification',
        notification,
      }));
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error sending friend request:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API từ chối lời mời kết bạn
app.put('/friend-requests/:requestId/reject', (req, res) => {
  try {
    const requestId = req.params.requestId;
    const notification = notifications.find(n => n.id === requestId);
    
    if (!notification) {
      return res.status(404).json({ error: 'Friend request not found' });
    }

    // Đánh dấu thông báo đã đọc
    notification.isRead = true;
    saveData();

    res.json({ success: true });
  } catch (error) {
    console.error('Error rejecting friend request:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API chấp nhận lời mời kết bạn
app.put('/friend-requests/:requestId/accept', (req, res) => {
  try {
    const requestId = req.params.requestId;
    const notification = notifications.find(n => n.id === requestId);
    
    if (!notification) {
      return res.status(404).json({ error: 'Friend request not found' });
    }

    // Cập nhật danh sách bạn bè
    const fromUser = users.find(u => u.id === notification.fromUserId);
    const toUser = users.find(u => u.id === notification.toUserId);
    
    if (fromUser && toUser) {
      if (!fromUser.friendIds) fromUser.friendIds = [];
      if (!toUser.friendIds) toUser.friendIds = [];
      
      // Thêm ID của nhau vào danh sách bạn bè
      fromUser.friendIds.push(toUser.id);
      toUser.friendIds.push(fromUser.id);
      
      // Đánh dấu thông báo đã đọc
      notification.isRead = true;
      
      saveData();

      // Gửi thông báo qua WebSocket cho người gửi lời mời
      const senderConnection = [...wss.clients].find(client => 
        client.userId === notification.fromUserId
      );
      if (senderConnection) {
        senderConnection.send(JSON.stringify({
          type: 'friend_accepted',
          fromUser,
          toUser,
        }));
      }

      res.json({ success: true, fromUser, toUser });
    } else {
      res.status(404).json({ error: 'Users not found' });
    }
  } catch (error) {
    console.error('Error accepting friend request:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API lấy thông báo của user
app.get('/notifications/:userId', (req, res) => {
  try {
    const userId = req.params.userId;
    const userNotifications = notifications.filter(n => 
      n.toUserId === userId && !n.isRead
    );
    res.json(userNotifications);
  } catch (error) {
    console.error('Error getting notifications:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API đánh dấu thông báo đã đọc
app.put('/notifications/:notificationId/read', (req, res) => {
  try {
    const notificationId = req.params.notificationId;
    const notification = notifications.find(n => n.id === notificationId);
    
    if (notification) {
      notification.isRead = true;
      saveData();
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Notification not found' });
    }
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API lấy tin nhắn chờ
app.get('/messages/pending/:userId', (req, res) => {
  try {
    const userId = req.params.userId;
    const pendingMessages = messages.filter(msg => 
      msg.receiverId === userId && !msg.isRead && !msg.groupId // Chỉ lấy tin nhắn cá nhân chưa đọc
    );
    res.json(pendingMessages);
  } catch (error) {
    console.error('Error getting pending messages:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API đánh dấu tin nhắn đã đọc
app.put('/messages/:messageId/read', (req, res) => {
  try {
    const messageId = req.params.messageId;
    const message = messages.find(m => m.id === messageId);
    
    if (message) {
      message.isRead = true;
      saveData();
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Message not found' });
    }
  } catch (error) {
    console.error('Error marking message as read:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API đánh dấu tất cả tin nhắn từ một người gửi là đã đọc
app.put('/messages/read-all/:senderId/:receiverId', (req, res) => {
  try {
    const { senderId, receiverId } = req.params;
    let updated = false;

    messages.forEach(message => {
      if (message.senderId === senderId && message.receiverId === receiverId && !message.isRead) {
        message.isRead = true;
        updated = true;
      }
    });

    if (updated) {
      saveData();
    }
    res.json({ success: true });
  } catch (error) {
    console.error('Error marking all messages as read:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API lấy số tin nhắn chưa đọc
app.get('/messages/unread-count/:userId', (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Đổi từ Array sang Object/Map
    const unreadCounts = {};
    messages.forEach(message => {
      if (message.receiverId === userId && !message.isRead && !message.groupId) {
        if (!unreadCounts[message.senderId]) {
          unreadCounts[message.senderId] = 0;
        }
        unreadCounts[message.senderId]++;
      }
    });
    
    res.json(unreadCounts); // Trả về object thay vì array
  } catch (error) {
    console.error('Error getting unread counts:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API tạo nhóm mới
app.post('/groups', (req, res) => {
  try {
    const group = {
      id: Date.now().toString(),
      name: req.body.name,
      creatorId: req.body.creatorId,
      memberIds: req.body.memberIds,
      createdAt: new Date().toISOString(),
    };
    
    groups.push(group);
    saveData();

    // Gửi thông báo cho tất cả thành viên qua WebSocket
    group.memberIds.forEach(memberId => {
      const memberConnection = [...wss.clients].find(client => 
        client.userId === memberId
      );
      if (memberConnection) {
        memberConnection.send(JSON.stringify({
          type: 'new_group',
          group,
        }));
      }
    });

    res.json(group);
  } catch (error) {
    console.error('Error creating group:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API lấy danh sách nhóm của user
app.get('/groups/user/:userId', (req, res) => {
  try {
    const userId = req.params.userId;
    const userGroups = groups.filter(g => g.memberIds.includes(userId));
    res.json(userGroups);
  } catch (error) {
    console.error('Error getting user groups:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API thêm thành viên vào nhóm
app.post('/groups/:groupId/members', authenticateToken, (req, res) => {
  try {
    console.log('Adding member to group:', req.body);
    const groupId = req.params.groupId;
    const memberId = req.body.memberId;
    
    // Tìm thông tin người được thêm
    const newMember = users.find(u => u.id === memberId);
    if (!newMember) {
      return res.status(404).json({ error: 'Không tìm thấy người dùng' });
    }
    
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(404).json({ error: 'Không tìm thấy nhóm' });
    }

    // Kiểm tra quyền
    if (group.creatorId !== req.user.id) {
      return res.status(403).json({ error: 'Chỉ người tạo nhóm mới có quyền thêm thành viên' });
    }

    if (!group.memberIds.includes(memberId)) {
      // Thêm thành viên mới
      group.memberIds.push(memberId);
      
      // Thêm tin nhắn hệ thống
      const systemMessage = {
        id: Date.now().toString(),
        content: `${newMember.name} đã được thêm vào nhóm`,
        timestamp: new Date().toISOString(),
        senderId: 'system',
        groupId: groupId,
        isRead: false,
      };
      messages.push(systemMessage);
      
      // Lấy tất cả tin nhắn của nhóm
      const groupMessages = messages.filter(m => m.groupId === groupId);
      
      saveData();

      // Gửi thông báo WebSocket cho tất cả thành viên và người mới
      wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN && 
            (group.memberIds.includes(client.userId) || client.userId === memberId)) {
          client.send(JSON.stringify({
            type: 'member_added',
            group: group,
            message: systemMessage,
            messages: groupMessages,
            newMember: {
              id: newMember.id,
              name: newMember.name
            }
          }));
        }
      });

      // Trả về đầy đủ thông tin
      res.json({
        success: true,
        group: group,
        messages: groupMessages,
        newMember: {
          id: newMember.id,
          name: newMember.name
        }
      });
    } else {
      res.json({
        success: true,
        group: group,
        messages: messages.filter(m => m.groupId === groupId)
      });
    }
  } catch (error) {
    console.error('Error adding member:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API lấy tin nhắn của nhóm
app.get('/messages/group/:groupId', (req, res) => {
  try {
    const groupId = req.params.groupId;
    
    // Kiểm tra nhóm tồn tại
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Lấy và sắp xếp tin nhắn theo thời gian
    const groupMessages = messages
      .filter(m => m.groupId === groupId)
      .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

    res.json(groupMessages);
  } catch (error) {
    console.error('Error getting group messages:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API xóa thành viên khỏi nhóm
app.delete('/groups/:groupId/members/:memberId', (req, res) => {
  try {
    const { groupId, memberId } = req.params;
    
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(404).json({ error: 'Group not found' });
    }

    group.memberIds = group.memberIds.filter(id => id !== memberId);
    saveData();

    res.json(group);
  } catch (error) {
    console.error('Error removing group member:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API xóa tin nhắn
app.delete('/messages/:messageId', authenticateToken, (req, res) => {
  try {
    const messageId = req.params.messageId;
    const messageIndex = messages.findIndex(m => m.id === messageId);
    
    if (messageIndex === -1) {
      return res.status(404).json({ error: 'Message not found' });
    }

    const message = messages[messageIndex];
    
    // Kiểm tra quyền xóa tin nhắn
    if (message.senderId !== req.user.id) {
      return res.status(403).json({ error: 'Không có quyền xóa tin nhắn này' });
    }

    // Xóa tin nhắn
    messages.splice(messageIndex, 1);
    saveData();

    // Gửi thông báo xóa tin nhắn qua WebSocket
    if (message.groupId) {
      // Thông báo cho tất cả thành viên trong nhóm
      const group = groups.find(g => g.id === message.groupId);
      if (group) {
        wss.clients.forEach(client => {
          if (client.readyState === WebSocket.OPEN && 
              group.memberIds.includes(client.userId)) {
            client.send(JSON.stringify({
              type: 'message_deleted',
              messageId,
              groupId: message.groupId
            }));
          }
        });
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting message:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API rời nhóm
app.post('/leave-group', authenticateToken, (req, res) => {
  try {
    const { groupId } = req.body;
    const userId = req.user.id;
    
    // Tìm nhóm
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(404).json({ error: 'Không tìm thấy nhóm' });
    }

    // Kiểm tra xem người dùng có trong nhóm không
    if (!group.memberIds.includes(userId)) {
      return res.status(400).json({ error: 'Người dùng không trong nhóm' });
    }

    // Không cho phép người tạo nhóm rời nhóm
    if (group.creatorId === userId) {
      return res.status(400).json({ error: 'Người tạo nhóm không thể rời nhóm' });
    }

    // Xóa userId khỏi danh sách thành viên
    group.memberIds = group.memberIds.filter(id => id !== userId);
    
    // Thêm tin nhắn hệ thống
    const systemMessage = {
      id: Date.now().toString(),
      content: `${userId} đã rời khỏi nhóm`,
      timestamp: new Date().toISOString(),
      senderId: 'system',
      groupId: groupId,
      isRead: false,
    };
    messages.push(systemMessage);
    
    // Lưu thay đổi
    saveData();

    // Gửi thông báo WebSocket cho các thành viên còn lại
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN && 
          (group.memberIds.includes(client.userId) || client.userId === userId)) {
        client.send(JSON.stringify({
          type: 'leave_group',
          groupId,
          userId,
          group
        }));
      }
    });

    res.json({ success: true, group });
  } catch (error) {
    console.error('Error leaving group:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Chạy removeDuplicateUsers mỗi phút đ tránh trùng lặp
setInterval(removeDuplicateUsers, 60 * 1000);

// Thêm API endpoint để kick thành viên
app.post('/kick-member', authenticateToken, (req, res) => {
  try {
    console.log('Received kick member request:', req.body);
    console.log('User from token:', req.user);

    const { groupId, memberId } = req.body;
    const requesterId = req.user.id;
    
    // Tìm nhóm
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      console.log('Group not found:', groupId);
      return res.status(404).json({ error: 'Không tìm thấy nhóm' });
    }

    console.log('Found group:', group);
    console.log('Requester ID:', requesterId);
    console.log('Creator ID:', group.creatorId);

    // Kiểm tra quyền
    if (group.creatorId !== requesterId) {
      console.log('Permission denied: User is not group creator');
      return res.status(403).json({ error: 'Chỉ người tạo nhóm mới có quyền kick thành viên' });
    }

    // Kiểm tra thành viên
    if (!group.memberIds.includes(memberId)) {
      console.log('Member not in group:', memberId);
      return res.status(400).json({ error: 'Thành viên không có trong nhóm' });
    }

    if (memberId === group.creatorId) {
      console.log('Cannot kick creator');
      return res.status(400).json({ error: 'Không thể kick người tạo nhóm' });
    }

    // Xóa thành viên
    group.memberIds = group.memberIds.filter(id => id !== memberId);
    console.log('Updated group members:', group.memberIds);
    
    // Lưu thay đổi
    saveData();

    // Gửi thông báo WebSocket
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN && 
          (group.memberIds.includes(client.userId) || client.userId === memberId)) {
        client.send(JSON.stringify({
          type: 'member_kicked',
          groupId,
          memberId,
          group
        }));
      }
    });

    console.log('Successfully kicked member');
    res.json({ success: true, group });
  } catch (error) {
    console.error('Error kicking member:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API xóa nhóm
app.delete('/groups/:groupId', authenticateToken, (req, res) => {
  try {
    const groupId = req.params.groupId;
    const userId = req.user.id;
    
    console.log('Delete group request:', {
      groupId,
      userId,
      token: req.headers.authorization
    });

    // Tìm nhóm
    const group = groups.find(g => g.id === groupId);
    if (!group) {
      return res.status(404).json({ error: 'Không tìm thấy nhóm' });
    }

    // Kiểm tra quyền xóa nhóm
    if (group.creatorId !== userId) {
      return res.status(403).json({ error: 'Chỉ người tạo nhóm mới có quyền xóa nhóm' });
    }

    // Xóa tất cả tin nhắn của nhóm
    messages = messages.filter(m => m.groupId !== groupId);

    // Xóa nhóm
    groups = groups.filter(g => g.id !== groupId);
    
    // Lưu thay đổi
    saveData();

    // Gửi thông báo WebSocket cho tất cả thành viên
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN && 
          group.memberIds.includes(client.userId)) {
        client.send(JSON.stringify({
          type: 'group_deleted',
          groupId,
          deletedBy: userId
        }));
      }
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting group:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});