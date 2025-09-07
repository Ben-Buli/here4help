// Generate a trace ID for logging
function generateTraceId(socket) {
  if (socket && socket.id) {
    return `socket:${socket.id}`;
  }
  return `trace:${Math.random().toString(36).substring(2, 10)}`;
}
/*
  Enhanced Socket.IO Gateway for Here4Help Chat
  - Auth via base64 token (consistent with PHP profile.php)
  - Events: join_room, leave_room, send_message, typing, read_room
  - Pushes: unread_total, unread_room, message
  - Database integration for room members and unread counts
*/

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');

// 引入客服事件處理器
const SupportEventHandler = require('./support_events');

const PORT = process.env.PORT || 3001;

// Load environment variables once at startup (try root .env, then backend/config/.env)
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
if (!process.env.JWT_SECRET) {
  dotenv.config({ path: path.resolve(__dirname, '../config/.env') });
}

// Get JWT secret once
const JWT_SECRET = process.env.JWT_SECRET || 'here4help_jwt_secret_key_2025_development_environment_secure_random_string';

if (!JWT_SECRET) {
  console.error('❌ JWT_SECRET not configured in environment variables');
  process.exit(1);
}

console.log('✅ JWT_SECRET loaded successfully');
console.log('🔑 JWT_SECRET length:', JWT_SECRET.length);
try {
  const hash = crypto.createHash('sha256').update(JWT_SECRET).digest('hex');
  console.log('🔐 JWT_SECRET SHA256:', hash);
} catch (err) {
  console.log('⚠️ Unable to hash JWT_SECRET');
}

const app = express();
app.use(cors());
app.use(express.json()); // 添加 JSON 解析中間件

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Database connection pool
let dbPool = null;

async function initDatabase() {
  try {
    // Load environment variables
    require('dotenv').config({ path: '../../.env' });
    
    dbPool = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 8889,
      user: process.env.DB_USERNAME || 'root',
      password: process.env.DB_PASSWORD || 'root',
      database: process.env.DB_NAME || 'hero4helpdemofhs_hero4help',
      charset: process.env.DB_CHARSET || 'utf8mb4',
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
    
    // Test connection
    await dbPool.query('SELECT 1');
    console.log('Database connected successfully');
  } catch (error) {
    console.error('Database connection failed:', error.message);
    // Fallback to in-memory mode
    console.log('Falling back to in-memory mode');
  }
}

// 驗證 JWT Token
function validateJWT(token, traceId) {
  // console.log("JWT_SECRET: ", JWT_SECRET);
  // console.log("token: ", token);
  // console.log("traceId: ", traceId);
  try {
    // 使用與 PHP 相同的 JWT 驗證邏輯
    const payload = jwt.verify(token, JWT_SECRET, {
      algorithms: ['HS256'], // 明確指定算法
      ignoreExpiration: false,
      ignoreNotBefore: false
    });
    
    if (!payload.user_id) {
      console.error(`[${traceId}] ❌ JWT payload missing user_id`);
      return null;
    }
    
    // 檢查必要欄位
    if (!payload.iat || !payload.exp) {
      console.error(`[${traceId}] ❌ JWT payload missing required fields (iat/exp)`);
      return null;
    }
    
    return payload;
  } catch (e) {
    console.error(`[${traceId}] ❌ JWT validation failed:`, e.name, e.message);
    return null;
  }
}

function validateTokenBase64(token, traceId) {
  try {
    const decoded = Buffer.from(token, 'base64').toString('utf8');
    const payload = JSON.parse(decoded);
    if (!payload.user_id) {
      console.error(`[${traceId}] ❌ Base64 payload missing user_id`);
      return null;
    }
    if (!payload.exp) {
      console.error(`[${traceId}] ❌ Base64 payload missing exp`);
      return null;
    }
    if (payload.exp < Date.now() / 1000) {
      console.error(`[${traceId}] ❌ Base64 token expired`);
      return null;
    }
    return payload;
  } catch (e) {
    console.error(`[${traceId}] ❌ Base64 validation failed:`, e.message);
    return null;
  }
}

