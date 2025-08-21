import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/dashboard',
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/LoginView.vue'),
      meta: { requiresGuest: true },
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'dashboard-home',
          component: () => import('../views/DashboardView.vue'),
          meta: { title: 'Dashboard' },
        },
      ],
    },
    {
      path: '/users',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'users.list' },
      children: [
        {
          path: '',
          name: 'users',
          component: () => import('../views/UsersView.vue'),
          meta: { title: 'Users' },
        },
        {
          path: ':id',
          name: 'user-detail',
          component: () => import('../views/UserDetailView.vue'),
          meta: { title: 'User Detail' },
        },
      ],
    },
    {
      path: '/tasks',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'tasks.list' },
      children: [
        {
          path: '',
          name: 'tasks',
          component: () => import('../views/TasksView.vue'),
          meta: { title: 'Tasks' },
        },
        {
          path: ':id',
          name: 'task-detail',
          component: () => import('../views/TaskDetailView.vue'),
          meta: { title: 'Task Detail' },
        },
      ],
    },
    {
      path: '/logs',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'logs.view' },
      children: [
        {
          path: '',
          name: 'logs',
          component: () => import('../views/LogsView.vue'),
          meta: { title: 'Logs' },
        },
      ],
    },
    {
      path: '/settings',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'settings',
          component: () => import('../views/SettingsView.vue'),
          meta: { title: 'Settings' },
        },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('../views/NotFoundView.vue'),
    },
  ],
})

// 路由守衛
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()

  // 初始化認證狀態
  if (!authStore.isAuthenticated && localStorage.getItem('admin_token')) {
    await authStore.initialize()
  }

  // 檢查是否需要認證
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login')
    return
  }

  // 檢查是否需要訪客狀態（如登入頁）
  if (to.meta.requiresGuest && authStore.isAuthenticated) {
    next('/dashboard')
    return
  }

  // 檢查權限
  if (to.meta.permission && !authStore.hasPermission(to.meta.permission as string)) {
    // 沒有權限，跳轉到儀表板
    next('/dashboard')
    return
  }

  next()
})

export default router
