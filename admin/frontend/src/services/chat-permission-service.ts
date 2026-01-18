/**
 * 統一聊天室權限管理服務
 * 提供一致的聊天室權限控制邏輯
 */

// 聊天室類型定義
export type ChatRoomType = 'dispute' | 'support' | 'application'

// 用戶角色定義
export type UserRole = 'admin' | 'user' | 'creator' | 'participant'

// 聊天室狀態定義
export type ChatRoomStatus = 'open' | 'in_progress' | 'resolved' | 'closed'

// 權限動作定義
export type PermissionAction = 'view' | 'send_message' | 'claim' | 'transfer' | 'resolve' | 'close'

/**
 * 聊天室權限配置介面
 */
export interface ChatRoomPermissionConfig {
  roomType: ChatRoomType
  userRole: UserRole
  roomStatus: ChatRoomStatus
  isAssignedAdmin?: boolean // 是否為指派的管理員
  isRoomCreator?: boolean // 是否為房間創建者
}

/**
 * 權限檢查結果
 */
export interface PermissionResult {
  allowed: boolean
  reason?: string
  requiresAction?: string
}

/**
 * 統一聊天室權限管理服務
 */
export class ChatRoomPermissionService {
  /**
   * 檢查用戶是否具有指定動作的權限
   * @param config 權限配置
   * @param action 要檢查的動作
   * @returns 權限檢查結果
   */
  static checkPermission(
    config: ChatRoomPermissionConfig,
    action: PermissionAction
  ): PermissionResult {
    // 基本權限檢查
    switch (action) {
      case 'view':
        return this._checkViewPermission(config)
      
      case 'send_message':
        return this._checkSendMessagePermission(config)
      
      case 'claim':
        return this._checkClaimPermission(config)
      
      case 'transfer':
        return this._checkTransferPermission(config)
      
      case 'resolve':
        return this._checkResolvePermission(config)
      
      case 'close':
        return this._checkClosePermission(config)
      
      default:
        return { allowed: false, reason: 'Unknown action' }
    }
  }

  /**
   * 檢查查看權限
   */
  private static _checkViewPermission(config: ChatRoomPermissionConfig): PermissionResult {
    const { userRole } = config

    // 所有用戶都可以查看聊天室
    if (userRole === 'admin' || userRole === 'user') {
      return { allowed: true }
    }

    // 創建者和參與者可以查看自己的聊天室
    if (userRole === 'creator' || userRole === 'participant') {
      return { allowed: true }
    }

    return { allowed: false, reason: 'Insufficient permissions to view chat room' }
  }

  /**
   * 檢查發送訊息權限
   */
  private static _checkSendMessagePermission(config: ChatRoomPermissionConfig): PermissionResult {
    const { roomType, userRole, roomStatus } = config

    // 已關閉的聊天室不允許發送訊息
    if (roomStatus === 'closed' || roomStatus === 'resolved') {
      return { 
        allowed: false, 
        reason: 'Cannot send messages to closed chat room' 
      }
    }

    switch (roomType) {
      case 'dispute':
        // 爭議聊天室：只有用戶可以發送訊息，管理員只能查看
        if (userRole === 'creator' || userRole === 'participant') {
          return { allowed: true }
        }
        return { 
          allowed: false, 
          reason: 'Admins can only view dispute chat rooms' 
        }

      case 'support':
        // 客服聊天室：用戶和管理員都可以發送訊息
        if (userRole === 'user' || userRole === 'admin') {
          return { allowed: true }
        }
        return { 
          allowed: false, 
          reason: 'Only users and admins can send messages in support chat' 
        }

      case 'application':
        // 任務聊天室：創建者和參與者都可以發送訊息
        if (userRole === 'creator' || userRole === 'participant') {
          return { allowed: true }
        }
        return { 
          allowed: false, 
          reason: 'Only task creator and participant can send messages' 
        }

      default:
        return { allowed: false, reason: 'Unknown room type' }
    }
  }

