<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Support
        </h2>
        <p class="mt-1 text-sm text-gray-500">Manage support and dispute chat rooms</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="refreshData" class="admin-button-secondary" :disabled="isLoading">
          Refresh
        </button>
      </div>
    </div>

    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <!-- <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
          <select v-model="filters.type" @change="() => loadIssues()" class="admin-input">
            <option value="all">All</option>
            <option value="support">Support</option>
            <option value="dispute">Dispute</option>
          </select>
        </div> -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select v-model="filters.status" @change="() => loadIssues()" class="admin-input">
            <option value="">All</option>
            <option value="submitted">Submitted</option>
            <option value="in_progress">In Progress</option>
            <option value="resolved">Resolved</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
          <input v-model="filters.search" type="text" class="admin-input" @input="debouncedSearch" placeholder="Title or user..." />
        </div>
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

    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Issues</h3>
        <div class="text-sm text-gray-500">
          Showing {{ (pagination.current_page - 1) * pagination.per_page + 1 }} to
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }} of
          {{ pagination.total }} results
        </div>
      </div>

      <div v-if="isLoading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <div v-else-if="items.length === 0" class="text-center py-8 text-gray-500">
        No issues found
      </div>

      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <!-- <th>Room ID</th> -->
              <th>Title</th>
              <th>User</th>
              <th>Claimed by</th>
              <th>Timestamp</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="it in items" :key="it.room_id">
              <!-- <td class="text-sm">{{ it.room_id }}</td> -->
          
              <td class="text-sm"><span class="block">{{ it.title || '-' }}</span><span class="block text-gray-400 text-xs">#{{ it.room_id }}</span></td>
              <td class="text-sm">{{ it.user_name }} <br/><small class="text-gray-400">({{ it.user_email }})</small></td>
              <td class="text-sm">{{ it.admin_name || '-' }} <br/><small class="text-gray-400">({{ it.admin_email || 'Not Assigned' }})</small></td>
              <td class="text-sm text-gray-500">{{ formatDateTime(it.last_message_at) }}</td>
              <td>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="statusClass(it.status)">
                  {{ it.status.replace('_', ' ') }}
                </span>
              </td>
              <td>
                <div class="flex items-center space-x-2">
                  <!-- 動態顯示 Claim/Chat 按鈕 -->
                  <button 
                    v-if="!it.admin_id && it.status !== 'resolved'" 
                    @click="claimIssue(it)" 
                    class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors duration-200"
                    :disabled="isLoading"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                    </svg>
                    Claim
                  </button>
                  <!-- 動態顯示聊天按鈕 -->
                  <button 
                    v-else-if="isAssignedToMe(it) && it.status !== 'resolved'" 
                    @click="openChatRoom(it)" 
                    class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors duration-200"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                    </svg>
                    Chat
                  </button>
                  
                  <!-- Issue 詳情按鈕（開啟 modal） -->
                  <button 
                    @click="openIssue(it)" 
                    class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-300 transition-colors duration-200"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    Issue
                  </button>
                  
                  
                  <!-- 狀態操作按鈕 -->
                  <!-- <button 
                    v-if="it.status === 'in_progress'" 
                    @click="updateStatus(it, 'resolved')" 
                    class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors duration-200"
                    :disabled="isLoading"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                    Resolve
                  </button> -->
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="pagination.total > 0" class="mt-6 flex items-center justify-between">
        <div class="text-sm text-gray-700">
          Showing {{ (pagination.current_page - 1) * pagination.per_page + 1 }} to
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }} of
          {{ pagination.total }} results
          <span class="text-gray-500">({{ pagination.per_page }} per page)</span>
        </div>
        <div class="flex items-center space-x-4">
          <div class="flex items-center space-x-2">
            <button @click="changePage(1)" :disabled="pagination.current_page <= 1" class="admin-button-secondary text-sm px-2 py-1" :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }">First</button>
            <button @click="changePage(pagination.current_page - 1)" :disabled="pagination.current_page <= 1" class="admin-button-secondary text-sm px-2 py-1" :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }">Previous</button>
            <span class="text-sm text-gray-700 px-2">Page {{ pagination.current_page }} of {{ pagination.last_page }}</span>
            <button @click="changePage(pagination.current_page + 1)" :disabled="pagination.current_page >= pagination.last_page" class="admin-button-secondary text-sm px-2 py-1" :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page }">Next</button>
            <button @click="changePage(pagination.last_page)" :disabled="pagination.current_page >= pagination.last_page" class="admin-button-secondary text-sm px-2 py-1" :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page }">Last</button>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Issue Detail Modal -->
  <div v-if="showIssueModal" class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="fixed inset-0 bg-black/20 backdrop-blur-sm" @click="closeIssue"></div>
    <div class="relative bg-white rounded-lg shadow-xl w-full max-w-2xl mx-4 z-10">
      <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
        <h3 class="text-lg font-medium text-gray-900">Issue Detail</h3>
        <button @click="closeIssue" class="text-gray-400 hover:text-gray-600 focus:outline-none">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <div class="px-6 py-5 space-y-4">
        <div>
          <div class="text-sm text-gray-500">Title</div>
          <div class="text-sm text-gray-900 break-words break-all overflow-hidden">{{ currentIssue?.title || '-' }}</div>
        </div>
        <div>
          <div class="text-sm text-gray-500">Description</div>
          <div class="text-sm text-gray-900 whitespace-pre-wrap break-words break-all overflow-hidden">{{ currentIssue?.description || '-' }}</div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <div class="text-sm text-gray-500">User ID</div>
            <div class="text-sm text-gray-900">{{ currentIssue?.user_id || '-' }}</div>
          </div>
          <div>
            <div class="text-sm text-gray-500">User Name</div>
            <div class="text-sm text-gray-900">{{ currentIssue?.user_name || '-' }}</div>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <div class="text-sm text-gray-500">Status</div>
            <div class="text-xs inline-flex px-2 py-1 rounded-full" :class="statusClass(currentIssue?.status || '')">
              {{ (currentIssue?.status || '').replace('_', ' ') || '-' }}
            </div>
          </div>
          <div>
            <div class="text-sm text-gray-500">Created At</div>
            <div class="text-sm text-gray-900">{{ formatDateTime(currentIssue?.created_at) }}</div>
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-200 flex justify-end">
        <button @click="closeIssue" class="admin-button-secondary">Close</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { adminSupportApi } from '@/services/api'

