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

const PORT = process.env.PORT || process.env.SOCKET_PORT || 3000;

// Load environment variables from socket/.env only
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');

// 明確指定 socket 目錄的 .env
const envPath = path.resolve(__dirname, './.env');
dotenv.config({ path: envPath });

console.log(`🔧 Loaded environment from ${envPath}`);

// Get JWT secret once
const JWT_SECRET = process.env.JWT_SECRET ;

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
  path: "/socket",
  cors: {
    origin: ['http://localhost/3000', 'https://hero4help.demofhs.com'],
    methods: ['GET', 'POST'],
    credentials: true
  }
});

// Database connection pool
let dbPool = null;

async function initDatabase() {
  try {
    // 初始化 MySQL 資料庫（MAMP）
    dbPool = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 8889,
      user: process.env.DB_USERNAME || 'root',
      password: process.env.DB_PASSWORD || 'root',
      database: process.env.DB_NAME || 'hero4helpdemofhs_hero4helpdemofhs,
      charset: process.env.DB_CHARSET || 'utf8mb4',
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });

    // 印出 DB Config
    console.log('DB Config:', {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USERNAME,
      database: process.env.DB_NAME,
      charset: process.env.DB_CHARSET
    });
    
    // Test database connection
    await dbPool.query('SELECT 1');
    console.log('MySQL database connected successfully');
    
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

// 驗證管理員 Sanctum Token
async function validateAdminToken(token, traceId) {
  if (!dbPool) {
    console.error(`[${traceId}] ❌ Database not available for admin token validation`);
    return null;
  }

  try {
    // Laravel Sanctum token 格式: {id}|{hash}
    // 我們需要提取 hash 部分來查詢資料庫
    const tokenParts = token.split('|');
    if (tokenParts.length !== 2) {
      console.error(`[${traceId}] ❌ Invalid Sanctum token format: ${token}`);
      return null;
    }

    const tokenId = tokenParts[0];
    const tokenHash = tokenParts[1];

    console.log(`[${traceId}] 🔍 Validating admin token - ID: ${tokenId}, Hash: ${tokenHash.substring(0, 10)}...`);

    // Laravel Sanctum 會將 token hash 後儲存，我們需要 hash 原始 token 來比較
    const crypto = require('crypto');
    const hashedToken = crypto.createHash('sha256').update(tokenHash).digest('hex');

    // 查詢 personal_access_tokens 表
    const [rows] = await dbPool.query(
      'SELECT id, tokenable_id, name, abilities, last_used_at, expires_at FROM personal_access_tokens WHERE id = ? AND token = ?',
      [tokenId, hashedToken]
    );

    if (rows.length === 0) {
      console.error(`[${traceId}] ❌ Admin token not found in database (ID: ${tokenId})`);
      return null;
    }

    const tokenData = rows[0];
    
    // 檢查 token 是否過期
    if (tokenData.expires_at && new Date(tokenData.expires_at) < new Date()) {
      console.error(`[${traceId}] ❌ Admin token expired`);
      return null;
    }
    
    // 查詢管理員資訊
    const [adminRows] = await dbPool.query(
      'SELECT id, username, full_name, email, status FROM admins WHERE id = ? AND status = "active"',
      [tokenData.tokenable_id]
    );

    if (adminRows.length === 0) {
      console.error(`[${traceId}] ❌ Admin user not found or inactive (ID: ${tokenData.tokenable_id})`);
      return null;
    }

    const admin = adminRows[0];
    
    // 更新 token 使用時間
    await dbPool.query(
      'UPDATE personal_access_tokens SET last_used_at = NOW() WHERE id = ?',
      [tokenId]
    );

    console.log(`[${traceId}] ✅ Admin token validated successfully for admin: ${admin.username} (ID: ${admin.id})`);
    
    return {
      user_id: `admin_${admin.id}`, // 使用 admin_ 前綴區分管理員
      admin_id: admin.id,
      username: admin.username,
      full_name: admin.full_name,
      email: admin.email,
      role: 'admin'
    };
  } catch (error) {
    console.error(`[${traceId}] ❌ Admin token validation failed:`, error.message);
    return null;
  }
}

