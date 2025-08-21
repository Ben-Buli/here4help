<template>
  <div class="space-y-6">
    <!-- 頁面標題 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Dashboard
        </h2>
        <p class="mt-1 text-sm text-gray-500">Welcome back, {{ authStore.userDisplayName }}</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4">
        <button @click="refreshData" class="admin-button-secondary" :disabled="isLoading">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- 統計卡片 -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <!-- 用戶統計 -->
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.user_stats?.total_users || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <!-- 活躍用戶 -->
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.user_stats?.active_users || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <!-- 任務統計 -->
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Tasks</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.task_stats?.total_tasks || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <!-- 管理員活動 -->
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Admin Actions</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.admin_stats?.total_actions || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- 快捷操作 -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">User Management</h3>
        <div class="space-y-3">
          <router-link to="/users" class="block w-full admin-button-primary text-center">
            Manage Users
          </router-link>
          <p class="text-sm text-gray-500">View, edit, and manage user accounts and permissions</p>
        </div>
      </div>

      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Task Management</h3>
        <div class="space-y-3">
          <router-link to="/tasks" class="block w-full admin-button-primary text-center">
            Manage Tasks
          </router-link>
          <p class="text-sm text-gray-500">Monitor and manage task status and disputes</p>
        </div>
      </div>

      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">System Logs</h3>
        <div class="space-y-3">
          <router-link to="/logs" class="block w-full admin-button-primary text-center">
            View Logs
          </router-link>
          <p class="text-sm text-gray-500">Review system activity and login logs</p>
        </div>
      </div>
    </div>

    <!-- Charts Section -->
    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">User Registration Trend</h3>
        <div class="h-64">
          <Line v-if="userRegistrationData" :data="userRegistrationData" :options="chartOptions" />
          <div v-else class="h-full flex items-center justify-center text-gray-500">
            Loading chart...
          </div>
        </div>
      </div>

      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Task Status Distribution</h3>
        <div class="h-64">
          <Doughnut v-if="taskStatusData" :data="taskStatusData" :options="doughnutOptions" />
          <div v-else class="h-full flex items-center justify-center text-gray-500">
            Loading chart...
          </div>
        </div>
      </div>
    </div>

    <!-- Additional Charts -->
    <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Daily Activity</h3>
        <div class="h-64">
          <Bar v-if="dailyActivityData" :data="dailyActivityData" :options="chartOptions" />
          <div v-else class="h-full flex items-center justify-center text-gray-500">
            Loading chart...
          </div>
        </div>
      </div>

      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Points Distribution</h3>
        <div class="h-64">
          <Line
            v-if="pointsDistributionData"
            :data="pointsDistributionData"
            :options="chartOptions"
          />
          <div v-else class="h-full flex items-center justify-center text-gray-500">
            Loading chart...
          </div>
        </div>
      </div>
    </div>

    <!-- 最近活動 -->
    <div class="admin-card">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h3>
      <div v-if="isLoading" class="flex justify-center py-4">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>
      <div v-else-if="recentActivity.length === 0" class="text-center py-4 text-gray-500">
        No recent activity
      </div>
      <div v-else class="space-y-3">
        <div
          v-for="activity in recentActivity"
          :key="activity.id"
          class="flex items-center justify-between py-2 border-b border-gray-200 last:border-b-0"
        >
          <div class="flex items-center space-x-3">
            <div class="flex-shrink-0 w-2 h-2 bg-green-400 rounded-full"></div>
            <div>
              <p class="text-sm font-medium text-gray-900">
                {{ activity.admin_name }}
              </p>
              <p class="text-sm text-gray-500">
                {{ activity.description }}
              </p>
            </div>
          </div>
          <div class="text-sm text-gray-400">
            {{ formatDate(activity.created_at) }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { logApi } from '@/services/api'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js'
import { Line, Bar, Doughnut } from 'vue-chartjs'

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
)

const authStore = useAuthStore()
const isLoading = ref(false)
const stats = ref<any>({})
const recentActivity = ref<any[]>([])

// Chart data
const userRegistrationData = ref<any>(null)
const taskStatusData = ref<any>(null)
const dailyActivityData = ref<any>(null)
const pointsDistributionData = ref<any>(null)

// Chart options
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'top' as const,
    },
  },
  scales: {
    y: {
      beginAtZero: true,
    },
  },
}

const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'right' as const,
    },
  },
}

const loadDashboardData = async () => {
  try {
    isLoading.value = true

    // 載入統計資料
    const statsResponse = await logApi.systemStats({ period: 'week' })
    if (statsResponse.data.success) {
      stats.value = statsResponse.data.data
    }

    // 載入最近活動
    const activityResponse = await logApi.activityLogs({
      page: 1,
      per_page: 10,
      sort_order: 'desc',
    })
    if (activityResponse.data.success) {
      recentActivity.value = activityResponse.data.data?.items || []
    }

    // Load chart data
    await loadChartData()
  } catch (error) {
    console.error('Failed to load dashboard data:', error)
    // Load mock data for development
    loadMockChartData()
  } finally {
    isLoading.value = false
  }
}

const loadChartData = async () => {
  try {
    // This would be real API calls to get chart data
    // For now, we'll use mock data
    loadMockChartData()
  } catch (error) {
    console.error('Failed to load chart data:', error)
    loadMockChartData()
  }
}

const loadMockChartData = () => {
  // User Registration Trend
  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const date = new Date()
    date.setDate(date.getDate() - (6 - i))
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  })

  userRegistrationData.value = {
    labels: last7Days,
    datasets: [
      {
        label: 'New Users',
        data: [12, 19, 8, 15, 22, 18, 25],
        borderColor: 'rgb(59, 130, 246)',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.4,
      },
    ],
  }

  // Task Status Distribution
  taskStatusData.value = {
    labels: ['Open', 'In Progress', 'Completed', 'Cancelled', 'Disputed'],
    datasets: [
      {
        data: [45, 25, 120, 8, 3],
        backgroundColor: [
          'rgba(59, 130, 246, 0.8)',
          'rgba(251, 191, 36, 0.8)',
          'rgba(34, 197, 94, 0.8)',
          'rgba(156, 163, 175, 0.8)',
          'rgba(239, 68, 68, 0.8)',
        ],
        borderWidth: 0,
      },
    ],
  }

  // Daily Activity
  dailyActivityData.value = {
    labels: last7Days,
    datasets: [
      {
        label: 'Logins',
        data: [65, 59, 80, 81, 56, 55, 70],
        backgroundColor: 'rgba(34, 197, 94, 0.8)',
      },
      {
        label: 'Tasks Created',
        data: [28, 48, 40, 19, 86, 27, 45],
        backgroundColor: 'rgba(59, 130, 246, 0.8)',
      },
      {
        label: 'Tasks Completed',
        data: [18, 35, 25, 15, 42, 20, 35],
        backgroundColor: 'rgba(251, 191, 36, 0.8)',
      },
    ],
  }

  // Points Distribution
  pointsDistributionData.value = {
    labels: last7Days,
    datasets: [
      {
        label: 'Points Earned',
        data: [450, 320, 580, 420, 650, 380, 520],
        borderColor: 'rgb(168, 85, 247)',
        backgroundColor: 'rgba(168, 85, 247, 0.1)',
        tension: 0.4,
      },
      {
        label: 'Points Spent',
        data: [200, 180, 250, 190, 280, 160, 220],
        borderColor: 'rgb(239, 68, 68)',
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        tension: 0.4,
      },
    ],
  }
}

const refreshData = () => {
  loadDashboardData()
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleString()
}

onMounted(() => {
  loadDashboardData()
})
</script>