const isLoading = ref(false)
const items = ref<any[]>([])
const pagination = ref({ current_page: 1, per_page: 15, total: 0, last_page: 1 })
const filters = reactive({ type: 'all', status: '', search: '' })

// 當前管理員 ID（從 localStorage 或 store 獲取）
const currentAdminId = ref<number | null>(null)

// Issue 詳情 modal 狀態
const showIssueModal = ref(false)
const currentIssue = ref<any | null>(null)

// 初始化當前管理員 ID
const initCurrentAdmin = () => {
  try {
    const adminUser = localStorage.getItem('admin_user')
    if (adminUser) {
      const user = JSON.parse(adminUser)
      const idNum = Number(user.id || user.admin_id)
      currentAdminId.value = Number.isFinite(idNum) ? idNum : null
    }
  } catch (e) {
    console.warn('Failed to get current admin ID:', e)
  }
}

const loadIssues = async (page = 1) => {
  try {
    isLoading.value = true
    
    const params = {
      page,
      per_page: pagination.value.per_page,
      type: filters.type !== 'all' ? filters.type as 'support' | 'dispute' : undefined,
      status: filters.status ? filters.status as 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed' : undefined,
      search: filters.search || undefined,
    }
    
    const response = await adminSupportApi.listIssues(params)
    
    if (response.data.success && response.data.data) {
      // 直接使用後端返回的數據格式
      console.log('API Response:', response.data.data.items) // 調試用
      items.value = response.data.data.items || []
      
      // 更新分頁信息
      if (response.data.data.pagination) {
        pagination.value = response.data.data.pagination
      }
    }
  } catch (e) {
    console.error('Load issues failed:', e)
  } finally {
    isLoading.value = false
  }
}

