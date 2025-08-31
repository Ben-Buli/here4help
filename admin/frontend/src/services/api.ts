import axios from 'axios'
import type { AxiosInstance, AxiosResponse } from 'axios'

// API 基礎配置
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

// 建立 axios 實例
const api: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
})

// 請求攔截器 - 添加 token
api.interceptors.request.use(
  (config) => {
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
      // Token 過期或無效，清除本地存儲並跳轉到登入頁
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_user')
      window.location.href = '/login'
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

// 認證相關 API
export const authApi = {
  login: (email: string, password: string) =>
    api.post<
      ApiResponse<{
        admin: any
        token: string
        permissions: string[]
      }>
    >('/api/admin/login', { email, password }),

  logout: () => api.post<ApiResponse>('/api/admin/logout'),

  me: () =>
    api.get<
      ApiResponse<{
        admin: any
        permissions: string[]
      }>
    >('/api/admin/me'),

  refresh: () => api.post<ApiResponse<{ token: string }>>('/api/admin/refresh'),
}

// 用戶管理 API
export const userApi = {
  list: (params?: {
    page?: number
    per_page?: number
    status?: string
    permission?: number
    search?: string
    sort_by?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/api/admin/users', { params }),

  show: (id: number) =>
    api.get<
      ApiResponse<{
        user: any
        stats: any
        recent_activities: any[]
        student_verification?: any
      }>
    >(`/api/admin/users/${id}`),

  updateStatus: (id: number, status: string, reason?: string) =>
    api.patch<ApiResponse>(`/api/admin/users/${id}/status`, { status, reason }),

  updatePermission: (id: number, permission: number, reason?: string) =>
    api.patch<ApiResponse>(`/api/admin/users/${id}/permission`, { permission, reason }),

  batchAction: (action: string, user_ids: number[], reason?: string) =>
    api.post<ApiResponse>('/api/admin/users/batch-action', { action, user_ids, reason }),
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

  show: (id: string) =>
    api.get<
      ApiResponse<{
        task: any
      }>
    >(`/api/admin/tasks/${id}`),

  updateStatus: (id: string, status_id: number, reason?: string) =>
    api.patch<ApiResponse>(`/api/admin/tasks/${id}/status`, { status_id, reason }),
}

// 支援/客服 API
export const supportApi = {
  listIssues: (params?: {
    page?: number
    per_page?: number
    type?: 'all' | 'support' | 'dispute'
    status?: 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed'
    search?: string
  }) => api.get<PaginatedResponse<any>>('/api/admin/support/issues', { params }),

  accept: (roomId: string) => api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/accept`),
  transfer: (roomId: string, target_admin_id: number) =>
    api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/transfer`, { target_admin_id }),
  updateStatus: (roomId: string, status: 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed') =>
    api.post<ApiResponse>(`/api/admin/support/issues/${roomId}/status`, { status }),
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
  }) => api.get<PaginatedResponse<any>>(`/api/admin/user-activities/${userId}`, { params }),
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

export default api
