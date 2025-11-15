import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/login',
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
          path: 'referral-codes',
          name: 'users-referral-codes',
          component: () => import('../views/ReferralCodesView.vue'),
          meta: { title: 'Referral Codes' },
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
      path: '/user-activities',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'logs.view' },
      children: [
        {
          path: '',
          name: 'user-activities',
          component: () => import('../views/UserActivitiesView.vue'),
          meta: { title: 'User Activities' },
        },
      ],
    },
    {
      path: '/user-transactions',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'logs.view' },
      children: [
        {
          path: '',
          name: 'user-transactions',
          component: () => import('../views/UserTransactionsView.vue'),
          meta: { title: 'User Transactions' },
        },
      ],
    },
    {
      path: '/task-disputes',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'disputes.list' },
      children: [
        {
          path: '',
          name: 'task-disputes',
          component: () => import('../views/TaskDisputesView.vue'),
          meta: { title: 'Task Disputes' },
        },
        {
          path: ':taskId/chat-room',
          name: 'admin-dispute-chat-room',
          component: () => import('../views/AdminChatRoomView.vue'),
          meta: { 
            title: 'Dispute Chat Room',
            permission: 'disputes.view'
          },
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
      path: '/issues',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'issues',
          component: () => import('../views/IssuesView.vue'),
          meta: { title: 'Issues' },
        },
      ],
    },
    {
      path: '/support-chat-list',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'support-chat-list',
          component: () => import('../views/SupportChatListView.vue'),
          meta: { title: 'Support Chat List' },
        },
        {
          path: ':roomId',
          name: 'support-chat-detail',
          component: () => import('../views/SupportChatDetailView.vue'),
          meta: { title: 'Support Chat Detail' },
        },
      ],
    },
    {
      path: '/payments',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          redirect: '/payments/requests',
        },
        {
          path: 'requests',
          name: 'payment-requests',
          component: () => import('../components/wallet/DepositApprovalPage.vue'),
          meta: { title: 'Deposit Requests' },
        },
        {
          path: 'fee-settings',
          name: 'payment-fee-settings',
          component: () => import('../components/wallet/FeeManagementPage.vue'),
          meta: { title: 'Fee Settings' },
        },
        {
          path: 'fee-revenue',
          name: 'payment-fee-revenue',
          component: () => import('../components/wallet/FeeRevenuePage.vue'),
          meta: { title: 'Fee Revenue' },
        },
        {
          path: 'official-account',
          name: 'payment-official-account',
          component: () => import('../components/wallet/OfficialBankAccountPage.vue'),
          meta: { title: 'Official Bank Account' },
        },
      ],
    },
    {
      path: '/point-policies',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true, permission: 'points.edit' },
      children: [
        {
          path: '',
          name: 'point-policies',
          component: () => import('../views/PointPolicyView.vue'),
          meta: { title: 'Point Policy' },
        },
      ],
    },
    {
      path: '/faqs',
      component: () => import('../components/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'faqs',
          component: () => import('../views/FAQView.vue'),
          meta: { title: 'FAQ Management' },
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