const refreshData = () => loadIssues(pagination.value.current_page)
const changePage = (p: number) => {
  if (p >= 1 && p <= pagination.value.last_page) loadIssues(p)
}

const handlePerPageChange = () => {
  pagination.value.current_page = 1
  loadIssues(1)
}

let timer: number
const debouncedSearch = () => {
  clearTimeout(timer)
  timer = setTimeout(() => loadIssues(1), 400)
}

// 管理員接手客服事件
const claimIssue = async (it: any) => {
  try {
    isLoading.value = true
    
    const response = await adminSupportApi.claimIssue(String(it.room_id))
    
    if (response.data.success) {
      console.log('Issue claimed successfully:', response.data.data?.message)

      // 無論後端提供什麼 redirect，都統一導向管理員的 Support Chat List 頁面
      const roomId = it.room_id
      if (roomId) {
        window.location.href = `/admin/support-chat-list?room_id=${roomId}`
        return
      }

      await refreshData()
    } else {
      throw new Error(response.data.message || 'Failed to claim issue')
    }
  } catch (error: any) {
    console.error('Failed to claim issue:', error)
    
    // 顯示錯誤訊息
    const message = error.response?.data?.message || error.message || 'Failed to claim issue'
    alert(`Error: ${message}`)
  } finally {
    isLoading.value = false
  }
}

// 開啟聊天室（僅接手管理員可用）
const openChatRoom = (it: any) => {
  // 跳轉到聊天室詳情頁面
  console.log('Opening chat room for:', it.room_id)
  
  // 跳轉到聊天室詳情頁面
  window.location.href = `/support-chat-list/${it.room_id}`
}

// 更新事件狀態
const updateStatus = async (it: any, newStatus: string) => {
  try {
    isLoading.value = true
    
    const response = await adminSupportApi.updateStatus(String(it.room_id), newStatus as 'submitted' | 'in_progress' | 'resolved')
    
    if (response.data.success) {
      console.log('Status updated successfully:', response.data.data?.message)
      await refreshData()
    } else {
      throw new Error(response.data.message || 'Failed to update status')
    }
  } catch (error: any) {
    console.error('Failed to update status:', error)
    
    const message = error.response?.data?.message || error.message || 'Failed to update status'
    alert(`Error: ${message}`)
  } finally {
    isLoading.value = false
  }
}

// 向後相容的舊方法（標記為 deprecated）
/** @deprecated 使用 claimIssue 替代 */
const accept = async (it: any) => {
  await claimIssue(it)
}

// 僅當前管理員被指派時可聊天
const isAssignedToMe = (it: any): boolean => {
  if (currentAdminId.value == null) return false
  return Number(it.admin_id) === currentAdminId.value
}

// 開啟 Issue 詳情 modal
const openIssue = (it: any) => {
  console.log('Issue data:', it) // 調試用
  currentIssue.value = it
  showIssueModal.value = true
}

const closeIssue = () => {
  showIssueModal.value = false
  currentIssue.value = null
}

const statusClass = (s: string) => {
  const map: Record<string, string> = {
    submitted: 'bg-yellow-100 text-yellow-800',
    in_progress: 'bg-blue-100 text-blue-800',
    resolved: 'bg-green-100 text-green-800',
    // 向後相容的舊狀態
    open: 'bg-yellow-100 text-yellow-800',
    waiting_customer: 'bg-purple-100 text-purple-800',
    closed: 'bg-gray-100 text-gray-800',
  }
  return map[s] || 'bg-gray-100 text-gray-800'
}

const formatDateTime = (d?: string) => {
  if (!d) return '-'
  const date = new Date(d)
  return `${date.toLocaleDateString()} ${date.toLocaleTimeString()}`
}

onMounted(() => {
  initCurrentAdmin()
  loadIssues()
})
</script>

