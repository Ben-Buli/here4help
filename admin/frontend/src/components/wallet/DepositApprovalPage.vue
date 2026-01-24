<template>
  <div class="space-y-6">
    <!-- 頁面標題與操作 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          User Deposit Approval Management
        </h2>
        <p class="mt-1 text-sm text-gray-500">
          Manage user deposit requests, approve them to automatically issue points
        </p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="refreshData" class="admin-button-secondary" :disabled="loading">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- 篩選器 -->
    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <!-- 狀態篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select v-model="filters.status" @change="loadDeposits" class="admin-input">
            <option value="">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>

        <!-- 開始日期 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
          <input type="date" v-model="filters.fromDate" @change="loadDeposits" class="admin-input" />
        </div>

        <!-- 結束日期 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
          <input type="date" v-model="filters.toDate" @change="loadDeposits" class="admin-input" />
        </div>

        <!-- 每頁顯示筆數 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Per Page</label>
          <select v-model="pagination.per_page" @change="handlePerPageChange" class="admin-input">
            <option value="10">10</option>
            <option value="15">15</option>
            <option value="25">25</option>
            <option value="50">50</option>
            <option value="100">100</option>
          </select>
        </div>
      </div>
    </div>

    <!-- 統計卡片 -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Pending</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ statistics?.pending || 0 }}
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
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Approved Today</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ statistics?.approved_today || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Amount</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ formatPoints(statistics?.total_amount || 0) }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Requests</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ pagination?.total || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- 申請列表 -->
    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Deposit Requests</h3>
        <div class="text-sm text-gray-500">
          Showing {{ (pagination?.current_page - 1) * pagination?.per_page + 1 }} to
          {{ Math.min(pagination?.current_page * pagination?.per_page, pagination?.total) }} of
          {{ pagination?.total }} results
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <!-- Empty State -->
      <div v-else-if="deposits.length === 0" class="text-center py-8">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No deposit requests</h3>
        <p class="mt-1 text-sm text-gray-500">No deposit requests match your criteria.</p>
      </div>

      <!-- Deposits Table -->
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>User</th>
              <th>Amount</th>
              <th>Bank Info</th>
              <th>Created</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="deposit in deposits" :key="deposit.id" class="hover:bg-gray-50">
              <td class="text-sm text-gray-900">#{{ deposit.id }}</td>
              <td>
                <div class="text-sm text-gray-900">{{ deposit.user_name }}</div>
                <div class="text-xs text-gray-500">{{ deposit.user_email }}</div>
              </td>
              <td class="text-sm font-medium text-green-600">
                {{ formatPoints(deposit.amount_points) }} points
              </td>
              <td>
                <div class="text-sm text-gray-900">****{{ deposit.bank_account_last5 }}</div>
                <div v-if="deposit.note" class="text-xs text-gray-500">{{ deposit.note }}</div>
              </td>
              <td class="text-xs text-gray-500">
                <div class="font-medium">{{ formatDateOnly(deposit.created_at) }}</div>
                <div>{{ formatTimeOnly(deposit.created_at) }}</div>
              </td>
              <td>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(deposit.status)">
                  {{ getStatusText(deposit.status) }}
                </span>
              </td>
              <td>
                <div v-if="deposit.status === 'pending'" class="flex flex-row gap-2">
                  <button
                    @click="approveDeposit(deposit)"
                    class="admin-button-primary flex-1 flex items-center justify-center text-xs"
                    :disabled="processing"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                    Approve
                  </button>
                  <button
                    @click="rejectDeposit(deposit)"
                    class="admin-button-secondary flex-1 flex items-center justify-center text-xs bg-red-600 text-white hover:bg-red-700"
                    :disabled="processing"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                    Reject
                  </button>
                </div>
                <div v-else class="text-xs text-gray-500">
                  <div>{{ deposit.admin_name || 'System' }}</div>
                  <div>{{ formatDate(deposit.updated_at) }}</div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="pagination && pagination.total > pagination.per_page" class="mt-6 flex items-center justify-between">
        <div class="text-sm text-gray-700">
          Page {{ pagination.current_page }} of {{ pagination.last_page }}
        </div>
        <div class="flex space-x-2">
          <button @click="changePage(pagination.current_page - 1)" :disabled="pagination.current_page <= 1"
            class="admin-button-secondary text-sm"
            :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }">
            Previous
          </button>
          <button @click="changePage(pagination.current_page + 1)"
            :disabled="pagination.current_page >= pagination.last_page" class="admin-button-secondary text-sm" :class="{
              'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page,
            }">
            Next
          </button>
        </div>
      </div>
    </div>

    <!-- 審核對話框 -->
    <div v-if="showApprovalDialog" class="fixed inset-0 z-[9999] overflow-y-auto">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 transition-opacity" @click="closeApprovalDialog">
          <div class="absolute inset-0 bg-gray-500 opacity-75"></div>
        </div>

        <div
          class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full relative z-10">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="sm:flex sm:items-start">
              <div class="mt-3 text-center sm:mt-0 sm:text-left w-full">
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                  {{ approvalAction === 'approve' ? 'Approve' : 'Reject' }} Deposit Request
                </h3>

                <div class="bg-gray-50 rounded-md p-4 mb-4">
                  <p class="text-sm text-gray-700"><strong>User:</strong> {{ selectedDeposit?.user_name }}</p>
                  <p class="text-sm text-gray-700"><strong>Amount:</strong> {{
                    formatPoints(selectedDeposit?.amount_points || 0) }} points</p>
                  <p class="text-sm text-gray-700"><strong>Bank:</strong> ****{{ selectedDeposit?.bank_account_last5 }}
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Note</label>
                  <textarea v-model="approvalNote" placeholder="Enter approval note..." rows="3"
                    class="admin-input w-full"></textarea>
                </div>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button @click="confirmApproval"
              :class="approvalAction === 'approve' ? 'admin-button-success' : 'admin-button-danger'"
              :disabled="processing" class="w-full sm:w-auto sm:ml-3">
              {{ processing ? 'Processing...' : (approvalAction === 'approve' ? 'Confirm Approve' : 'Confirm Reject') }}
            </button>
            <button @click="closeApprovalDialog" class="admin-button-secondary w-full sm:w-auto">
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 訊息提示 -->
    <div v-if="showMessage" class="fixed top-4 right-4 z-[10000] max-w-sm">
      <div class="rounded-md p-4 shadow-lg"
        :class="message.type === 'success' ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg v-if="message.type === 'success'" class="h-5 w-5 text-green-400" fill="currentColor"
              viewBox="0 0 20 20">
              <path fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clip-rule="evenodd"></path>
            </svg>
            <svg v-else class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                clip-rule="evenodd"></path>
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-medium" :class="message.type === 'success' ? 'text-green-800' : 'text-red-800'">
              {{ message.text }}
            </p>
          </div>
          <div class="ml-auto pl-3">
            <div class="-mx-1.5 -my-1.5">
              <button @click="showMessage = false"
                class="inline-flex rounded-md p-1.5 focus:outline-none focus:ring-2 focus:ring-offset-2"
                :class="message.type === 'success' ? 'text-green-500 hover:bg-green-100 focus:ring-green-600' : 'text-red-500 hover:bg-red-100 focus:ring-red-600'">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { paymentApi } from '@/services/api'

