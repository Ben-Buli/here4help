<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Support/Dispute Issues
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
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
          <select v-model="filters.type" @change="() => loadIssues()" class="admin-input">
            <option value="all">All</option>
            <option value="support">Support</option>
            <option value="dispute">Dispute</option>
          </select>
        </div>
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
              <th>ID</th>
              <th>Type</th>
              <th>Status</th>
              <th>Title</th>
              <th>User</th>
              <th>Last Message</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="it in items" :key="it.room_id">
              <td class="text-sm">{{ it.room_id }}</td>
              <td class="text-sm capitalize">{{ it.type }}</td>
              <td>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="statusClass(it.status)">
                  {{ it.status.replace('_', ' ') }}
                </span>
              </td>
              <td class="text-sm">{{ it.title || '-' }}</td>
              <td class="text-sm">{{ it.user_name }} <span class="text-gray-400">({{ it.user_email }})</span></td>
              <td class="text-sm text-gray-500">{{ formatDateTime(it.last_message_at) }}</td>
              <td>
                <div class="flex items-center space-x-2">
                  <!-- 動態顯示 Claim/Chat 按鈕 -->
                  <button 
                    v-if="!it.is_claimed" 
                    @click="claimIssue(it)" 
                    class="text-primary-600 hover:text-primary-900 text-sm font-medium"
                  >
                    Claim
                  </button>
                  <button 
                    v-else-if="it.admin_id === currentAdminId" 
                    @click="openChatRoom(it)" 
                    class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                  >
                    Chat
                  </button>
                  <span 
                    v-else 
                    class="text-gray-400 text-sm cursor-not-allowed"
                  >
                    Claimed
                  </span>
                  
                  <!-- 狀態操作按鈕 -->
                  <button 
                    v-if="it.status === 'in_progress'" 
                    @click="updateStatus(it, 'resolved')" 
                    class="text-green-600 hover:text-green-900 text-sm"
                  >
                    Resolve
                  </button>
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
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { supportApi } from '@/services/api'

const isLoading = ref(false)
const items = ref<any[]>([])
const pagination = ref({ current_page: 1, per_page: 15, total: 0, last_page: 1 })
const filters = reactive({ type: 'all', status: '', search: '' })

// 當前管理員 ID（從 localStorage 或 store 獲取）
const currentAdminId = ref<string | null>(null)

// 初始化當前管理員 ID
const initCurrentAdmin = () => {
  try {
    const adminUser = localStorage.getItem('admin_user')
    if (adminUser) {
      const user = JSON.parse(adminUser)
      currentAdminId.value = String(user.id || user.admin_id || '')
    }
  } catch (e) {
    console.warn('Failed to get current admin ID:', e)
  }
}

const loadIssues = async (page = 1) => {
  try {
    isLoading.value = true
    const res = await supportApi.listIssues({
      page,
      per_page: pagination.value.per_page,
      type: filters.type as any,
      status: (filters.status || undefined) as any,
      search: filters.search || undefined,
    })
    if (res.data.success && res.data.data) {
      items.value = res.data.data.items || []
      pagination.value = res.data.data.pagination || pagination.value
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
    const result = await supportApi.claimIssue(String(it.room_id))
    
    if (result.data.success) {
      // 顯示成功訊息
      console.log('Issue claimed successfully:', result.data.data?.message)
      
      // 重新載入列表以更新狀態
      await refreshData()
    }
  } catch (error: any) {
    console.error('Failed to claim issue:', error)
    
    // 顯示錯誤訊息
    const message = error.response?.data?.message || 'Failed to claim issue'
    alert(`Error: ${message}`)
  } finally {
    isLoading.value = false
  }
}

// 開啟聊天室（僅接手管理員可用）
const openChatRoom = (it: any) => {
  // 跳轉到管理員聊天室列表頁面
  console.log('Opening chat room for:', it.room_id)
  
  // 使用 Vue Router 跳轉到聊天室列表
  window.open(`/support-chat-list?room_id=${it.room_id}`, '_blank')
}

// 更新事件狀態
const updateStatus = async (it: any, newStatus: string) => {
  try {
    isLoading.value = true
    
    // 使用 event_id 而不是 room_id
    const result = await supportApi.updateEventStatus(String(it.event_id), newStatus as any)
    
    if (result.data.success) {
      console.log('Status updated successfully:', result.data.data?.message)
      await refreshData()
    }
  } catch (error: any) {
    console.error('Failed to update status:', error)
    
    const message = error.response?.data?.message || 'Failed to update status'
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


