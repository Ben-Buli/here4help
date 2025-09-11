<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Support Chat List
        </h2>
        <p class="mt-1 text-sm text-gray-500">Manage your assigned support chat rooms</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="refreshData" class="admin-button-secondary" :disabled="isLoading">
          Refresh
        </button>
      </div>
    </div>

    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select v-model="filters.status" @change="() => loadChatRooms()" class="admin-input">
            <option value="">All</option>
            <option value="submitted">Submitted</option>
            <option value="in_progress">In Progress</option>
            <!-- <option value="resolved">Resolved</option> -->
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
          <input v-model="filters.search" type="text" class="admin-input" @input="debouncedSearch" placeholder="Title or customer name..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Per Page</label>
          <select v-model="pagination.per_page" @change="handlePerPageChange" class="admin-input">
            <option value="10">10</option>
            <option value="15">15</option>
            <option value="25">25</option>
            <option value="50">50</option>
          </select>
        </div>
      </div>
    </div>

    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Chat Rooms</h3>
        <div class="text-sm text-gray-500">
          Showing {{ (pagination.current_page - 1) * pagination.per_page + 1 }} to
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }} of
          {{ pagination.total }} results
        </div>
      </div>

      <div v-if="isLoading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <div v-else-if="chatRooms.length === 0" class="text-center py-8 text-gray-500">
        No chat rooms found
      </div>

      <div v-else class="space-y-4">
        <div 
          v-for="room in chatRooms" 
          :key="room.room_id"
          :data-room-id="room.room_id"
          class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow cursor-pointer"
          @click="openChatRoom(room)"
        >
          <div class="flex items-start justify-between">
            <div class="flex items-start space-x-4 flex-1">
              <!-- 客戶頭像 -->
              <div class="flex-shrink-0">
                <img 
                  :src="getAvatarUrl(room.customer?.avatar_url)" 
                  :alt="room.customer?.name"
                  class="h-12 w-12 rounded-full"
                />
              </div>
              
              <!-- 聊天室資訊 -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center space-x-2 mb-1">
                  <h4 class="text-lg font-medium text-gray-900 truncate">
                    {{ room.title || 'Untitled Support Case' }}
                  </h4>
                  <span 
                    class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" 
                    :class="getStatusClass(room.status)"
                  >
                    {{ getStatusDisplay(room.status) }}
                  </span>
                </div>
                
                <p class="text-sm text-gray-600 mb-2">
                  <span class="font-medium">Customer:</span> {{ room.customer?.name }}
                </p>
                
                <div class="text-sm text-gray-500 space-y-1">
                  <p v-if="room.last_message" class="truncate">
                    <span class="font-medium">Last message:</span> {{ room.last_message }}
                  </p>
                  <div class="flex items-center justify-between">
                    <p>
                      <span class="font-medium">Created:</span> {{ formatDateTime(room.created_at) }}
                    </p>
                    <p v-if="room.last_message_time">
                      <span class="font-medium">Last activity:</span> {{ formatDateTime(room.last_message_time) }}
                    </p>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- 未讀數和操作 -->
            <div class="flex items-center space-x-3">
              <div v-if="room.unread_count > 0" class="flex items-center">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                  {{ room.unread_count }} unread
                </span>
              </div>
              
              <div class="flex flex-col items-end space-y-1">
                <button 
                  @click.stop="openChatRoom(room)"
                  class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                >
                  Open Chat
                </button>
                
                <div v-if="room.rating" class="flex items-center">
                  <div class="flex items-center">
                    <span v-for="i in 5" :key="i" class="text-yellow-400">
                      {{ i <= room.rating ? '★' : '☆' }}
                    </span>
                  </div>
                  <span class="ml-1 text-xs text-gray-500">({{ room.rating }}/5)</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 分頁 -->
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
import { useRoute } from 'vue-router'
import { adminSupportApi } from '@/services/api'

interface ChatRoom {
  room_id: string
  event_id: string
  title: string
  status: string
  rating?: number
  review?: string
  created_at: string
  updated_at: string
  closed_at?: string
  last_message?: string
  last_message_time?: string
  unread_count: number
  room_created_at: string
  customer: {
    id: string
    name: string
    avatar_url?: string
  }
}

const route = useRoute()
const isLoading = ref(false)
const chatRooms = ref<ChatRoom[]>([])
const pagination = ref({ current_page: 1, per_page: 15, total: 0, last_page: 1 })
const filters = reactive({ status: '', search: '' })

// 當前管理員 ID
const currentAdminId = ref<string | null>(null)
try {
  const adminUser = localStorage.getItem('admin_user')
  if (adminUser) {
    const parsed = JSON.parse(adminUser)
    currentAdminId.value = String(parsed.id || parsed.admin_id || '')
  }
} catch {}

// 如果有 room_id 參數，自動篩選到該聊天室
const targetRoomId = route.query.room_id as string