// 統一的 token 驗證函數
function validateToken(token, socket) {
  const traceId = generateTraceId(socket);

  // 調試：顯示 token 格式資訊
  if (process.env.NODE_ENV === 'development') {
    console.log(`[${traceId}] 🔍 Token format analysis:`);
    console.log(`[${traceId}] - Length: ${token ? token.length : 0}`);
    console.log(`[${traceId}] - Parts: ${token ? token.split('.').length : 0}`);
    console.log(`[${traceId}] - First 50 chars: ${token ? token.slice(0, 50) + '...' : 'null'}`);
  }

  let payload = validateJWT(token, traceId);
  if (payload) {
    console.log(`[${traceId}] ✅ JWT token validated successfully`);
    return payload;
  }

  payload = validateTokenBase64(token, traceId);
  if (payload) {
    console.log(`[${traceId}] ✅ Base64 token validated successfully (legacy)`);
    return payload;
  }

  if (process.env.NODE_ENV === 'development') {
    console.error(`[${traceId}] ❌ Token validation failed (neither valid JWT nor Base64). Token snippet:`, token ? token.slice(0, 30) + '...' : 'null');
  } else {
    console.error(`[${traceId}] ❌ Token validation failed (JWT & Base64).`);
  }
  return null;
}

function getUserRoom(userId) {
  return `user:${userId}`;
}

function getChatRoom(roomId) {
  return `room:${roomId}`;
}

// Get room members from database
async function getRoomMembers(roomId) {
  if (!dbPool) return [];
  
  try {
    const [rows] = await dbPool.query(
      'SELECT creator_id, participant_id FROM chat_rooms WHERE id = ?',
      [roomId]
    );
    
    if (rows.length === 0) return [];
    
    const room = rows[0];
    return [room.creator_id.toString(), room.participant_id.toString()];
  } catch (error) {
    console.error('Error getting room members:', error);
    return [];
  }
}

// Get unread count from database
async function getUnreadCount(userId, roomId) {
  if (!dbPool) return 0;
  
  try {
    const [rows] = await dbPool.query(`
      SELECT COUNT(*) as count
      FROM chat_messages cm
      LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
      WHERE cm.room_id = ? AND cm.id > COALESCE(cr.last_read_message_id, 0)
    `, [userId, roomId]);
    
    return rows[0].count;
  } catch (error) {
    console.error('Error getting unread count:', error);
    return 0;
  }
}

// Get total unread count for user
async function getTotalUnreadCount(userId) {
  if (!dbPool) return 0;
  
  try {
    const [rows] = await dbPool.query(`
      SELECT COUNT(*) as count
      FROM chat_messages cm
      LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
      WHERE cm.id > COALESCE(cr.last_read_message_id, 0)
    `, [userId]);
    
    return rows[0].count;
  } catch (error) {
    console.error('Error getting total unread count:', error);
    return 0;
  }
}

// Emit unread counts to user
async function emitUnread(userId) {
  try {
    const total = await getTotalUnreadCount(userId);
    
    // Get unread counts by room
    const [rows] = await dbPool.query(`
      SELECT 
        cm.room_id,
        COUNT(*) as count
      FROM chat_messages cm
      LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
      WHERE cm.id > COALESCE(cr.last_read_message_id, 0)
      GROUP BY cm.room_id
    `, [userId]);
    
    const byRoom = {};
    rows.forEach(row => {
      byRoom[row.room_id] = row.count;
    });
    
    io.to(getUserRoom(userId)).emit('unread_total', { total });
    io.to(getUserRoom(userId)).emit('unread_by_room', { by_room: byRoom });
  } catch (error) {
    console.error('Error emitting unread counts:', error);
  }
}

// Initialize database connection
initDatabase();

// 初始化客服事件處理器
let supportEventHandler = null;

// 創建客服事件處理器
function initSupportEventHandler() {
  supportEventHandler = new SupportEventHandler(io);
  console.log('✅ Support Event Handler initialized');
}

// 在 IO 初始化後創建客服事件處理器
initSupportEventHandler();

