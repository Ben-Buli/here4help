<template>
  <div class="space-y-6">
    <!-- 頁面標題 -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">User Transactions</h1>
        <p class="text-sm text-gray-600">Monitor all user point transactions and financial activities</p>
      </div>
    </div>

    <!-- 統計卡片 -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6" v-if="stats">
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
            <p class="text-sm font-medium text-gray-500">Total Transactions</p>
            <p class="text-2xl font-semibold text-gray-900">{{ stats.total_transactions || 0 }}</p>
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
            <p class="text-sm font-medium text-gray-500">Active Users</p>
            <p class="text-2xl font-semibold text-gray-900">{{ stats.unique_users || 0 }}</p>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">Total Income</p>
            <p class="text-2xl font-semibold text-green-600">{{ formatPoints(stats.total_income || 0) }}</p>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-red-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
              </svg>
            </div>
          </div>
          <div class="ml-4">
            <p class="text-sm font-medium text-gray-500">Total Expense</p>
            <p class="text-2xl font-semibold text-red-600">{{ formatPoints(stats.total_expense || 0) }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 交易類型統計 -->
    <div class="bg-white rounded-lg shadow" v-if="typeStats && typeStats.length > 0">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Transaction Type Statistics</h3>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div v-for="type in typeStats" :key="type.transaction_type" class="bg-gray-50 rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div>
                <h4 class="text-sm font-medium text-gray-900">{{ getTransactionTypeText(type.transaction_type) }}</h4>
                <p class="text-xs text-gray-500">{{ type.count }} 筆交易</p>
              </div>
              <div class="text-right">
                <p class="text-sm font-medium text-green-600">+{{ formatPoints(type.total_income || 0) }}</p>
                <p class="text-sm font-medium text-red-600">-{{ formatPoints(type.total_expense || 0) }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 篩選器 -->
    <div class="bg-white rounded-lg shadow">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Filter Conditions</h3>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- 使用者 ID -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">User ID</label>
            <input
              v-model="filters.user_id"
              type="number"
              placeholder="Enter User ID"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 交易類型 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Transaction Type</label>
            <select
              v-model="filters.transaction_type"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            >
              <option value="">All</option>
              <option value="earn">Income</option>
              <option value="spend">Expense</option>
              <option value="deposit">Deposit</option>
              <option value="fee">Fee</option>
              <option value="refund">Refund</option>
              <option value="adjustment">Adjustment</option>
            </select>
          </div>

          <!-- 搜尋 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              v-model="filters.search"
              type="text"
              placeholder="Search user name, email or description"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 每頁顯示數量 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Per Page</label>
            <select
              v-model="pagination.per_page"
              @change="handlePerPageChange"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            >
              <option value="15">15 items</option>
              <option value="25">25 items</option>
              <option value="50">50 items</option>
              <option value="100">100 items</option>
            </select>
          </div>

          <!-- 日期範圍 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
            <input
              v-model="filters.date_from"
              type="date"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
            <input
              v-model="filters.date_to"
              type="date"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <!-- 操作按鈕 -->
          <div class="flex items-end space-x-2">
            <button
              @click="loadTransactions"
              class="px-4 py-2 bg-cyan-600 text-white rounded-md hover:bg-cyan-700 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:ring-offset-2"
            >
              Search
            </button>
            <button
              @click="resetFilters"
              class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
            >
              Reset
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 交易列表 -->
    <div class="bg-white rounded-lg shadow">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Transaction Records</h3>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ID
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                User
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Transaction Type
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Amount
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Description
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Related Task
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Time
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="transaction in transactions" :key="transaction.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ transaction.id }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-8 w-8">
                    <div class="h-8 w-8 rounded-full bg-cyan-100 flex items-center justify-center">
                      <span class="text-sm font-medium text-cyan-600">
                        {{ getUserInitials(transaction.user_name) }}
                      </span>
                    </div>
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-gray-900">{{ transaction.user_name || 'Unknown User' }}</div>
                    <div class="text-sm text-gray-500">{{ transaction.user_email }}</div>
                    <div class="text-xs text-gray-400">Balance: {{ formatPoints(transaction.current_balance) }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                      :class="getTransactionTypeBadgeClass(transaction.transaction_type)">
                  {{ getTransactionTypeText(transaction.transaction_type) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="text-sm font-medium"
                      :class="transaction.amount > 0 ? 'text-green-600' : 'text-red-600'">
                  {{ transaction.amount > 0 ? '+' : '' }}{{ formatPoints(transaction.amount) }}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-900">
                <div class="max-w-xs truncate" :title="transaction.description">
                  {{ transaction.description }}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <span v-if="transaction.related_task_id" class="text-cyan-600 hover:text-cyan-800 cursor-pointer">
                  {{ transaction.related_task_id }}
                </span>
                <span v-else class="text-gray-400">-</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                      :class="getStatusBadgeClass(transaction.status)">
                  {{ getStatusText(transaction.status) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ formatDate(transaction.created_at) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 分頁 -->
      <div class="px-6 py-4 border-t border-gray-200">
        <div class="flex items-center justify-between">
          <div class="flex items-center text-sm text-gray-700">
            <span>Showing {{ paginationInfo.from }} to {{ paginationInfo.to }} of {{ paginationInfo.total }} results</span>
          </div>
          <div class="flex items-center space-x-2">
            <button
              @click="goToPage(1)"
              :disabled="pagination.current_page === 1"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              First
            </button>
            <button
              @click="goToPage(pagination.current_page - 1)"
              :disabled="pagination.current_page === 1"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>
            <span class="px-3 py-1 text-sm text-gray-700">
              Page {{ pagination.current_page }} of {{ pagination.last_page }}
            </span>
            <button
              @click="goToPage(pagination.current_page + 1)"
              :disabled="pagination.current_page === pagination.last_page"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
            <button
              @click="goToPage(pagination.last_page)"
              :disabled="pagination.current_page === pagination.last_page"
              class="px-3 py-1 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Last
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 載入中 -->
    <div v-if="loading" class="flex justify-center items-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-cyan-600"></div>
      <span class="ml-2 text-gray-600">Loading...</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { userTransactionApi } from '@/services/api'

// 響應式資料
const loading = ref(false)
const transactions = ref<any[]>([])
const stats = ref<any>(null)
const typeStats = ref<any[]>([])

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
  transaction_type: '',
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

// 載入交易紀錄
const loadTransactions = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.current_page,
      per_page: pagination.per_page,
      ...filters
    }
    
    const response = await userTransactionApi.list(params)
    
    if (response.data && response.data.success && response.data.data) {
      transactions.value = response.data.data.items || []
      if (response.data.data.pagination) {
        pagination.total = response.data.data.pagination.total
        pagination.last_page = response.data.data.pagination.last_page
      }
      stats.value = response.data.data.stats || null
      typeStats.value = response.data.data.type_stats || []
    }
  } catch (error) {
    console.error('Failed to load transactions:', error)
  } finally {
    loading.value = false
  }
}

// 分頁處理
const goToPage = (page: number) => {
  pagination.current_page = page
  loadTransactions()
}

const handlePerPageChange = () => {
  pagination.current_page = 1
  loadTransactions()
}

// 重置篩選條件
const resetFilters = () => {
  Object.assign(filters, {
    user_id: '',
    transaction_type: '',
    date_from: '',
    date_to: '',
    search: '',
    sort_by: 'created_at',
    sort_order: 'desc'
  })
  pagination.current_page = 1
  loadTransactions()
}

// 工具函數
const getUserInitials = (name: string) => {
  if (!name) return '?'
  return name.split(' ').map(n => n.charAt(0)).join('').toUpperCase().substring(0, 2)
}

const getTransactionTypeBadgeClass = (type: string) => {
  const typeMap: Record<string, string> = {
    'earn': 'bg-green-100 text-green-800',
    'spend': 'bg-red-100 text-red-800',
    'deposit': 'bg-blue-100 text-blue-800',
    'fee': 'bg-orange-100 text-orange-800',
    'refund': 'bg-purple-100 text-purple-800',
    'adjustment': 'bg-gray-100 text-gray-800'
  }
  return typeMap[type] || 'bg-gray-100 text-gray-800'
}

const getTransactionTypeText = (type: string) => {
  const typeMap: Record<string, string> = {
    'earn': 'Income',
    'spend': 'Expense',
    'deposit': 'Deposit',
    'fee': 'Fee',
    'refund': 'Refund',
    'adjustment': 'Adjustment'
  }
  return typeMap[type] || type
}

const getStatusBadgeClass = (status: string) => {
  const statusMap: Record<string, string> = {
    'completed': 'bg-green-100 text-green-800',
    'pending': 'bg-yellow-100 text-yellow-800',
    'cancelled': 'bg-red-100 text-red-800'
  }
  return statusMap[status] || 'bg-gray-100 text-gray-800'
}

const getStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    'completed': 'Completed',
    'pending': 'Pending',
    'cancelled': 'Cancelled'
  }
  return statusMap[status] || status
}

const formatPoints = (points: number) => {
  return points.toLocaleString() + ' pts'
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleString('zh-TW')
}

// 初始化
onMounted(() => {
  loadTransactions()
})
</script>
