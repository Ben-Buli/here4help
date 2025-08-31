<template>
  <div class="space-y-6">
    <!-- 頁面標題 -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">使用者活動紀錄</h1>
        <p class="text-sm text-gray-600">監控所有使用者的系統活動和操作記錄</p>
      </div>
    </div>

    <!-- 統計卡片 -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6" v-if="stats">
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">總活動數</p>
            <p class="text-2xl font-semibold text-gray-900">{{ stats.total_activities || 0 }}</p>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">活躍使用者</p>
            <p class="text-2xl font-semibold text-gray-900">{{ stats.unique_users || 0 }}</p>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">活動類型</p>
            <p class="text-2xl font-semibold text-gray-900">{{ stats.unique_actions || 0 }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 篩選器 -->
    <div class="bg-white rounded-lg shadow">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">篩選條件</h3>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- 使用者 ID -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">使用者 ID</label>
            <input
              v-model="filters.user_id"
              type="number"
              placeholder="輸入使用者 ID"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 活動類型 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">活動類型</label>
            <input
              v-model="filters.action"
              type="text"
              placeholder="搜尋活動類型"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 操作者類型 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">操作者類型</label>
            <select
              v-model="filters.actor_type"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            >
              <option value="">全部</option>
              <option value="user">使用者</option>
              <option value="admin">管理員</option>
              <option value="system">系統</option>
            </select>
          </div>

          <!-- 搜尋 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">搜尋</label>
            <input
              v-model="filters.search"
              type="text"
              placeholder="搜尋使用者名稱、Email 或原因"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 日期範圍 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">開始日期</label>
            <input
              v-model="filters.date_from"
              type="date"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">結束日期</label>
            <input
              v-model="filters.date_to"
              type="date"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 每頁顯示數量 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">每頁顯示</label>
            <select
              v-model="pagination.per_page"
              @change="handlePerPageChange"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            >
              <option value="15">15 筆</option>
              <option value="25">25 筆</option>
              <option value="50">50 筆</option>
              <option value="100">100 筆</option>
            </select>
          </div>

          <!-- 操作按鈕 -->
          <div class="flex items-end space-x-2">
            <button
              @click="loadActivities"
              class="px-4 py-2 bg-cyan-600 text-white rounded-md hover:bg-cyan-700 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:ring-offset-2"
            >
              搜尋
            </button>
            <button
              @click="resetFilters"
              class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
            >
              重置
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 活動列表 -->
    <div class="bg-white rounded-lg shadow">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">活動紀錄列表</h3>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ID
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                使用者
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                活動類型
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                操作者
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                變更欄位
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                原因
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                IP 位址
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                時間
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="activity in activities" :key="activity.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ activity.id }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-8 w-8">
                    <div class="h-8 w-8 rounded-full bg-cyan-100 flex items-center justify-center">
                      <span class="text-sm font-medium text-cyan-600">
                        {{ getUserInitials(activity.user_name) }}
                      </span>
                    </div>
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-gray-900">{{ activity.user_name || '未知使用者' }}</div>
                    <div class="text-sm text-gray-500">{{ activity.user_email }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                      :class="getActionBadgeClass(activity.action)">
                  {{ getActionText(activity.action) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900">
                  <span v-if="activity.actor_type === 'admin'">
                    {{ activity.admin_full_name || activity.admin_username || '管理員' }}
                  </span>
                  <span v-else-if="activity.actor_type === 'user'">
                    {{ activity.user_name || '使用者' }}
                  </span>
                  <span v-else>
                    系統
                  </span>
                </div>
                <div class="text-sm text-gray-500">{{ activity.actor_type }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <div v-if="activity.field">
                  <div class="font-medium">{{ activity.field }}</div>
                  <div v-if="activity.old_value || activity.new_value" class="text-xs text-gray-500">
                    <span v-if="activity.old_value">舊值: {{ activity.old_value }}</span>
                    <span v-if="activity.old_value && activity.new_value"> → </span>
                    <span v-if="activity.new_value">新值: {{ activity.new_value }}</span>
                  </div>
                </div>
                <span v-else class="text-gray-400">-</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ activity.reason || '-' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ activity.ip || '-' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ formatDate(activity.created_at) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 分頁 -->
      <div class="px-6 py-4 border-t border-gray-200">
        <div class="flex items-center justify-between">
          <div class="flex items-center text-sm text-gray-700">
            <span>顯示第 {{ paginationInfo.from }} 到 {{ paginationInfo.to }} 筆，共 {{ paginationInfo.total }} 筆結果</span>
          </div>
          <div class="flex items-center space-x-2">
            <button
              @click="goToPage(1)"
              :disabled="pagination.current_page === 1"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              第一頁
            </button>
            <button
              @click="goToPage(pagination.current_page - 1)"
              :disabled="pagination.current_page === 1"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              上一頁
            </button>
            <span class="px-3 py-1 text-sm text-gray-700">
              第 {{ pagination.current_page }} 頁，共 {{ pagination.last_page }} 頁
            </span>
            <button
              @click="goToPage(pagination.current_page + 1)"
              :disabled="pagination.current_page === pagination.last_page"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              下一頁
            </button>
            <button
              @click="goToPage(pagination.last_page)"
              :disabled="pagination.current_page === pagination.last_page"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              最後頁
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 載入中 -->
    <div v-if="loading" class="flex justify-center items-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-cyan-600"></div>
      <span class="ml-2 text-gray-600">載入中...</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { userActivityApi } from '@/services/api'

// 響應式資料
const loading = ref(false)
const activities = ref<any[]>([])
const stats = ref<any>(null)

// 分頁資訊
const pagination = reactive({
  current_page: 1,
  per_page: 15,
  total: 0,
  last_page: 1
})

// 篩選條件
const filters = reactive({
  user_id: '',
  action: '',
  actor_type: '',
  date_from: '',
  date_to: '',
  search: '',
  sort_by: 'created_at',
  sort_order: 'desc' as 'asc' | 'desc'
})

// 計算屬性
const paginationInfo = computed(() => {
  const from = (pagination.current_page - 1) * pagination.per_page + 1
  const to = Math.min(pagination.current_page * pagination.per_page, pagination.total)
  return { from, to, total: pagination.total }
})

// 載入活動紀錄
const loadActivities = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.current_page,
      per_page: pagination.per_page,
      ...filters
    }
    
    const response = await userActivityApi.list(params)
    
    if (response.data.success) {
      activities.value = response.data.data.items
      pagination.total = response.data.data.pagination.total
      pagination.last_page = response.data.data.pagination.last_page
      stats.value = response.data.data.stats
    }
  } catch (error) {
    console.error('載入活動紀錄失敗:', error)
  } finally {
    loading.value = false
  }
}

// 分頁處理
const goToPage = (page: number) => {
  pagination.current_page = page
  loadActivities()
}

const handlePerPageChange = () => {
  pagination.current_page = 1
  loadActivities()
}

// 重置篩選條件
const resetFilters = () => {
  Object.assign(filters, {
    user_id: '',
    action: '',
    actor_type: '',
    date_from: '',
    date_to: '',
    search: '',
    sort_by: 'created_at',
    sort_order: 'desc'
  })
  pagination.current_page = 1
  loadActivities()
}

// 工具函數
const getUserInitials = (name: string) => {
  if (!name) return '?'
  return name.split(' ').map(n => n.charAt(0)).join('').toUpperCase().substring(0, 2)
}

const getActionBadgeClass = (action: string) => {
  const actionMap: Record<string, string> = {
    'register': 'bg-green-100 text-green-800',
    'login': 'bg-blue-100 text-blue-800',
    'logout': 'bg-gray-100 text-gray-800',
    'permission_change': 'bg-yellow-100 text-yellow-800',
    'status_change': 'bg-orange-100 text-orange-800',
    'task_completion_reward': 'bg-purple-100 text-purple-800',
    'task_completion_fee': 'bg-red-100 text-red-800',
    'update_profile': 'bg-indigo-100 text-indigo-800'
  }
  return actionMap[action] || 'bg-gray-100 text-gray-800'
}

const getActionText = (action: string) => {
  const actionMap: Record<string, string> = {
    'register': '註冊',
    'login': '登入',
    'logout': '登出',
    'permission_change': '權限變更',
    'status_change': '狀態變更',
    'task_completion_reward': '任務獎勵',
    'task_completion_fee': '任務手續費',
    'update_profile': '更新資料'
  }
  return actionMap[action] || action
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleString('zh-TW')
}

// 初始化
onMounted(() => {
  loadActivities()
})
</script>
