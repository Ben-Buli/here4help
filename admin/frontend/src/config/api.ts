/**
 * 統一API配置管理
 * 提供一致的API基礎URL和端點配置
 */

// API 基礎配置
export const API_CONFIG = {
  // Laravel Admin API URL
  baseUrl: import.meta.env.VITE_API_BASE_URL,
  
  // PHP Backend API URL (for Flutter app compatibility)
  backendUrl: import.meta.env.VITE_BACKEND_API_URL,
  
  // API 前綴
  adminPrefix: '/api/admin',
  userPrefix: '/api',
  
  // 超時設定
  timeout: parseInt(import.meta.env.VITE_API_TIMEOUT || '10000'),
  
  // 應用程式標題
  appTitle: import.meta.env.VITE_APP_TITLE || 'Here4Help Admin Panel',
}

// 環境檢測
export const ENV_CONFIG = {
  isDevelopment: import.meta.env.DEV,
  isProduction: import.meta.env.PROD,
  isLocal: API_CONFIG.baseUrl.includes('localhost'),
  isStaging: API_CONFIG.baseUrl.includes('staging'),
}

/**
 * 獲取完整的API URL
 * @param path API路徑
 * @param useAdminPrefix 是否使用管理員前綴
 * @returns 完整的API URL
 */
export const getApiUrl = (path: string = '', useAdminPrefix: boolean = true): string => {
  const prefix = useAdminPrefix ? API_CONFIG.adminPrefix : API_CONFIG.userPrefix
  
  // 確保路徑以 / 開頭
  const normalizedPath = path.startsWith('/') ? path : `/${path}`
  
  if (ENV_CONFIG.isLocal) {
    // 本地開發使用代理，直接返回相對路徑
    return `${prefix}${normalizedPath}`
  }
  
  // 生產環境使用完整URL
  return `${API_CONFIG.baseUrl}${prefix}${normalizedPath}`
}

/**
 * 獲取圖片URL
 * @param path 圖片路徑
 * @returns 完整的圖片URL
 */
export const getImageUrl = (path: string): string => {
  if (ENV_CONFIG.isLocal) {
    // 本地開發使用代理，Vite 會將 /uploads 代理到後端
    return `/uploads/${path}`
  }
  
  // 生產環境使用完整URL
  return `${API_CONFIG.backendUrl}/uploads/${path}`
}

/**
 * API端點配置
 * 統一管理所有API端點，便於維護和修改
 * 遵循RESTful API設計規範
 * 
 * 注意：目前使用現有的後端端點，未來可逐步遷移到標準化端點
 */
export const API_ENDPOINTS = {
  // 認證相關 - 使用現有端點
  auth: {
    login: () => getApiUrl('/login'),
    logout: () => getApiUrl('/logout'),
    me: () => getApiUrl('/me'),
    refresh: () => getApiUrl('/refresh'),
  },
  
  // 用戶管理
  users: {
    list: () => getApiUrl('/users'),
    show: (id: number) => getApiUrl(`/users/${id}`),
    updateStatus: (id: number) => getApiUrl(`/users/${id}/status`),
    updatePermission: (id: number) => getApiUrl(`/users/${id}/permission`),
    batchAction: () => getApiUrl('/users/batch-action'),
    activities: (id: number) => getApiUrl(`/users/${id}/activities`),
    pointTransactions: (id: number) => getApiUrl(`/users/${id}/point-transactions`),
    review: (id: number) => getApiUrl(`/users/${id}/review`),
    verification: (id: number) => getApiUrl(`/users/${id}/verification`),
    referralInfo: (id: number) => getApiUrl(`/users/${id}/referral-info`),
    introReferralInfo: (id: number) => getApiUrl(`/users/${id}/intro-referral-info`),
  },
  
  // 任務管理
  tasks: {
    list: () => getApiUrl('/tasks'),
    show: (id: number) => getApiUrl(`/tasks/${id}`),
    updateStatus: (id: number) => getApiUrl(`/tasks/${id}/status`),
  },
  
  // 爭議管理 - 修正為Laravel路由
  disputes: {
    list: () => getApiUrl('/disputes'),
    show: (id: number) => getApiUrl(`/disputes/${id}`),
    chatRoom: (id: number) => getApiUrl(`/disputes/${id}`),
    resolve: (id: number) => getApiUrl(`/disputes/${id}/status`),
    updateStatus: (id: number) => getApiUrl(`/disputes/${id}/status`),
  },
  
  // 客服管理 - 修正為Laravel路由
  support: {
    issues: () => getApiUrl('/support/issues'),
    issue: (id: number) => getApiUrl(`/support/issues/${id}`),
    claim: (id: number) => getApiUrl(`/support/issues/${id}/accept`),
    transfer: (id: number) => getApiUrl(`/support/issues/${id}/transfer`),
    status: (id: number) => getApiUrl(`/support/issues/${id}/status`),
    chatRoom: (id: number) => getApiUrl(`/support/issues/${id}`),
  },
  
  // 費用管理
  fees: {
    settings: () => getApiUrl('/fees/settings'),
    revenue: () => getApiUrl('/fees/revenue'),
  },
  
  // 推薦管理
  referrals: {
    events: () => getApiUrl('/referral-events'),
  },
  
  // 日誌管理 - 修正為Laravel路由
  logs: {
    stats: () => getApiUrl('/logs/stats'),
    activity: () => getApiUrl('/logs/activity'),
    login: () => getApiUrl('/logs/login'),
    userActivities: () => getApiUrl('/user-activities'),
  },
  
  // 媒體管理
  media: {
    scan: () => getApiUrl('/media/scan', false), // 不使用管理員前綴
  },
}

// 導出配置供其他模組使用
export default API_CONFIG
