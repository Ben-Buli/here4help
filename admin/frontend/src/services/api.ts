import axios from 'axios'
import type { AxiosInstance, AxiosResponse } from 'axios'

// API 基礎配置
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api'

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
    >('/admin/login', { email, password }),

  logout: () => api.post<ApiResponse>('/admin/logout'),

  me: () =>
    api.get<
      ApiResponse<{
        admin: any
        permissions: string[]
      }>
    >('/admin/me'),

  refresh: () => api.post<ApiResponse<{ token: string }>>('/admin/refresh'),
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
  }) => api.get<PaginatedResponse<any>>('/admin/users', { params }),

  show: (id: number) =>
    api.get<
      ApiResponse<{
        user: any
        stats: any
        recent_activities: any[]
      }>
    >(`/admin/users/${id}`),

  updateStatus: (id: number, status: string, reason?: string) =>
    api.patch<ApiResponse>(`/admin/users/${id}/status`, { status, reason }),

  updatePermission: (id: number, permission: number, reason?: string) =>
    api.patch<ApiResponse>(`/admin/users/${id}/permission`, { permission, reason }),

  batchAction: (action: string, user_ids: number[], reason?: string) =>
    api.post<ApiResponse>('/admin/users/batch-action', { action, user_ids, reason }),
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
  }) => api.get<PaginatedResponse<any>>('/admin/tasks', { params }),

  show: (id: string) =>
    api.get<
      ApiResponse<{
        task: any
      }>
    >(`/admin/tasks/${id}`),

  updateStatus: (id: string, status_id: number, reason?: string) =>
    api.patch<ApiResponse>(`/admin/tasks/${id}/status`, { status_id, reason }),
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
  }) => api.get<PaginatedResponse<any>>('/admin/logs', { params }),

  activityLogs: (params?: {
    page?: number
    per_page?: number
    admin_id?: number
    action?: string
    resource_type?: string
    date_from?: string
    date_to?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/admin/logs/activity', { params }),

  loginLogs: (params?: {
    page?: number
    per_page?: number
    admin_id?: number
    status?: string
    ip_address?: string
    date_from?: string
    date_to?: string
    sort_order?: 'asc' | 'desc'
  }) => api.get<PaginatedResponse<any>>('/admin/logs/login', { params }),

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
    >('/admin/logs/stats', { params }),
}

// 系統資訊 API
export const systemApi = {
  dashboard: () => api.get<ApiResponse>('/admin/dashboard'),
  test: () => api.get<ApiResponse>('/test'),
}

export default api
