// 環境變數配置
export const config = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8888/here4help/backend',
  apiTimeout: parseInt(import.meta.env.VITE_API_TIMEOUT || '10000'),
  appTitle: import.meta.env.VITE_APP_TITLE || 'Here4Help Admin Panel',
  appVersion: import.meta.env.VITE_APP_VERSION || '1.0.0',
  debugMode: import.meta.env.VITE_DEBUG_MODE === 'true',
  socketUrl: import.meta.env.VITE_SOCKET_URL || 'http://localhost:8888/here4help/socket' || 'http://localhost:3000',
  imageBaseUrl: import.meta.env.VITE_IMAGE_BASE_URL || 'http://localhost:8888/here4help',
  isDevelopment: import.meta.env.DEV,
  isProduction: import.meta.env.PROD,
  
  
  // 功能開關
  features: {
    chat: import.meta.env.VITE_ENABLE_CHAT !== 'false',
    disputes: import.meta.env.VITE_ENABLE_DISPUTES !== 'false',
    support: import.meta.env.VITE_ENABLE_SUPPORT !== 'false',
    analytics: import.meta.env.VITE_ENABLE_ANALYTICS !== 'false',
  }
}

console.log('config.socketUrl', config.socketUrl)


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
  // 生產環境使用圖片基礎 URL
  return `${config.imageBaseUrl}/uploads/${path}`
}
