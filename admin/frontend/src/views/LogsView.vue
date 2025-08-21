<template>
  <div class="space-y-6">
    <!-- 頁面標題與操作 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          System Logs
        </h2>
        <p class="mt-1 text-sm text-gray-500">
          Monitor system activities, user actions, and login records
        </p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
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
        <button @click="exportLogs" class="admin-button-primary">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          Export
        </button>
      </div>
    </div>

    <!-- 日誌類型標籤 -->
    <div class="border-b border-gray-200">
      <nav class="-mb-px flex space-x-8">
        <button
          v-for="tab in logTabs"
          :key="tab.key"
          @click="activeTab = tab.key"
          :class="[
            activeTab === tab.key
              ? 'border-primary-500 text-primary-600'
              : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300',
            'whitespace-nowrap py-2 px-1 border-b-2 font-medium text-sm',
          ]"
        >
          {{ tab.name }}
          <span
            v-if="tab.count"
            :class="[
              activeTab === tab.key
                ? 'bg-primary-100 text-primary-600'
                : 'bg-gray-100 text-gray-900',
              'ml-2 py-0.5 px-2.5 rounded-full text-xs font-medium',
            ]"
          >
            {{ tab.count }}
          </span>
        </button>
      </nav>
    </div>

    <!-- 篩選與搜尋 -->
    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <!-- 搜尋 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
          <input
            v-model="filters.search"
            type="text"
            placeholder="User, action, IP address..."
            class="admin-input"
            @input="debouncedSearch"
          />
        </div>

        <!-- 用戶篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">User ID</label>
          <input
            v-model="filters.user_id"
            type="number"
            placeholder="User ID"
            class="admin-input"
            @input="() => loadLogs()"
          />
        </div>

        <!-- 動作類型篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Action Type</label>
          <select v-model="filters.action_type" @change="() => loadLogs()" class="admin-input">
            <option value="">All Actions</option>
            <option value="login">Login</option>
            <option value="logout">Logout</option>
            <option value="create_task">Create Task</option>
            <option value="update_task">Update Task</option>
            <option value="delete_task">Delete Task</option>
            <option value="apply_task">Apply Task</option>
            <option value="complete_task">Complete Task</option>
            <option value="update_profile">Update Profile</option>
            <option value="admin_action">Admin Action</option>
          </select>
        </div>

        <!-- 日期範圍 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Date Range</label>
          <select v-model="filters.date_range" @change="handleDateRangeChange" class="admin-input">
            <option value="">All Time</option>
            <option value="today">Today</option>
            <option value="yesterday">Yesterday</option>
            <option value="last_7_days">Last 7 Days</option>
            <option value="last_30_days">Last 30 Days</option>
            <option value="custom">Custom Range</option>
          </select>
        </div>
      </div>

      <!-- 自定義日期範圍 -->
      <div v-if="filters.date_range === 'custom'" class="mt-4 grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
          <input
            v-model="filters.date_from"
            type="datetime-local"
            class="admin-input"
            @change="() => loadLogs()"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
          <input
            v-model="filters.date_to"
            type="datetime-local"
            class="admin-input"
            @change="() => loadLogs()"
          />
        </div>
      </div>
    </div>

    <!-- 統計卡片 -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Logs</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.total_logs || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Today's Logins</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.today_logins || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Failed Logins</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.failed_logins || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Admin Actions</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.admin_actions || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- 日誌列表 -->
    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">{{ getCurrentTabName() }} Logs</h3>
        <div class="text-sm text-gray-500">
          Showing {{ (pagination.current_page - 1) * pagination.per_page + 1 }} to
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }} of
          {{ pagination.total }} results
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <!-- Empty State -->
      <div v-else-if="logs.length === 0" class="text-center py-8">
        <svg
          class="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No logs found</h3>
        <p class="mt-1 text-sm text-gray-500">Try adjusting your search or filter criteria.</p>
      </div>

      <!-- Logs Table -->
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Time</th>
              <th>User</th>
              <th>Action</th>
              <th>Details</th>
              <th>IP Address</th>
              <th>User Agent</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="log in logs" :key="log.id" class="hover:bg-gray-50">
              <td class="text-sm text-gray-900">
                {{ formatDateTime(log.created_at) }}
              </td>
              <td>
                <div v-if="log.user_id" class="text-sm text-gray-900">
                  {{ log.user_name || 'Unknown' }}
                </div>
                <div v-else class="text-sm text-gray-500">System</div>
                <div v-if="log.user_id" class="text-xs text-gray-500">ID: {{ log.user_id }}</div>
              </td>
              <td>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getActionBadgeClass(log.action_type)"
                >
                  {{ formatActionType(log.action_type) }}
                </span>
              </td>
              <td class="text-sm text-gray-900 max-w-xs truncate">
                {{ log.details || 'No details' }}
              </td>
              <td class="text-sm text-gray-500">
                {{ log.ip_address || 'Unknown' }}
              </td>
              <td class="text-sm text-gray-500 max-w-xs truncate">
                {{ log.user_agent || 'Unknown' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div
        v-if="pagination.total > pagination.per_page"
        class="mt-6 flex items-center justify-between"
      >
        <div class="text-sm text-gray-700">
          Page {{ pagination.current_page }} of {{ pagination.last_page }}
        </div>
        <div class="flex space-x-2">
          <button
            @click="changePage(pagination.current_page - 1)"
            :disabled="pagination.current_page <= 1"
            class="admin-button-secondary text-sm"
            :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }"
          >
            Previous
          </button>
          <button
            @click="changePage(pagination.current_page + 1)"
            :disabled="pagination.current_page >= pagination.last_page"
            class="admin-button-secondary text-sm"
            :class="{
              'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page,
            }"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { logApi } from '@/services/api'

