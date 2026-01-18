import axios from 'axios'
import type { AxiosInstance, AxiosResponse } from 'axios'
import { API_CONFIG, ENV_CONFIG, API_ENDPOINTS } from '@/config/api'

/**
 * HTTP 客戶端: 建立和管理 axios 實例
 * 請求/響應攔截器: 處理認證、錯誤處理
 * API 服務封裝: 提供具體的 API 調用方法
 * 型別定義: 定義 API 響應的 TypeScript 介面
 */

// 建立 axios 實例
const api: AxiosInstance = axios.create({
  baseURL: ENV_CONFIG.isLocal ? '' : API_CONFIG.baseUrl, // 本地開發使用代理
  timeout: API_CONFIG.timeout,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
  withCredentials: true, // 因為 Sanctum 的 CSRF Cookie 機制需要跨域攜帶 cookie，這裡 withCredentials: true 是必須的。
})

// 請求攔截器 - 添加 token 和 CSRF 處理
api.interceptors.request.use(
  async (config) => {
    // 對於需要 CSRF 保護的請求，先獲取 CSRF Token
    if (config.method !== 'get' && !config.url?.includes('/sanctum/csrf-cookie')) {
      try {
        await api.get('/sanctum/csrf-cookie')
      } catch (error) {
        console.warn('Failed to get CSRF token:', error)
      }
    }

    // 添加認證 token
    const token = localStorage.getItem('admin_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  },
)

// 響應攔截器 - 處理錯誤
api.interceptors.response.use(
  (response: AxiosResponse) => {
    return response
  },
  (error) => {
    if (error.response?.status === 401) {
      const url: string = error.config?.url || ''
      const isPhpDisputeApi = url.includes('/api/admin/task-disputes')
      const isLoginApi = url.includes('/api/admin/login')
      
      if (!isPhpDisputeApi && !isLoginApi) {
        // 僅對 Laravel 管理端 API 觸發登出；排除 PHP 爭議聊天室 API 和登入 API
        localStorage.removeItem('admin_token')
        localStorage.removeItem('admin_user')
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  },
)

// API 介面定義
export interface ApiResponse<T = any> {
  success: boolean
  data?: T
  message?: string
  errors?: Record<string, string[]>
}

export interface PaginationMeta {
  current_page: number
  per_page: number
  total: number
  last_page: number
}

export interface PaginatedResponse<T>
  extends ApiResponse<{
    items: T[]
    pagination: PaginationMeta
    stats?: any
  }> {}

export interface PasswordResetLinkResponse {
  user_id: number
  user_name: string
  email: string
  reset_link: string
  token: string
  expires_at: string
  remaining_seconds: number
  created_at: string
  created_by?: number | null
  created_by_name?: string | null
  was_existing_link: boolean
}

export interface AdminAccount {
  id: number
  username: string
  full_name: string
  email: string
  status: string
  last_login: string | null
  login_attempts: number
  locked_until: string | null
  created_at: string
  role: {
    name: string | null
    display_name: string | null
  }
}

export interface AdminPasswordResetLinkResponse {
  admin_id: number
  admin_name: string
  admin_email: string
  role_name?: string | null
  reset_link: string
  token: string
  expires_at: string
  remaining_seconds: number
  created_at: string
  created_by: number
  created_by_name?: string | null
  was_existing_link: boolean
}

// 認證相關 API
export const authApi = {
  // 獲取 CSRF Token (Sanctum SPA 認證必需)
  getCsrfToken: () => api.get('/sanctum/csrf-cookie'),

  login: (email: string, password: string) =>
    api.post<
      ApiResponse<{
        admin: any
        token: string
        permissions: string[]
      }>
    >(API_ENDPOINTS.auth.login(), { email, password }),

  logout: () => api.post<ApiResponse>(API_ENDPOINTS.auth.logout()),

  me: () =>
    api.get<
      ApiResponse<{
        admin: any
        permissions: string[]
      }>
    >(API_ENDPOINTS.auth.me()),

  refresh: () => api.post<ApiResponse<{ token: string }>>(API_ENDPOINTS.auth.refresh()),
}

// 用戶管理 API
export const userApi = {
  list: (params?: {
    page?: number
    per_page?: number
    status?: string
    permission?: number
    user_id?: number
    search?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>(API_ENDPOINTS.users.list(), { params }),

  show: (id: number) =>
    api.get<
      ApiResponse<{
        user: any
        stats: any
        recent_activities: any[]
        student_verification?: any
      }>
    >(API_ENDPOINTS.users.show(id)),

  updateStatus: (id: number, status: string, reason?: string) =>
    api.patch<ApiResponse>(API_ENDPOINTS.users.updateStatus(id), { status, reason }),

  updatePermission: (id: number, permission: number, reason?: string) =>
    api.patch<ApiResponse>(API_ENDPOINTS.users.updatePermission(id), { permission, reason }),

  batchAction: (action: string, user_ids: number[], reason?: string) =>
    api.post<ApiResponse>(API_ENDPOINTS.users.batchAction(), { action, user_ids, reason }),

  // 新增推薦碼相關 API
  verification: (id: number) =>
    api.get<ApiResponse<any>>(API_ENDPOINTS.users.verification(id)),

  introReferralInfo: (id: number) =>
    api.get<ApiResponse<any>>(API_ENDPOINTS.users.introReferralInfo(id)),

  termsHistory: (id: number) =>
    api.get<
      ApiResponse<{
        user_registered_at: string
        items: Array<{
          id: number
          version: string
          title: string
          created_at: string
          accepted_at?: string
        }>
      }>
    >(API_ENDPOINTS.users.termsHistory(id)),

  review: (
    id: number,
    payload: {
      decision: 'approve' | 'reject'
      notes: string
      new_permission: number
    },
  ) => api.post<ApiResponse<any>>(API_ENDPOINTS.users.review(id), payload),

  passwordResetLink: (id: number) =>
    api.post<ApiResponse<PasswordResetLinkResponse>>(API_ENDPOINTS.users.passwordResetLink(id)),
}

export const adminAccountsApi = {
  list: (params?: {
    page?: number
    per_page?: number
    search?: string
    status?: string
    role?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<AdminAccount>>(API_ENDPOINTS.admins.list(), { params }),

  passwordResetLink: (id: number) =>
    api.post<ApiResponse<AdminPasswordResetLinkResponse>>(API_ENDPOINTS.admins.passwordResetLink(id)),
}

// 任務管理 API
export const taskApi = {
  list: (params?: {
    page?: number
    per_page?: number
    status_id?: number
    creator_id?: number
    participant_id?: number
    search?: string
    date_from?: string
    date_to?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/tasks', { params }),

  // 任務狀態（管理端 Laravel API）
  statuses: (params?: { active?: 0 | 1 }) =>
    api.get<ApiResponse<any[]>>('/api/admin/tasks/statuses', { params }),

  show: (id: string) =>
    api.get<
      ApiResponse<{
        task: any
      }>
    >(`/api/admin/tasks/${id}`),

  updateStatus: (id: string, status_id: number, reason?: string) =>
    api.patch<ApiResponse>(`/api/admin/tasks/${id}/status`, { status_id, reason }),

  reports: (taskId: string) =>
    api.get<
      ApiResponse<{
        task_id: number
        task_title: string
        has_pending: boolean
        reports: any[]
      }>
    >(`/api/admin/tasks/${taskId}/reports`),

  resolveReport: (reportId: string | number, payload: { decision: string; notes: string }) =>
    api.post<ApiResponse>(`/api/admin/tasks/reports/${reportId}/resolve`, payload),

  moderate: (taskId: string, payload: { action: string; reason: string }) =>
    api.post<ApiResponse>(`/api/admin/tasks/${taskId}/moderate`, payload),
}

// 客服(支援) API
export const supportApi = {
  // 獲取客服事件列表（對接新的 issues API）
  listIssues: (params?: {
    page?: number
    per_page?: number
    type?: 'all' | 'support' | 'dispute'
    status?: 'submitted' | 'in_progress' | 'resolved'
    search?: string
  }) => api.get<PaginatedResponse<any>>('/api/support/issues', { params }),

  // 管理員接手客服事件（對接新的 claim API）
  claimIssue: (roomId: string) => 
    api.post<ApiResponse<{
      room_id: string
      event_id: string
      admin_id: string
      status: string
      old_status: string
      message: string
    }>>('/api/support/claim', { room_id: roomId }),

  // 更新事件狀態（對接現有的 events PATCH API）
  updateEventStatus: (eventId: string, status: 'submitted' | 'in_progress' | 'resolved') =>
    api.patch<ApiResponse<{
      event_id: string
      status: string
      message: string
    }>>('/api/support/events', { event_id: eventId, status }),

  // 獲取事件詳情和時間線（對接現有的 events GET API）
  getEventDetails: (chatRoomId: string) =>
    api.get<ApiResponse<{
      events: Array<{
        id: string
        title: string
        description: string
        status: string
        closed_at?: string
        rating?: number
        review?: string
        created_at: string
        updated_at: string
        customer_name?: string
        admin_name?: string
        logs: Array<{
          old_status?: string
          new_status: string
          created_at: string
          admin_name?: string
        }>
      }>
      chat_room_id: string
    }>>(`/api/support/events?chat_room_id=${chatRoomId}`),

  // 向後相容的舊方法（標記為 deprecated）
  /** @deprecated 使用 claimIssue 替代 */
  accept: (roomId: string) => api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/accept`),
  
  /** @deprecated 使用 updateEventStatus 替代 */
  updateStatus: (roomId: string, status: string) =>
    api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/status`, { status }),
}

// 管理員客服 API
export const adminSupportApi = {
  // 管理員獲取支援問題列表
  listIssues: (params?: {
    page?: number
    per_page?: number
    type?: 'all' | 'support' | 'dispute'
    status?: 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed'
    search?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/support/issues', { params }),

  // 管理員接手支援問題
  claimIssue: (roomId: string) => 
    api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/accept`),

  // 管理員更新支援問題狀態
  updateStatus: (roomId: string, status: 'submitted' | 'in_progress' | 'resolved') =>
    api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/status`, { status }),

  // 管理員獲取自己負責的聊天室列表
  listChatRooms: (params?: {
    page?: number
    per_page?: number
    status?: 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed'
    search?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/support/chat-rooms', { params }),

  // 管理員獲取單個聊天室詳情
  getChatRoom: (roomId: string) => 
    api.get<ApiResponse<any>>(`/api/admin/support/chat-rooms/${roomId}`),

  // 管理員獲取聊天室訊息
  getMessages: (roomId: string, params?: {
    limit?: number
    before_id?: number
  }) => api.get<ApiResponse<{
    messages: any[]
    unread_count: number
    has_more: boolean
  }>>(`/api/admin/support/chat-rooms/${roomId}/messages`, { params }),

  // 管理員發送訊息
  sendMessage: (roomId: string, data: {
    content: string
    kind?: 'text' | 'image' | 'system'
  }) => api.post<ApiResponse<{
    message_id: number
    content: string
    kind: string
    created_at: string
  }>>(`/api/admin/support/chat-rooms/${roomId}/messages`, data),

  // 管理員標記訊息為已讀
  markAsRead: (roomId: string, messageId: number) =>
    api.post<ApiResponse<{
      message_id: number
      read_at: string
    }>>(`/api/admin/support/chat-rooms/${roomId}/read`, { message_id: messageId }),

  // 向後相容的舊方法
  /** @deprecated 使用 listIssues 替代 */
  chatRooms: (params?: {
    page?: number
    per_page?: number
    type?: string
    status?: string
    search?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/support/issues', { params }),
}

// 日誌管理 API
export const logApi = {
  list: (params?: {
    page?: number
    per_page?: number
    search?: string
    user_id?: number
    action_type?: string
    date_from?: string
    date_to?: string
    log_type?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/logs', { params }),

  activityLogs: (params?: {
    page?: number
    per_page?: number
    admin_id?: number
    action?: string
    resource_type?: string
    date_from?: string
    date_to?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/logs/activity', { params }),

  loginLogs: (params?: {
    page?: number
    per_page?: number
    admin_id?: number
    status?: string
    ip_address?: string
    date_from?: string
    date_to?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/logs/login', { params }),

  systemStats: (params?: { period?: 'today' | 'week' | 'month' | 'year' }) =>
    api.get<
      ApiResponse<{
        period: string
        date_from: string
        admin_stats: any
        user_stats: any
        task_stats: any
        login_stats: any
      }>
    >('/api/admin/logs/stats', { params }),
}

// 條款管理 API
export const appTermsApi = {
  list: () => api.get<ApiResponse<any[]>>(API_ENDPOINTS.appTerms.list()),
  detail: (id: number) => api.get<ApiResponse<any>>(API_ENDPOINTS.appTerms.detail(id)),
  push: (id: number, payload?: Record<string, any>) =>
    api.post<ApiResponse>(API_ENDPOINTS.appTerms.push(id), payload),
}

// 系統資訊 API
export const systemApi = {
  dashboard: () => api.get<ApiResponse>('/api/admin/dashboard'),
  test: () => api.get<ApiResponse>('/api/test'),
}

// 付款/儲值 API（Admin）
export const paymentApi = {
  requests: (params?: {
    page?: number
    per_page?: number
    status?: 'pending' | 'approved' | 'rejected'
    from_date?: string
    to_date?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/payment/requests', { params }),

  approve: (id: number, note?: string) => api.post<ApiResponse>(`/api/admin/payment/requests/${id}/approve`, { note }),
  reject: (id: number, note?: string) => api.post<ApiResponse>(`/api/admin/payment/requests/${id}/reject`, { note }),

  withdrawRequests: (params?: {
    page?: number
    per_page?: number
    status?: 'pending' | 'approved' | 'rejected' | 'cancelled' | 'paid'
    from_date?: string
    to_date?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/payment/withdraw-requests', { params }),

  approveWithdraw: (id: number, note?: string) =>
    api.post<ApiResponse>(`/api/admin/payment/withdraw-requests/${id}/approve`, { note }),
  rejectWithdraw: (id: number, note?: string) =>
    api.post<ApiResponse>(`/api/admin/payment/withdraw-requests/${id}/reject`, { note }),
  markWithdrawPaid: (id: number) =>
    api.post<ApiResponse>(`/api/admin/payment/withdraw-requests/${id}/paid`, {}),

  getFeeSettings: () => api.get<ApiResponse<{ items: any[] }>>('/api/admin/payment/fee-settings'),
  setFeeSettings: (percentage: number) => api.post<ApiResponse>('/api/admin/payment/fee-settings', { percentage }),

  getOfficialAccounts: () => api.get<ApiResponse<{ items: any[] }>>('/api/admin/payment/official-accounts'),
  setOfficialAccount: (payload: { bank_name: string; account_number: string; account_name: string }) =>
    api.post<ApiResponse>('/api/admin/payment/official-accounts', payload),
}

// 使用者活動紀錄 API
export const userActivityApi = {
  list: (params?: {
    page?: number
    per_page?: number
    user_id?: number
    action?: string
    actor_type?: 'user' | 'admin' | 'system'
    date_from?: string
    date_to?: string
    search?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/user-activities', { params }),

  show: (userId: number, params?: {
    page?: number
    per_page?: number
    action?: string
    date_from?: string
    date_to?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/user-activities-by-user', { 
    params: { ...params, user_id: userId } 
  }),
}

// 使用者交易紀錄 API
export const userTransactionApi = {
  list: (params?: {
    page?: number
    per_page?: number
    user_id?: number
    transaction_type?: 'earn' | 'spend' | 'deposit' | 'fee' | 'refund' | 'adjustment'
    date_from?: string
    date_to?: string
    search?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/user-transactions', { params }),

  show: (userId: number, params?: {
    page?: number
    per_page?: number
    transaction_type?: 'earn' | 'spend' | 'deposit' | 'fee' | 'refund' | 'adjustment'
    date_from?: string
    date_to?: string
  }) => api.get<PaginatedResponse<any>>(`/api/admin/user-transactions/${userId}`, { params }),
}

// 任務爭議 API
export const disputeApi = {
  list: (params?: {
    page?: number
    per_page?: number
    status?: string
    date_from?: string
    date_to?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/disputes', { params }),

  show: (id: string) => api.get<ApiResponse<any>>(`/api/admin/disputes/${id}`),

  updateStatus: (id: string, action: 'resolve' | 'reject' | 'reopen', notes?: string, resolution?: string) =>
    api.patch<ApiResponse>(`/api/admin/disputes/${id}/status`, { 
      action,
      notes,
      resolution
    }),

  batchAction: (action: 'resolve' | 'reject' | 'reopen', task_ids: string[], notes?: string) =>
    api.post<ApiResponse>('/api/admin/disputes/batch-action', {
      action,
      task_ids,
      notes
    }),

  // 管理員查看聊天室 - 暫時保留但可能需要調整
  getChatRoom: (disputeId: string) => 
    api.get<ApiResponse<any>>(`/api/admin/task-disputes/chat-room?dispute_id=${disputeId}`),

  // 以 taskId 取得聊天室（後端已支援 fallback）
  getChatRoomByTask: (taskId: string) => 
    api.get<ApiResponse<any>>(`/api/admin/task-disputes/${taskId}/chat-room`),

  // 管理員查看爭議聊天記錄 - 使用正確的端點
  getChatMessages: (disputeId: number) =>
    api.get<ApiResponse<any>>(`/api/admin/disputes/${disputeId}/chat-messages`),

  // 解決爭議
  resolve: (disputeId: string, decision: string, note: string) =>
    api.post<ApiResponse<any>>('/api/admin/task-disputes/resolve', {
      dispute_id: disputeId,
      decision,
      note
    }),
}

export default api