// State
const loading = ref(false)
const processing = ref(false)
const deposits = ref<any[]>([])
const statistics = ref<any>(null)
const pagination = ref({
  current_page: 1,
  per_page: 15,
  total: 0,
  last_page: 1,
})

const filters = reactive({
  status: '',
  fromDate: '',
  toDate: '',
})

// 審核對話框
const showApprovalDialog = ref(false)
const selectedDeposit = ref<any>(null)
const approvalAction = ref('')
const approvalNote = ref('')
const message = ref({ type: '', text: '' })
const showMessage = ref(false)

// 載入儲值申請列表
const loadDeposits = async () => {
  try {
    loading.value = true

    const params = {
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
      status: (filters.status as 'pending' | 'approved' | 'rejected') || undefined,
      from_date: filters.fromDate || undefined,
      to_date: filters.toDate || undefined,
    }

    const res = await paymentApi.requests(params)
    if (res.data.success && res.data.data) {
      const data = res.data.data
      deposits.value = (data.items || []).map((it: any) => ({
        id: it.id,
        user_id: it.user_id,
        user_name: it.user_name,
        user_email: it.user_email,
        amount_points: it.amount_points,
        bank_account_last5: it.bank_account_last5 || '',
        note: it.approver_reply_description || '',
        status: it.status,
        created_at: it.created_at,
        updated_at: it.updated_at,
        admin_name: it.admin_name || null,
      }))
      pagination.value = {
        current_page: data.pagination.current_page,
        per_page: data.pagination.per_page,
        total: data.pagination.total,
        last_page: data.pagination.last_page,
      }
      statistics.value = {
        pending: data.stats?.pending || 0,
        approved_today: data.stats?.approved_today || 0,
        total_amount: data.stats?.total_amount || 0,
      }
    }
  } catch (error) {
    console.error('Failed to load deposits:', error)
  } finally {
    loading.value = false
  }
}

