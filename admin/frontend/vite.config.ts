import { fileURLToPath, URL } from 'node:url'

import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // 載入環境變數
  const env = loadEnv(mode, process.cwd(), '')
  
  // 從環境變數獲取API基礎URL，如果沒有則使用預設值
  const apiBaseUrl = env.VITE_API_BASE_URL || 'http://localhost:8889/here4help/backend'
  const socketUrl = env.VITE_SOCKET_URL || 'http://localhost:3001'
  const imageBaseUrl = env.VITE_IMAGE_BASE_URL || 'http://localhost:8889/here4help'
  
  return {
    plugins: [
      vue(),
      vueDevTools(),
    ],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      },
    },
    server: {
      proxy: {
        // 圖片上傳代理
        '/uploads': {
          target: 'http://localhost:8889',
          changeOrigin: true,
          rewrite: (path) => {
            const rewrittenPath = `/here4help/backend${path}`
            console.log('🔄 Uploads Proxy:', path, '->', rewrittenPath)
            return rewrittenPath
          }
        },
        // 所有管理員API代理 - 統一路由到Laravel應用
        '/api/admin': {
          target: 'http://localhost:8000',
          changeOrigin: true,
          rewrite: (path) => {
            console.log('🔄 Admin API Proxy:', path, '->', path)
            return path
          }
        },
        // 其他API代理 - 路由到PHP後端（排除 /api/admin）
        '^/api(?!/admin)': {
          target: 'http://localhost:8889',
          changeOrigin: true,
          rewrite: (path) => {
            const rewrittenPath = `/here4help/backend${path}`
            console.log('🔄 Backend API Proxy:', path, '->', rewrittenPath)
            return rewrittenPath
          }
        }
      }
    }
  }
})
