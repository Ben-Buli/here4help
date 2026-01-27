import { io, Socket } from 'socket.io-client'
import { config } from '@/config/env'

/**
 * Socket.IO 即時聊天服務
 * 用於後台管理員與用戶的即時通訊
 */
class SocketService {
  private static instance: SocketService
  private socket: Socket | null = null
  private isConnected = false
  private currentRoomId: string | null = null
  private reconnectAttempts = 0
  private maxReconnectAttempts = 5

  // 事件監聽器
  private messageListeners: Array<(data: any) => void> = []
  private unreadListeners: Array<(data: any) => void> = []
  private typingListeners: Array<(data: any) => void> = []
  private connectionListeners: Array<(connected: boolean) => void> = []

  private constructor() {}

  static getInstance(): SocketService {
    if (!SocketService.instance) {
      SocketService.instance = new SocketService()
    }
    return SocketService.instance
  }

  /**
   * 連接到 Socket.IO 服務器
   */
  async connect(): Promise<void> {
    if (this.isConnected && this.socket) {
      console.log('🔌 Socket already connected')
      return
    }

    try {
      // 獲取管理員認證 token
      const token = localStorage.getItem('admin_token')
      if (!token) {
        throw new Error('No admin token found')
      }

      // 創建 Socket.IO 連接
      this.socket = io(config.socketUrl, {
        path: '/socket',
        transports: ['websocket', 'polling'],
        autoConnect: false,
        query: {
          token: token
        },
        forceNew: true,
        reconnection: true,
        reconnectionAttempts: this.maxReconnectAttempts,
        reconnectionDelay: 1000,
      })

      // 設置事件監聽器
      this.setupEventListeners()

      // 連接
      this.socket.connect()

      console.log('🔌 Socket connecting to:', config.socketUrl)

    } catch (error) {
      console.error('❌ Socket connection failed:', error)
      throw error
    }
  }

  /**
   * 設置事件監聽器
   */
  private setupEventListeners(): void {
    if (!this.socket) return

    // 連接成功
    this.socket.on('connect', () => {
      console.log('✅ Socket connected:', this.socket?.id)
      this.isConnected = true
      this.reconnectAttempts = 0
      this.notifyConnectionListeners(true)

      // 如果之前有加入房間，重新加入
      if (this.currentRoomId) {
        this.joinRoom(this.currentRoomId)
      }
    })

    // 連接斷開
    this.socket.on('disconnect', (reason) => {
      console.log('❌ Socket disconnected:', reason)
      this.isConnected = false
      this.notifyConnectionListeners(false)
    })

    // 連接錯誤
    this.socket.on('connect_error', (error) => {
      console.error('❌ Socket connection error:', error)
      this.reconnectAttempts++
      
      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        console.error('❌ Max reconnection attempts reached')
        this.notifyConnectionListeners(false)
      }
    })

    // 接收訊息
    this.socket.on('message', (data) => {
      console.log('📨 Received message:', data)
      this.notifyMessageListeners(data)
    })

    // 未讀訊息更新
    this.socket.on('unread_by_room', (data) => {
      console.log('📊 Unread update:', data)
      this.notifyUnreadListeners(data)
    })

    // 打字狀態
    this.socket.on('typing', (data) => {
      console.log('⌨️ Typing update:', data)
      this.notifyTypingListeners(data)
    })

    // 認證成功
    this.socket.on('authenticated', (data) => {
      console.log('✅ Socket authenticated:', data)
    })

