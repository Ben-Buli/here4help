// 環境變數配置
export const config = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000',
  apiTimeout: parseInt(import.meta.env.VITE_API_TIMEOUT || '10000'),
  appTitle: import.meta.env.VITE_APP_TITLE || 'Admin Panel',
  isDevelopment: import.meta.env.DEV,
  isProduction: import.meta.env.PROD,
}

// 環境檢查
export const isLocal = config.apiBaseUrl.includes('localhost')
export const isStaging = config.apiBaseUrl.includes('staging')
export const isProduction = config.isProduction

// 根據環境返回不同的 API URL
export const getApiUrl = (path: string = '') => {
  if (isLocal) {
    // 本地開發使用代理
    return path
  }
  // 生產環境使用完整 URL
  return `${config.apiBaseUrl}${path}`
}

// 根據環境返回不同的圖片 URL
export const getImageUrl = (path: string) => {
  if (isLocal) {
    // 本地開發使用代理
    return `/uploads/${path}`
  }
  // 生產環境使用完整 URL
  return `${config.apiBaseUrl}/uploads/${path}`
}