  /**
   * 檢查接手權限
   */
  private static _checkClaimPermission(config: ChatRoomPermissionConfig): PermissionResult {
    const { roomType, userRole, roomStatus, isAssignedAdmin } = config

    // 只有管理員可以接手
    if (userRole !== 'admin') {
      return { 
        allowed: false, 
        reason: 'Only admins can claim chat rooms' 
      }
    }

    // 已經被接手的聊天室不能再次接手
    if (isAssignedAdmin) {
      return { 
        allowed: false, 
        reason: 'Chat room is already claimed by another admin' 
      }
    }

    // 已關閉的聊天室不能接手
    if (roomStatus === 'closed' || roomStatus === 'resolved') {
      return { 
        allowed: false, 
        reason: 'Cannot claim closed chat room' 
      }
    }

    // 只有客服聊天室可以被接手
    if (roomType !== 'support') {
      return { 
        allowed: false, 
        reason: 'Only support chat rooms can be claimed' 
      }
    }

    return { allowed: true }
  }

  /**
   * 檢查轉派權限
   */
  private static _checkTransferPermission(config: ChatRoomPermissionConfig): PermissionResult {
    const { userRole, isAssignedAdmin } = config

    // 只有管理員可以轉派
    if (userRole !== 'admin') {
      return { 
        allowed: false, 
        reason: 'Only admins can transfer chat rooms' 
      }
    }

    // 只有被指派的管理員可以轉派
    if (!isAssignedAdmin) {
      return { 
        allowed: false, 
        reason: 'Only assigned admin can transfer chat room' 
      }
    }

    return { allowed: true }
  }

  /**
   * 檢查解決權限
   */
  private static _checkResolvePermission(config: ChatRoomPermissionConfig): PermissionResult {
    const { userRole, isAssignedAdmin } = config

    // 只有管理員可以解決
    if (userRole !== 'admin') {
      return { 
        allowed: false, 
        reason: 'Only admins can resolve chat rooms' 
      }
    }

    // 只有被指派的管理員可以解決
    if (!isAssignedAdmin) {
      return { 
        allowed: false, 
        reason: 'Only assigned admin can resolve chat room' 
      }
    }

    return { allowed: true }
  }

  /**
   * 檢查關閉權限
   */
  private static _checkClosePermission(config: ChatRoomPermissionConfig): PermissionResult {
    const { roomType, userRole, roomStatus } = config

    // 已關閉的聊天室不能再次關閉
    if (roomStatus === 'closed' || roomStatus === 'resolved') {
      return { 
        allowed: false, 
        reason: 'Chat room is already closed' 
      }
    }

    // 用戶可以關閉自己的客服聊天室
    if (roomType === 'support' && userRole === 'user') {
      return { allowed: true }
    }

    // 管理員可以關閉任何聊天室
    if (userRole === 'admin') {
      return { allowed: true }
    }

    return { 
      allowed: false, 
      reason: 'Insufficient permissions to close chat room' 
    }
  }

  /**
   * 獲取聊天室可用的動作列表
   * @param config 權限配置
   * @returns 可用動作列表
   */
  static getAvailableActions(config: ChatRoomPermissionConfig): PermissionAction[] {
    const actions: PermissionAction[] = ['view']
    
    // 檢查每個動作的權限
    const allActions: PermissionAction[] = [
      'send_message',
      'claim',
      'transfer',
      'resolve',
      'close'
    ]

    for (const action of allActions) {
      const result = this.checkPermission(config, action)
      if (result.allowed) {
        actions.push(action)
      }
    }

    return actions
  }

  /**
   * 檢查聊天室是否為唯讀模式
   * @param config 權限配置
   * @returns 是否為唯讀模式
   */
  static isReadOnly(config: ChatRoomPermissionConfig): boolean {
    const sendMessageResult = this.checkPermission(config, 'send_message')
    return !sendMessageResult.allowed
  }

  /**
   * 獲取聊天室狀態顯示文字
   * @param status 聊天室狀態
   * @returns 顯示文字
   */
  static getStatusDisplayText(status: ChatRoomStatus): string {
    const statusMap: Record<ChatRoomStatus, string> = {
      'open': 'Open',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
      'closed': 'Closed'
    }
    return statusMap[status] || status
  }

  /**
   * 獲取聊天室類型顯示文字
   * @param type 聊天室類型
   * @returns 顯示文字
   */
  static getTypeDisplayText(type: ChatRoomType): string {
    const typeMap: Record<ChatRoomType, string> = {
      'dispute': 'Dispute',
      'support': 'Support',
      'application': 'Task Chat'
    }
    return typeMap[type] || type
  }
}

// 導出類型定義 (移除重複導出)
// 這些類型已經在檔案開頭定義，不需要重複導出

// 導出服務實例
export default ChatRoomPermissionService