// State
const isLoading = ref(false)
const logs = ref<any[]>([])
const activeTab = ref('all')

const stats = ref({
  total_logs: 0,
  today_logins: 0,
  failed_logins: 0,
  admin_actions: 0,
})

const pagination = ref({
  current_page: 1,
  per_page: 25,
  total: 0,
  last_page: 1,
})

const filters = reactive({
  search: '',
  user_id: '',
  action_type: '',
  date_range: '',
  date_from: '',
  date_to: '',
})

const logTabs = ref([
  { key: 'all', name: 'All Logs', count: 0 },
  { key: 'login', name: 'Login Logs', count: 0 },
  { key: 'activity', name: 'Activity Logs', count: 0 },
  { key: 'admin', name: 'Admin Actions', count: 0 },
])

// Methods
const getCurrentTabName = () => {
  const tab = logTabs.value.find((t) => t.key === activeTab.value)
  return tab ? tab.name : 'All'
}

const loadLogs = async (page = 1) => {
  try {
    isLoading.value = true

    const params = {
      page,
      per_page: pagination.value.per_page,
      search: filters.search || undefined,
      user_id: filters.user_id ? parseInt(filters.user_id) : undefined,
      action_type: filters.action_type || undefined,
      date_from: filters.date_from || undefined,
      date_to: filters.date_to || undefined,
      log_type: activeTab.value !== 'all' ? activeTab.value : undefined,
    }

    const response = await logApi.list(params)

    if (response.data.success && response.data.data) {
      const data = response.data.data as any
      logs.value = data.items || []
      pagination.value = data.pagination || pagination.value
      stats.value = data.stats || stats.value

      // Update tab counts
      if (data.tab_counts) {
        logTabs.value.forEach((tab) => {
          tab.count = data.tab_counts[tab.key] || 0
        })
      }
    }
  } catch (error) {
    console.error('Failed to load logs:', error)
    // Mock data for development
    logs.value = [
      {
        id: 1,
        created_at: new Date().toISOString(),
        user_id: 1,
        user_name: 'John Doe',
        action_type: 'login',
        details: 'User logged in successfully',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      },
      {
        id: 2,
        created_at: new Date().toISOString(),
        user_id: 2,
        user_name: 'Jane Smith',
        action_type: 'create_task',
        details: 'Created new task: Help with homework',
        ip_address: '192.168.1.2',
        user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ]
    stats.value = {
      total_logs: 150,
      today_logins: 25,
      failed_logins: 3,
      admin_actions: 8,
    }
  } finally {
    isLoading.value = false
  }
}

const refreshData = () => {
  loadLogs(pagination.value.current_page)
}

const changePage = (page: number) => {
  if (page >= 1 && page <= pagination.value.last_page) {
    loadLogs(page)
  }
}

const exportLogs = () => {
  alert('Export functionality coming soon!')
}

const handleDateRangeChange = () => {
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  switch (filters.date_range) {
    case 'today':
      filters.date_from = today.toISOString().slice(0, 16)
      filters.date_to = now.toISOString().slice(0, 16)
      break
    case 'yesterday':
      const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000)
      filters.date_from = yesterday.toISOString().slice(0, 16)
      filters.date_to = today.toISOString().slice(0, 16)
      break
    case 'last_7_days':
      const week = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000)
      filters.date_from = week.toISOString().slice(0, 16)
      filters.date_to = now.toISOString().slice(0, 16)
      break
    case 'last_30_days':
      const month = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000)
      filters.date_from = month.toISOString().slice(0, 16)
      filters.date_to = now.toISOString().slice(0, 16)
      break
    default:
      filters.date_from = ''
      filters.date_to = ''
  }

  if (filters.date_range !== 'custom') {
    loadLogs(1)
  }
}

// Debounced search
let searchTimeout: number
const debouncedSearch = () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    loadLogs(1)
  }, 500)
}

// Utility functions
const getActionBadgeClass = (actionType: string) => {
  const classes = {
    login: 'bg-green-100 text-green-800',
    logout: 'bg-gray-100 text-gray-800',
    create_task: 'bg-blue-100 text-blue-800',
    update_task: 'bg-yellow-100 text-yellow-800',
    delete_task: 'bg-red-100 text-red-800',
    apply_task: 'bg-purple-100 text-purple-800',
    complete_task: 'bg-green-100 text-green-800',
    update_profile: 'bg-indigo-100 text-indigo-800',
    admin_action: 'bg-red-100 text-red-800',
  }
  return classes[actionType as keyof typeof classes] || 'bg-gray-100 text-gray-800'
}

const formatActionType = (actionType: string) => {
  const formats = {
    login: 'Login',
    logout: 'Logout',
    create_task: 'Create Task',
    update_task: 'Update Task',
    delete_task: 'Delete Task',
    apply_task: 'Apply Task',
    complete_task: 'Complete Task',
    update_profile: 'Update Profile',
    admin_action: 'Admin Action',
  }
  return formats[actionType as keyof typeof formats] || actionType
}

const formatDateTime = (dateString: string | null) => {
  if (!dateString) return 'Unknown'
  return new Date(dateString).toLocaleString()
}

// Watch for tab changes
watch(activeTab, () => {
  loadLogs(1)
})

// Lifecycle
onMounted(() => {
  loadLogs()
})
</script>
