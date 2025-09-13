import { fileURLToPath, URL } from 'node:url'

import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // 載入環境變數
  const env = loadEnv(mode, process.cwd(), '')
  
  // 從環境變數獲取API基礎URL，如果沒有則使用預設值
  const apiBaseUrl = env.VITE_BACKEND_API_URL || 'http://localhost:8888/here4help/backend'
  const socketUrl = env.VITE_SOCKET_URL || 'http://localhost:3001'
  const imageBaseUrl = env.VITE_IMAGE_BASE_URL || 'http://localhost:8888/here4help'

  // 以 URL 解析，避免 http/https 或不同主機造成字串替換錯誤
  const backendUrl = new URL(apiBaseUrl)
  const backendOrigin = backendUrl.origin // e.g. http://localhost:8888
  const backendBasePath = backendUrl.pathname.replace(/\/$/, '') || '' // e.g. /here4help/backend
  const adminHost = env.VITE_API_BASE_URL || 'http://localhost:8000'
  
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
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (path) => {
            const rewrittenPath = `${backendBasePath}${path}`
            console.log('🔄 Uploads Proxy:', path, '->', rewrittenPath)
            return rewrittenPath
          }
        },
        // 指定 task-disputes 走 PHP 後端
        '/api/admin/task-disputes': {
          target: backendOrigin,
          changeOrigin: true,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With'
          },
          configure: (proxy, options) => {
            proxy.on('proxyReq', (proxyReq, req, res) => {
              // 轉發 Authorization 標頭
              if (req.headers.authorization) {
                proxyReq.setHeader('Authorization', req.headers.authorization)
                console.log('🔑 Forwarding Authorization header:', req.headers.authorization.substring(0, 20) + '...')
              }
              // 轉發其他重要標頭
              if (req.headers['content-type']) {
                proxyReq.setHeader('Content-Type', req.headers['content-type'])
              }
              if (req.headers['x-requested-with']) {
                proxyReq.setHeader('X-Requested-With', req.headers['x-requested-with'])
              }
            })
          },
          rewrite: (path) => {
            // 支援 REST 風格：/api/admin/task-disputes/:taskId/chat-room -> /backend/api/admin/task-disputes/chat-room.php?task_id=:taskId
            const m = path.match(/^\/api\/admin\/task-disputes\/([^\/]+)\/chat-room$/)
            if (m) {
              const taskId = encodeURIComponent(m[1])
              const rewrittenPath = `${backendBasePath}/api/admin/task-disputes/chat-room.php?task_id=${taskId}`
              console.log('🔄 TaskDisputes Proxy(REST):', path, '->', rewrittenPath)
              return rewrittenPath
            }
            // 舊式 query 參數（保留相容）：/api/admin/task-disputes/chat-room?task_id=...
            const rewrittenPath = path.replace(/^\/api\/admin\/task-disputes\/(.*)$/,
              `${backendBasePath}/api/admin/task-disputes/$1.php`)
            console.log('🔄 TaskDisputes Proxy:', path, '->', rewrittenPath)
            return rewrittenPath
          }
        },
        // 所有管理員API代理 - 統一路由到Laravel應用
        '/api/admin': {
          target: adminHost,
          changeOrigin: true,
          rewrite: (path) => {
            console.log('🔄 Admin API Proxy:', path, '->', path)
            return path
          }
        },
        // 其他API代理 - 路由到PHP後端（排除 /api/admin）
        '^/api(?!/admin)': {
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (path) => {
            const rewrittenPath = `${backendBasePath}${path}`
            console.log('🔄 Backend API Proxy:', path, '->', rewrittenPath)
            return rewrittenPath
          }
        }
      }
    }
  }
})