// 刷新數據
const refreshData = () => {
  pagination.value.current_page = 1
  loadDeposits()
}

// 換頁
const changePage = (page: number) => {
  if (page >= 1 && page <= pagination.value.last_page) {
    pagination.value.current_page = page
    loadDeposits()
  }
}

// 每頁顯示筆數改變
const handlePerPageChange = () => {
  pagination.value.current_page = 1
  loadDeposits()
}

// 通過申請
const approveDeposit = (deposit: any) => {
  selectedDeposit.value = deposit
  approvalAction.value = 'approve'
  approvalNote.value = ''
  showApprovalDialog.value = true
}

// 拒絕申請
const rejectDeposit = (deposit: any) => {
  selectedDeposit.value = deposit
  approvalAction.value = 'reject'
  approvalNote.value = ''
  showApprovalDialog.value = true
}

// 確認審核
const confirmApproval = async () => {
  try {
    processing.value = true

    let response
    if (approvalAction.value === 'approve') {
      response = await paymentApi.approve(selectedDeposit.value.id, approvalNote.value)
    } else {
      response = await paymentApi.reject(selectedDeposit.value.id, approvalNote.value)
    }

    if (response.data.success) {
      // 成功提示
      const actionText = approvalAction.value === 'approve' ? 'approved' : 'rejected'
      message.value = { type: 'success', text: `Deposit request ${actionText} successfully!` }
      showMessage.value = true

      // 關閉對話框並刷新列表
      closeApprovalDialog()
      await loadDeposits()

      // 3秒後自動隱藏成功訊息
      setTimeout(() => {
        showMessage.value = false
      }, 3000)
    } else {
      throw new Error(response.data.message || `Failed to ${approvalAction.value} deposit request`)
    }
  } catch (error: any) {
    console.error('Approval failed:', error)

    // 錯誤提示
    const actionText = approvalAction.value === 'approve' ? 'approve' : 'reject'
    const errorMessage = error.response?.data?.message || error.message || `Failed to ${actionText} deposit request`
    message.value = { type: 'error', text: errorMessage }
    showMessage.value = true

    // 5秒後自動隱藏錯誤訊息
    setTimeout(() => {
      showMessage.value = false
    }, 5000)
  } finally {
    processing.value = false
  }
}

// 關閉審核對話框
const closeApprovalDialog = () => {
  showApprovalDialog.value = false
  selectedDeposit.value = null
  approvalAction.value = ''
  approvalNote.value = ''
}

// 工具函數
const formatPoints = (points: number) => {
  return points.toLocaleString()
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleString()
}

const formatDateOnly = (dateString: string) => {
  return new Date(dateString).toLocaleDateString()
}

const formatTimeOnly = (dateString: string) => {
  return new Date(dateString).toLocaleTimeString()
}

const getStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    pending: 'Pending',
    approved: 'Approved',
    rejected: 'Rejected'
  }
  return statusMap[status] || status
}

const getStatusBadgeClass = (status: string) => {
  const classes: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800'
  }
  return classes[status] || 'bg-gray-100 text-gray-800'
}

// 初始化
onMounted(() => {
  loadDeposits()
})
</script>