io.use((socket, next) => {
  const { token } = socket.handshake.query || {};
  if (!token) return next(new Error('Unauthorized: token missing'));
  const payload = validateToken(String(token), socket);
  if (!payload) return next(new Error('Unauthorized: invalid token'));
  socket.user = { id: String(payload.user_id) };
  return next();
});

io.on('connection', (socket) => {
  const userId = socket.user.id;
  socket.join(getUserRoom(userId));

  console.log(`User ${userId} connected`);

  // Initial push for safety (client can also fetch snapshot via REST)
  emitUnread(userId);

  // 處理客服事件相關連線
  if (supportEventHandler) {
    supportEventHandler.handleConnection(socket);
  }

  socket.on('join_room', ({ roomId }) => {
    if (!roomId) return;
    socket.join(getChatRoom(roomId));
    console.log(`User ${userId} joined room ${roomId}`);
  });

  socket.on('leave_room', ({ roomId }) => {
    if (!roomId) return;
    socket.leave(getChatRoom(roomId));
    console.log(`User ${userId} left room ${roomId}`);
  });

  socket.on('send_message', async ({ roomId, messageId, text, toUserIds = [] }) => {
    if (!roomId || !text) return;

    console.log(`User ${userId} sending message to room ${roomId}`);

    // Get room members from database
    let recipients = Array.isArray(toUserIds) ? toUserIds.map(String) : [];
    if (recipients.length === 0) {
      recipients = await getRoomMembers(roomId);
    }

    // Broadcast message to the room (excluding sender)
    socket.to(getChatRoom(roomId)).emit('message', {
      roomId,
      messageId: messageId || `${Date.now()}`,
      text,
      fromUserId: userId,
      sentAt: Date.now()
    });

    // Increment unread counters for recipients (excluding sender)
    for (const uid of recipients) {
      if (uid && uid !== userId) {
        // Update unread count in database
        if (dbPool) {
          try {
            // Get current unread count
            const currentCount = await getUnreadCount(uid, roomId);
            
            // Emit updated count to user
            io.to(getUserRoom(uid)).emit('unread_by_room', {
              by_room: { [roomId]: currentCount + 1 }
            });
          } catch (error) {
            console.error('Error updating unread count:', error);
          }
        }
      }
    }

    // Mark sender as read up-to latest
    if (dbPool) {
      try {
        // Get latest message ID for this room
        const [rows] = await dbPool.query(
          'SELECT COALESCE(MAX(id), 0) as last_id FROM chat_messages WHERE room_id = ?',
          [roomId]
        );
        const lastMessageId = rows[0].last_id;
        
        // Update read status
        await dbPool.query(`
          INSERT INTO chat_reads (user_id, room_id, last_read_message_id) 
          VALUES (?, ?, ?) 
          ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)
        `, [userId, roomId, lastMessageId]);
        
        // Emit updated unread counts
        emitUnread(userId);
      } catch (error) {
        console.error('Error marking sender as read:', error);
      }
    }
  });

  socket.on('typing', ({ roomId, isTyping }) => {
    if (!roomId) return;
    socket.to(getChatRoom(roomId)).emit('typing', {
      roomId,
      fromUserId: userId,
      isTyping: Boolean(isTyping)
    });
  });

  socket.on('read_room', async ({ roomId }) => {
    if (!roomId) return;
    
    console.log(`User ${userId} marked room ${roomId} as read`);
    
    if (dbPool) {
      try {
        // Get latest message ID for this room
        const [rows] = await dbPool.query(
          'SELECT COALESCE(MAX(id), 0) as last_id FROM chat_messages WHERE room_id = ?',
          [roomId]
        );
        const lastMessageId = rows[0].last_id;
        
        // Update read status
        await dbPool.query(`
          INSERT INTO chat_reads (user_id, room_id, last_read_message_id) 
          VALUES (?, ?, ?) 
          ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)
        `, [userId, roomId, lastMessageId]);
        
        // Emit updated unread counts
        emitUnread(userId);
      } catch (error) {
        console.error('Error marking room as read:', error);
      }
    }
  });

  socket.on('disconnect', () => {
    console.log(`User ${userId} disconnected`);
  });
});