const loadChatRooms = async (page = 1) => {
  try {
    isLoading.value = true
    
    // 使用管理員 API
    const params = {
      page,
      per_page: pagination.value.per_page,
      ...(filters.status && { status: filters.status as 'open' | 'in_progress' | 'waiting_customer' | 'resolved' | 'closed' }),
      ...(filters.search && { search: filters.search })
    }
    
    const response = await adminSupportApi.listChatRooms(params)
    
    if (response.data.success && response.data.data) {
      const data = response.data.data
      const rawItems: any[] = data.items || []

      // 後端已經過濾了當前管理員負責的聊天室，直接使用
      // 映射為前端使用結構
      chatRooms.value = rawItems.map((it: any) => ({
        room_id: String(it.room_id),
        event_id: String(it.event_id || ''),
        title: it.title || '-',
        status: it.status || 'open',
        rating: it.rating || undefined,
        review: it.review || undefined,
        created_at: it.event_created_at || it.created_at || '',
        updated_at: it.updated_at || '',
        closed_at: it.closed_at || undefined,
        last_message: it.last_message || '',
        last_message_time: it.last_message_at || it.updated_at || '',
        unread_count: it.unread_count || 0,
        room_created_at: it.created_at || '',
        customer: {
          id: String(it.user_id || ''),
          name: it.user_name || '-',
          avatar_url: it.user_avatar_url || undefined,
        },
      }))
      pagination.value = {
        current_page: data.pagination?.current_page || page,
        per_page: data.pagination?.per_page || pagination.value.per_page,
        total: data.pagination?.total || 0,
        last_page: data.pagination?.last_page || 1
      }
      
      // 如果有目標 room_id，滾動到該項目
      if (targetRoomId) {
        setTimeout(() => {
          const targetElement = document.querySelector(`[data-room-id="${targetRoomId}"]`)
          if (targetElement) {
            targetElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
            targetElement.classList.add('ring-2', 'ring-blue-500')
          }
        }, 100)
      }
    }
  } catch (error) {
    console.error('Failed to load chat rooms:', error)
  } finally {
    isLoading.value = false
  }
}

const refreshData = () => loadChatRooms(pagination.value.current_page)

const changePage = (p: number) => {
  if (p >= 1 && p <= pagination.value.last_page) loadChatRooms(p)
}

const handlePerPageChange = () => {
  pagination.value.current_page = 1
  loadChatRooms(1)
}

let timer: number
const debouncedSearch = () => {
  clearTimeout(timer)
  timer = setTimeout(() => loadChatRooms(1), 400)
}

const openChatRoom = (room: ChatRoom) => {
  // 跳轉到聊天室詳情頁面
  window.location.href = `/support-chat-list/${room.room_id}`
}

const getAvatarUrl = (avatarUrl?: string) => {
  if (!avatarUrl) {
    // 使用管理員預設頭像
    return '/uploads/avatars/default.png'
  }
  
  // 統一處理 uploads/support_chat/ 路徑
  if (avatarUrl.startsWith('uploads/support_chat/')) {
    return avatarUrl
  }
  
  // 處理舊格式：/backend/uploads/avatars/ 或 /backend/uploads/support_chat/
  if (avatarUrl.startsWith('/backend/uploads/')) {
    return avatarUrl.replace('/backend', '')
  }
  
  // 處理舊格式：backend/uploads/avatars/ 或 backend/uploads/support_chat/
  if (avatarUrl.startsWith('backend/uploads/')) {
    return `/${avatarUrl}`
  }
  
  // 如果是完整 URL，直接返回
  if (avatarUrl.startsWith('http')) {
    return avatarUrl
  }
  
  return avatarUrl
}

const getStatusClass = (status: string) => {
  const statusClasses: Record<string, string> = {
    open: 'bg-yellow-100 text-yellow-800',
    in_progress: 'bg-blue-100 text-blue-800',
    waiting_customer: 'bg-purple-100 text-purple-800',
    // resolved: 'bg-green-100 text-green-800', // 管理員後台沒有權限關閉客服事件
    closed: 'bg-gray-200 text-gray-700',
  }
  return statusClasses[status] || 'bg-gray-100 text-gray-800'
}

const getStatusDisplay = (status: string) => {
  const statusDisplays: Record<string, string> = {
    open: 'Open',
    in_progress: 'In Progress',
    waiting_customer: 'Waiting Customer',
    // resolved: 'Resolved', // 管理員後台沒有權限關閉客服事件
    closed: 'Closed'
  }
  return statusDisplays[status] || status
}

const formatDateTime = (dateTimeStr?: string) => {
  if (!dateTimeStr) return ''
  return new Date(dateTimeStr).toLocaleString()
}

onMounted(() => {
  loadChatRooms()
})
</script>

<style scoped>
.admin-card {
  @apply bg-white shadow rounded-lg p-6;
}

.admin-input {
  @apply block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm;
}

.admin-button-secondary {
  @apply inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500;
}
</style>