// 統一的 token 驗證函數
async function validateToken(token, socket) {
  const traceId = generateTraceId(socket);

  // 調試：顯示 token 格式資訊
  if (process.env.NODE_ENV === 'development') {
    console.log(`[${traceId}] 🔍 Token format analysis:`);
    console.log(`[${traceId}] - Length: ${token ? token.length : 0}`);
    console.log(`[${traceId}] - Parts: ${token ? token.split('.').length : 0}`);
    console.log(`[${traceId}] - First 50 chars: ${token ? token.slice(0, 50) + '...' : 'null'}`);
  }

  // 1. 嘗試 JWT token 驗證
  let payload = validateJWT(token, traceId);
  if (payload) {
    console.log(`[${traceId}] ✅ JWT token validated successfully`);
    return payload;
  }

  // 2. 嘗試 Base64 token 驗證
  payload = validateTokenBase64(token, traceId);
  if (payload) {
    console.log(`[${traceId}] ✅ Base64 token validated successfully (legacy)`);
    return payload;
  }

  // 3. 嘗試管理員 Sanctum token 驗證
  payload = await validateAdminToken(token, traceId);
  if (payload) {
    console.log(`[${traceId}] ✅ Admin Sanctum token validated successfully`);
    return payload;
  }

  if (process.env.NODE_ENV === 'development') {
    console.error(`[${traceId}] ❌ Token validation failed (JWT, Base64 & Admin). Token snippet:`, token ? token.slice(0, 30) + '...' : 'null');
  } else {
    console.error(`[${traceId}] ❌ Token validation failed (JWT, Base64 & Admin).`);
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
    // 先查詢一般聊天室
    let [rows] = await dbPool.query(
      'SELECT creator_id, participant_id FROM chat_rooms WHERE id = ?',
      [roomId]
    );
    
    // 如果一般聊天室沒找到，查詢客服聊天室
    if (rows.length === 0) {
      [rows] = await dbPool.query(
        'SELECT user_id, admin_id FROM support_chat_rooms WHERE id = ?',
        [roomId]
      );
      
      if (rows.length === 0) return [];
      
      const room = rows[0];
      const members = [];
      if (room.user_id) members.push(room.user_id.toString());
      if (room.admin_id) members.push(`admin_${room.admin_id}`);
      return members;
    }
    
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
    // 先查詢一般聊天室的未讀數量
    let [rows] = await dbPool.query(`
      SELECT COUNT(*) as count
      FROM chat_messages cm
      LEFT JOIN chat_reads cr ON cm.room_id = cr.room_id AND cr.user_id = ?
      WHERE cm.room_id = ? AND cm.id > COALESCE(cr.last_read_message_id, 0)
    `, [userId, roomId]);
    
    if (rows[0].count > 0) {
      return rows[0].count;
    }
    
    // 如果一般聊天室沒有未讀，查詢客服聊天室
    [rows] = await dbPool.query(`
      SELECT COUNT(*) as count
      FROM support_chat_messages scm
      LEFT JOIN support_chat_reads scr ON scm.room_id = scr.room_id AND scr.user_id = ?
      WHERE scm.room_id = ? AND scm.id > COALESCE(scr.last_read_message_id, 0)
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
  supportEventHandler = new SupportEventHandler(io, dbPool);
  console.log('✅ Support Event Handler initialized');
}

// 在 IO 初始化後創建客服事件處理器
initSupportEventHandler();

io.use(async (socket, next) => {
  const { token } = socket.handshake.query || {};
  if (!token) return next(new Error('Unauthorized: token missing'));
  
  try {
    // 確保 token 是字符串且不被截斷
    const tokenStr = typeof token === 'string' ? token : String(token);
    
    // 調試：檢查 token 格式
    const traceId = generateTraceId(socket);
    console.log(`[${traceId}] 🔍 Token analysis:`);
    console.log(`[${traceId}] - Type: ${typeof token}`);
    console.log(`[${traceId}] - Length: ${tokenStr.length}`);
    console.log(`[${traceId}] - Parts: ${tokenStr.split('.').length}`);
    console.log(`[${traceId}] - First 50 chars: ${tokenStr.slice(0, 50)}...`);
    
    const payload = await validateToken(tokenStr, socket);
    if (!payload) return next(new Error('Unauthorized: invalid token'));
    
    socket.user = { 
      id: String(payload.user_id),
      role: payload.role || 'user',
      admin_id: payload.admin_id || null,
      username: payload.username || null,
      full_name: payload.full_name || null,
      email: payload.email || null
    };
    
    return next();
  } catch (error) {
    console.error('Socket authentication error:', error);
    return next(new Error('Unauthorized: authentication failed'));
  }
});

io.on('connection', (socket) => {
  const userId = socket.user.id;
  const userRole = socket.user.role;
  const isAdmin = userRole === 'admin';
  
  socket.join(getUserRoom(userId));

  if (isAdmin) {
    console.log(`Admin ${socket.user.username} (ID: ${socket.user.admin_id}) connected`);
  } else {
    console.log(`User ${userId} connected`);
  }

  // 只有一般用戶才需要未讀計數推送
  if (!isAdmin) {
    // Initial push for safety (client can also fetch snapshot via REST)
    emitUnread(userId);
  }

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

    const senderInfo = isAdmin ? `Admin ${socket.user.username}` : `User ${userId}`;
    console.log(`${senderInfo} sending message to room ${roomId}`);

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
      fromUserId: isAdmin ? 'admin' : userId,
      fromAdminId: isAdmin ? socket.user.admin_id : null,
      sentAt: Date.now()
    });

    // Increment unread counters for recipients (excluding sender)
    for (const uid of recipients) {
      if (uid && uid !== userId && !uid.startsWith('admin_')) {
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

    // Mark sender as read up-to latest (only for non-admin users)
    if (dbPool && !isAdmin) {
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
    
    const senderInfo = isAdmin ? `Admin ${socket.user.username}` : `User ${userId}`;
    console.log(`${senderInfo} marked room ${roomId} as read`);
    
    // 只有一般用戶才需要更新已讀狀態
    if (dbPool && !isAdmin) {
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
    if (isAdmin) {
      console.log(`Admin ${socket.user.username} (ID: ${socket.user.admin_id}) disconnected`);
    } else {
      console.log(`User ${userId} disconnected`);
    }
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

// Passenger / cPanel 相容寫法
// Cpanel Setup Node.js - Passenger 模式下通常不需要 listen，因為 Passenger 會自己接管 socket
if (require.main === module) {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Socket.IO Gateway listening on :${PORT}`);
  });
} else {
  module.exports = server;
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  if (dbPool) {
    try {
      dbPool.end();
    } catch (error) {
      console.log('Database pool already closed');
    }
  }
  server.close(() => {
    console.log('Process terminated');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  if (dbPool) {
    try {
      dbPool.end();
    } catch (error) {
      console.log('Database pool already closed');
    }
  }
  server.close(() => {
    console.log('Process terminated');
  });
});