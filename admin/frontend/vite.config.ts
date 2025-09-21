// admin/frontend/vite.config.ts
import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

export default defineConfig(({ mode }) => {
  // 載入環境變數
  const env = loadEnv(mode, process.cwd(), '')
  
  // 後端 API 與資源 URL
  const apiBaseUrl = env.VITE_BACKEND_API_URL || 'http://localhost:8888/here4help/backend'
  const socketUrl = env.VITE_SOCKET_URL || 'http://localhost:3001'
  const imageBaseUrl = env.VITE_IMAGE_BASE_URL || 'http://localhost:8888/here4help'
  const backendUrl = new URL(apiBaseUrl)
  const backendOrigin = backendUrl.origin
  const backendBasePath = backendUrl.pathname.replace(/\/$/, '') || ''
  const adminHost = env.VITE_API_BASE_URL || 'http://localhost:8000'
  
  return {
    // 🔑 確保資源以 /admin/ 開頭
    base: '/admin/',

    // 🔑 輸出到 Laravel 的 public/ 目錄
    build: {
      outDir: '../public',
      emptyOutDir: true,
    },

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
        '/uploads': {
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (path) => `${backendBasePath}${path}`
        },
        '/api/admin/task-disputes': {
          target: backendOrigin,
          changeOrigin: true,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With'
          },
          rewrite: (path) => {
            const m = path.match(/^\/api\/admin\/task-disputes\/([^\/]+)\/chat-room$/)
            if (m) {
              const taskId = encodeURIComponent(m[1])
              return `${backendBasePath}/api/admin/task-disputes/chat-room.php?task_id=${taskId}`
            }
            return path.replace(/^\/api\/admin\/task-disputes\/(.*)$/,
              `${backendBasePath}/api/admin/task-disputes/$1.php`)
          }
        },
        '/api/admin': {
          target: adminHost,
          changeOrigin: true,
        },
        '^/api(?!/admin)': {
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (path) => `${backendBasePath}${path}`
        }
      }
    }
  }
})