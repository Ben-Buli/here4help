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

const PORT = process.env.PORT || 3001;

// Load environment variables once at startup
require('dotenv').config({ path: '../../.env' });

// Get JWT secret once
const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  console.error('❌ JWT_SECRET not configured in environment variables');
  process.exit(1);
}

console.log('✅ JWT_SECRET loaded successfully');

const app = express();
app.use(cors());

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
function validateJWT(token) {
  try {
    if (!JWT_SECRET) {
      console.error('JWT_SECRET not configured');
      return null;
    }
    
    const payload = jwt.verify(token, JWT_SECRET);
    if (!payload.user_id) return null;
    return payload; // { user_id, email, name, ... }
  } catch (e) {
    console.error('JWT validation failed:', e.message);
    return null;
  }
}

function validateTokenBase64(token) {
  try {
    const decoded = Buffer.from(token, 'base64').toString('utf8');
    const payload = JSON.parse(decoded);
    if (!payload.user_id || !payload.exp) return null;
    if (payload.exp < Date.now() / 1000) return null;
    return payload; // { user_id, email, name, ... }
  } catch (e) {
    return null;
  }
}

// 統一的 token 驗證函數
function validateToken(token) {
  // 首先嘗試 JWT 驗證
  let payload = validateJWT(token);
  if (payload) {
    console.log('✅ JWT token validated successfully');
    return payload;
  }
  
  // 如果 JWT 失敗，嘗試 base64 驗證（向後兼容）
  payload = validateTokenBase64(token);
  if (payload) {
    console.log('✅ Base64 token validated successfully (legacy)');
    return payload;
  }
  
  console.log('❌ Token validation failed for both JWT and Base64');
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

io.use((socket, next) => {
  const { token } = socket.handshake.query || {};
  if (!token) return next(new Error('Unauthorized: token missing'));
  const payload = validateToken(String(token));
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
    timestamp: new Date().toISOString()
  });
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