    // 認證失敗
    this.socket.on('authenticated', (data) => {
      if (!data.success) {
        console.error('❌ Socket authentication failed:', data.error)
        this.disconnect()
      }
    })
  }

  /**
   * 斷開連接
   */
  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect()
      this.socket = null
    }
    this.isConnected = false
    this.currentRoomId = null
    this.notifyConnectionListeners(false)
    console.log('🔌 Socket disconnected')
  }

  /**
   * 加入聊天室
   */
  joinRoom(roomId: string): void {
    if (!this.isConnected || !this.socket) {
      console.warn('⚠️ Socket not connected, cannot join room')
      return
    }

    this.socket.emit('join_room', { roomId })
    this.currentRoomId = roomId
    console.log('🏠 Joined room:', roomId)
  }

  /**
   * 離開聊天室
   */
  leaveRoom(roomId: string): void {
    if (!this.isConnected || !this.socket) {
      return
    }

    this.socket.emit('leave_room', { roomId })
    if (this.currentRoomId === roomId) {
      this.currentRoomId = null
    }
    console.log('🚪 Left room:', roomId)
  }

  /**
   * 發送訊息
   */
  sendMessage(roomId: string, text: string, messageId?: string): void {
    if (!this.isConnected || !this.socket) {
      console.warn('⚠️ Socket not connected, cannot send message')
      return
    }

    this.socket.emit('send_message', {
      roomId,
      messageId: messageId || Date.now().toString(),
      text,
      toUserIds: []
    })
    console.log('📤 Sent message to room:', roomId)
  }

  /**
   * 發送打字狀態
   */
  sendTyping(roomId: string, isTyping: boolean): void {
    if (!this.isConnected || !this.socket) {
      return
    }

    this.socket.emit('typing', {
      roomId,
      isTyping
    })
  }

  /**
   * 標記訊息為已讀
   */
  markAsRead(roomId: string, messageId: string): void {
    if (!this.isConnected || !this.socket) {
      return
    }

    this.socket.emit('read_room', {
      roomId,
      messageId
    })
    console.log('✅ Marked as read:', roomId, messageId)
  }

  // 事件監聽器管理
  addMessageListener(listener: (data: any) => void): void {
    this.messageListeners.push(listener)
  }

  removeMessageListener(listener: (data: any) => void): void {
    const index = this.messageListeners.indexOf(listener)
    if (index > -1) {
      this.messageListeners.splice(index, 1)
    }
  }

  addUnreadListener(listener: (data: any) => void): void {
    this.unreadListeners.push(listener)
  }

  removeUnreadListener(listener: (data: any) => void): void {
    const index = this.unreadListeners.indexOf(listener)
    if (index > -1) {
      this.unreadListeners.splice(index, 1)
    }
  }

  addTypingListener(listener: (data: any) => void): void {
    this.typingListeners.push(listener)
  }

  removeTypingListener(listener: (data: any) => void): void {
    const index = this.typingListeners.indexOf(listener)
    if (index > -1) {
      this.typingListeners.splice(index, 1)
    }
  }

  addConnectionListener(listener: (connected: boolean) => void): void {
    this.connectionListeners.push(listener)
  }

  removeConnectionListener(listener: (connected: boolean) => void): void {
    const index = this.connectionListeners.indexOf(listener)
    if (index > -1) {
      this.connectionListeners.splice(index, 1)
    }
  }

  // 通知方法
  private notifyMessageListeners(data: any): void {
    this.messageListeners.forEach(listener => {
      try {
        listener(data)
      } catch (error) {
        console.error('❌ Message listener error:', error)
      }
    })
  }

  private notifyUnreadListeners(data: any): void {
    this.unreadListeners.forEach(listener => {
      try {
        listener(data)
      } catch (error) {
        console.error('❌ Unread listener error:', error)
      }
    })
  }

  private notifyTypingListeners(data: any): void {
    this.typingListeners.forEach(listener => {
      try {
        listener(data)
      } catch (error) {
        console.error('❌ Typing listener error:', error)
      }
    })
  }

  private notifyConnectionListeners(connected: boolean): void {
    this.connectionListeners.forEach(listener => {
      try {
        listener(connected)
      } catch (error) {
        console.error('❌ Connection listener error:', error)
      }
    })
  }

  // Getters
  get connected(): boolean {
    return this.isConnected
  }

  get currentRoom(): string | null {
    return this.currentRoomId
  }
}

// 導出單例實例
export const socketService = SocketService.getInstance()
export default socketService
