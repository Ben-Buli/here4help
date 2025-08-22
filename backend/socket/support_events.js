/**
 * 客服事件 WebSocket 處理器
 * 
 * 支援的事件：
 * - event:new - 新事件建立
 * - event:update - 事件狀態更新
 * - event:closed - 客戶結案
 * - event:rated - 評分提交
 */

const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');

// 資料庫連線配置
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'here4help',
  charset: 'utf8mb4'
};

class SupportEventHandler {
  constructor(io) {
    this.io = io;
    this.db = null;
    this.initDatabase();
  }

  async initDatabase() {
    try {
      this.db = await mysql.createConnection(dbConfig);
      console.log('✅ Support Events WebSocket: 資料庫連線成功');
    } catch (error) {
      console.error('❌ Support Events WebSocket: 資料庫連線失敗', error);
    }
  }

  /**
   * 處理客戶端連線
   */
  handleConnection(socket) {
    console.log(`🔌 Support Events: 客戶端連線 ${socket.id}`);

    // 驗證 JWT Token
    socket.on('authenticate', async (data) => {
      try {
        const { token } = data;
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
        
        socket.userId = decoded.user_id;
        socket.userRole = decoded.role || 'user';
        
        socket.emit('authenticated', { success: true, userId: socket.userId });
        console.log(`✅ Support Events: 用戶 ${socket.userId} 認證成功`);
      } catch (error) {
        console.error('❌ Support Events: JWT 認證失敗', error);
        socket.emit('authenticated', { success: false, error: 'Invalid token' });
        socket.disconnect();
      }
    });

    // 加入聊天室事件監聽
    socket.on('join_room', (data) => {
      const { chatRoomId } = data;
      if (!socket.userId) {
        socket.emit('error', { message: 'Not authenticated' });
        return;
      }

      socket.join(`support_events_${chatRoomId}`);
      console.log(`📥 Support Events: 用戶 ${socket.userId} 加入聊天室 ${chatRoomId} 事件監聽`);
    });

    // 離開聊天室事件監聽
    socket.on('leave_room', (data) => {
      const { chatRoomId } = data;
      socket.leave(`support_events_${chatRoomId}`);
      console.log(`📤 Support Events: 用戶 ${socket.userId} 離開聊天室 ${chatRoomId} 事件監聽`);
    });

    // 處理斷線
    socket.on('disconnect', () => {
      console.log(`🔌 Support Events: 客戶端斷線 ${socket.id}`);
    });
  }

  /**
   * 廣播新事件建立
   */
  async broadcastEventNew(chatRoomId, eventData) {
    try {
      const roomName = `support_events_${chatRoomId}`;
      
      // 獲取事件詳細資料
      const eventDetail = await this.getEventDetail(eventData.id);
      
      this.io.to(roomName).emit('event:new', {
        type: 'event_created',
        chatRoomId: chatRoomId,
        event: eventDetail,
        timestamp: new Date().toISOString()
      });

      console.log(`📢 Support Events: 廣播新事件到聊天室 ${chatRoomId}`, eventData);
    } catch (error) {
      console.error('❌ Support Events: 廣播新事件失敗', error);
    }
  }

  /**
   * 廣播事件狀態更新
   */
  async broadcastEventUpdate(chatRoomId, eventId, oldStatus, newStatus, adminId = null) {
    try {
      const roomName = `support_events_${chatRoomId}`;
      
      // 獲取事件詳細資料
      const eventDetail = await this.getEventDetail(eventId);
      
      this.io.to(roomName).emit('event:update', {
        type: 'event_updated',
        chatRoomId: chatRoomId,
        eventId: eventId,
        event: eventDetail,
        oldStatus: oldStatus,
        newStatus: newStatus,
        adminId: adminId,
        timestamp: new Date().toISOString()
      });

      console.log(`📢 Support Events: 廣播事件更新到聊天室 ${chatRoomId}`, { eventId, oldStatus, newStatus });
    } catch (error) {
      console.error('❌ Support Events: 廣播事件更新失敗', error);
    }
  }

  /**
   * 廣播客戶結案
   */
  async broadcastEventClosed(chatRoomId, eventId, rating = null, review = null) {
    try {
      const roomName = `support_events_${chatRoomId}`;
      
      // 獲取事件詳細資料
      const eventDetail = await this.getEventDetail(eventId);
      
      this.io.to(roomName).emit('event:closed', {
        type: 'event_closed',
        chatRoomId: chatRoomId,
        eventId: eventId,
        event: eventDetail,
        rating: rating,
        review: review,
        timestamp: new Date().toISOString()
      });

      console.log(`📢 Support Events: 廣播事件結案到聊天室 ${chatRoomId}`, { eventId, rating });
    } catch (error) {
      console.error('❌ Support Events: 廣播事件結案失敗', error);
    }
  }

  /**
   * 廣播評分提交
   */
  async broadcastEventRated(chatRoomId, eventId, rating, review = null) {
    try {
      const roomName = `support_events_${chatRoomId}`;
      
      // 獲取事件詳細資料
      const eventDetail = await this.getEventDetail(eventId);
      
      this.io.to(roomName).emit('event:rated', {
        type: 'event_rated',
        chatRoomId: chatRoomId,
        eventId: eventId,
        event: eventDetail,
        rating: rating,
        review: review,
        timestamp: new Date().toISOString()
      });

      console.log(`📢 Support Events: 廣播事件評分到聊天室 ${chatRoomId}`, { eventId, rating });
    } catch (error) {
      console.error('❌ Support Events: 廣播事件評分失敗', error);
    }
  }

  /**
   * 獲取事件詳細資料
   */
  async getEventDetail(eventId) {
    try {
      if (!this.db) {
        await this.initDatabase();
      }

      const [rows] = await this.db.execute(`
        SELECT 
          se.*,
          cr.id as chat_room_id,
          u_customer.name as customer_name,
          u_admin.name as admin_name
        FROM support_events se
        LEFT JOIN chat_rooms cr ON se.chat_room_id = cr.id
        LEFT JOIN users u_customer ON se.customer_id = u_customer.id
        LEFT JOIN users u_admin ON se.admin_id = u_admin.id
        WHERE se.id = ?
      `, [eventId]);

      if (rows.length === 0) {
        return null;
      }

      const event = rows[0];

      // 獲取事件歷程
      const [logRows] = await this.db.execute(`
        SELECT 
          sel.*,
          u.name as admin_name
        FROM support_event_logs sel
        LEFT JOIN users u ON sel.admin_id = u.id
        WHERE sel.event_id = ?
        ORDER BY sel.created_at ASC
      `, [eventId]);

      event.logs = logRows;

      return event;
    } catch (error) {
      console.error('❌ Support Events: 獲取事件詳細資料失敗', error);
      return null;
    }
  }
}

module.exports = SupportEventHandler;
