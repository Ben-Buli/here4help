// admin/frontend/vite.config.ts
import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  // 後端 api
  const backendUrl = new URL(env.VITE_BACKEND_API_URL || 'http://localhost:8888/here4help/backend')
  const backendOrigin = backendUrl.origin
  const backendBasePath = backendUrl.pathname.replace(/\/$/, '') || ''
  const adminApiUrl = env.VITE_ADMIN_API_URL || 'http://localhost:8000'

  return {
     // 前端資源路徑以 /admin/ 開頭
     base: '/admin/',
     build: {
       outDir: '../public',
       emptyOutDir: true,
     },
    plugins: [vue(), vueDevTools()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      proxy: {
        '/uploads': {
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (p) => `${backendBasePath}${p}`,
        },
        '/sanctum': {
          target: adminApiUrl, 
          changeOrigin: true,
        },
        '/api/admin/task-disputes': {
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (p) => {
            const m = p.match(/^\/api\/admin\/task-disputes\/([^\/]+)\/chat-room$/)
            if (m) return `${backendBasePath}/api/admin/task-disputes/chat-room.php?task_id=${encodeURIComponent(m[1])}`
            return p.replace(/^\/api\/admin\/task-disputes\/(.*)$/, `${backendBasePath}/api/admin/task-disputes/$1.php`)
          },
        },
        '/api/admin': {
          target: adminApiUrl,
          changeOrigin: true,
        },
        '^/api(?!/admin)': {
          target: backendOrigin,
          changeOrigin: true,
          rewrite: (p) => `${backendBasePath}${p}`,
        },
      },
    },
  }
})