app.get('/health', (req, res) => {
  res.json({ 
    ok: true, 
    database: dbPool ? 'connected' : 'disconnected',
    supportEvents: supportEventHandler ? 'initialized' : 'not initialized',
    timestamp: new Date().toISOString()
  });
});

// 新增：任務狀態和應徵狀態通知端點
app.post('/api/notify', async (req, res) => {
  try {
    // 驗證請求
    const authHeader = req.headers.authorization;
    const expectedToken = process.env.SOCKET_SERVER_TOKEN || 'your-socket-server-token';
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Authorization header required' });
    }
    
    const token = authHeader.substring(7);
    if (token !== expectedToken) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    
    // 解析請求數據
    const { event, data, userIds } = req.body;
    
    if (!event || !data || !Array.isArray(userIds)) {
      return res.status(400).json({ error: 'Invalid request data' });
    }
    
    console.log(`📋 Received notification: ${event} for users: ${userIds.join(', ')}`);
    
    // 向指定用戶發送事件
    let sentCount = 0;
    for (const userId of userIds) {
      const userRoom = getUserRoom(userId);
      const sockets = await io.in(userRoom).fetchSockets();
      
      if (sockets.length > 0) {
        io.to(userRoom).emit(event, data);
        sentCount++;
        console.log(`✅ Sent ${event} to user ${userId}`);
      } else {
        console.log(`⚠️ User ${userId} not connected, skipping notification`);
      }
    }
    
    res.json({
      success: true,
      event,
      totalUsers: userIds.length,
      sentCount,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 新增：獲取用戶連接狀態的端點
app.get('/api/users/status', async (req, res) => {
  try {
    const { userIds } = req.query;
    
    if (!userIds) {
      return res.status(400).json({ error: 'userIds parameter required' });
    }
    
    const userIdArray = userIds.split(',').map(id => id.trim());
    const status = {};
    
    for (const userId of userIdArray) {
      const userRoom = getUserRoom(userId);
      const sockets = await io.in(userRoom).fetchSockets();
      status[userId] = {
        connected: sockets.length > 0,
        socketCount: sockets.length
      };
    }
    
    res.json({
      success: true,
      status,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ User status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 暴露客服事件處理器給外部使用（供 PHP API 調用）
global.supportEventHandler = supportEventHandler;

// 添加客服事件通知端點
app.post('/support/event/new', express.json(), async (req, res) => {
  try {
    const { chatRoomId, eventData } = req.body;
    if (supportEventHandler) {
      await supportEventHandler.broadcastEventNew(chatRoomId, eventData);
      res.json({ success: true, message: 'Event notification sent' });
    } else {
      res.status(503).json({ error: 'Support event handler not available' });
    }
  } catch (error) {
    console.error('Support event new notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/support/event/update', express.json(), async (req, res) => {
  try {
    const { chatRoomId, eventId, oldStatus, newStatus, adminId } = req.body;
    if (supportEventHandler) {
      await supportEventHandler.broadcastEventUpdate(chatRoomId, eventId, oldStatus, newStatus, adminId);
      res.json({ success: true, message: 'Event update notification sent' });
    } else {
      res.status(503).json({ error: 'Support event handler not available' });
    }
  } catch (error) {
    console.error('Support event update notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/support/event/closed', express.json(), async (req, res) => {
  try {
    const { chatRoomId, eventId, rating, review } = req.body;
    if (supportEventHandler) {
      await supportEventHandler.broadcastEventClosed(chatRoomId, eventId, rating, review);
      res.json({ success: true, message: 'Event closed notification sent' });
    } else {
      res.status(503).json({ error: 'Support event handler not available' });
    }
  } catch (error) {
    console.error('Support event closed notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

server.listen(PORT, () => {
  console.log(`Socket.IO Gateway listening on :${PORT}`);
  console.log(`Database mode: ${dbPool ? 'connected' : 'in-memory'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  if (dbPool) {
    dbPool.end();
  }
  server.close(() => {
    console.log('Process terminated');
  });
});