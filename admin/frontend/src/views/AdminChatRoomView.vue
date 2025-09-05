<template>
  <div class="admin-chat-room-view h-full flex flex-col">
    <!-- 頁面標題區 -->
    <div class="chat-header bg-gray-50 p-4 border-b border-gray-200 flex-shrink-0">
      <div class="flex items-center justify-between">
        <div class="min-w-0 flex-1">
          <h2 class="text-xl font-bold text-gray-900">Dispute Chat Room</h2>
          <div class="mt-1 text-sm text-gray-600 space-y-1">
            <p><span class="font-medium">Task:</span> {{ chatData?.task?.title || 'Loading...' }}</p>
            <p><span class="font-medium">Dispute ID:</span> {{ disputeId }} | 
               <span class="font-medium">Status:</span> 
               <span :class="getStatusBadgeClass(chatData?.dispute_info?.status || '')" 
                     class="inline-flex px-2 py-1 text-xs font-semibold rounded-full ml-1">
                 {{ getStatusDisplayName(chatData?.dispute_info?.status || '') }}
               </span>
            </p>
          </div>
        </div>
        <button 
          @click="goBack" 
          class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          <Icon name="arrow-left" class="mr-2 h-4 w-4" />
          Back to Disputes
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="flex-1 flex items-center justify-center">
      <div class="text-center">
        <Icon name="loading" class="animate-spin h-8 w-8 mx-auto text-gray-400" />
        <p class="mt-2 text-sm text-gray-500">Loading chat room...</p>
      </div>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="flex-1 flex items-center justify-center">
      <div class="text-center">
        <Icon name="exclamation-triangle" class="h-12 w-12 mx-auto text-red-400" />
        <h3 class="mt-2 text-sm font-medium text-gray-900">Error Loading Chat Room</h3>
        <p class="mt-1 text-sm text-gray-500">{{ error }}</p>
        <button 
          @click="loadChatRoom" 
          class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
        >
          Try Again
        </button>
      </div>
    </div>

    <!-- Chat Content -->
    <div v-else class="flex-1 flex flex-col min-h-0">
      <!-- 參與者資訊 -->
      <div class="bg-white border-b border-gray-200 px-4 py-3 flex-shrink-0">
        <div class="flex items-center space-x-6">
          <div class="flex items-center space-x-3">
            <div class="flex-shrink-0">
              <img 
                :src="getAvatarUrl(chatData?.users?.[chatData?.task?.creator_id]?.avatar_url)" 
                :alt="chatData?.users?.[chatData?.task?.creator_id]?.name"
                class="h-8 w-8 rounded-full"
              />
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">
                {{ chatData?.users?.[chatData?.task?.creator_id]?.name }}
              </p>
              <p class="text-xs text-gray-500">Task Creator</p>
            </div>
          </div>
          
          <div v-if="chatData?.task?.participant_id" class="flex items-center space-x-3">
            <div class="flex-shrink-0">
              <img 
                :src="getAvatarUrl(chatData?.users?.[chatData?.task?.participant_id]?.avatar_url)" 
                :alt="chatData?.users?.[chatData?.task?.participant_id]?.name"
                class="h-8 w-8 rounded-full"
              />
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">
                {{ chatData?.users?.[chatData?.task?.participant_id]?.name }}
              </p>
              <p class="text-xs text-gray-500">Task Participant</p>
            </div>
          </div>

          <div class="flex-1"></div>

          <div class="text-sm text-gray-500">
            <p><span class="font-medium">Reward:</span> {{ chatData?.task?.reward_point }} points</p>
            <p><span class="font-medium">Task Status:</span> {{ chatData?.task?.status?.display_name }}</p>
          </div>
        </div>
      </div>

      <!-- 聊天訊息區域 -->
      <div class="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50" ref="messagesContainer">
        <div v-if="chatData?.messages?.length === 0" class="text-center py-8">
          <Icon name="chat-bubble" class="h-12 w-12 mx-auto text-gray-400" />
          <p class="mt-2 text-sm text-gray-500">No messages in this chat room</p>
        </div>
        
        <div v-else class="space-y-4">
          <AdminMessageBubble
            v-for="message in chatData.messages"
            :key="message.id"
            :message="message"
            :users="chatData.users"
            :task="chatData.task"
            :dispute-submitted-at="chatData.dispute_info?.created_at"
          />
        </div>
      </div>

      <!-- 底部資訊欄（替代輸入區） -->
      <div class="chat-footer-info border-t bg-white flex-shrink-0">
        <div class="flex items-center justify-center py-3 px-4">
          <Icon name="eye" class="text-gray-400 mr-2 h-5 w-5" />
          <span class="text-sm text-gray-600">
            Admin Read-Only Mode - Total {{ chatData?.messages?.length || 0 }} messages
          </span>
          <div class="flex-1"></div>
          <span class="text-xs text-gray-500">
            Viewed by {{ chatData?.meta?.viewed_by_admin }} at {{ formatDateTime(chatData?.meta?.viewed_at) }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { disputeApi } from '@/services/api'
import Icon from '@/components/Icon.vue'
import AdminMessageBubble from '@/components/AdminMessageBubble.vue'

interface ChatMessage {
  id: number
  room_id: string
  from_user_id?: number
  content: string
  kind: 'text' | 'image' | 'resume' | 'system'
  created_at: string
  user_name?: string
  user_avatar?: string
  image_url?: string
  resume_data?: any
}

interface UserInfo {
  id: number
  name: string
  email: string
  avatar_url?: string
}

interface TaskInfo {
  id: string
  title: string
  creator_id: number
  participant_id?: number
  reward_point: number
  status: {
    code: string
    display_name: string
  }
}

interface DisputeInfo {
  id: number
  title: string
  description: string
  status: string
  decision_result?: string
  decision_note?: string
  created_at: string
  updated_at: string
}

interface ChatRoomData {
  chat_room: {
    id: string
    type: string
    task_id: string
    created_at: string
  }
  task: TaskInfo
  messages: ChatMessage[]
  users: Record<number, UserInfo>
  dispute_info: DisputeInfo
  meta: {
    total_messages: number
    viewed_by_admin: string
    viewed_at: string
  }
}

const route = useRoute()
const router = useRouter()

// Data
const disputeId = route.params.disputeId as string
const loading = ref(false)
const error = ref('')
const chatData = ref<ChatRoomData | null>(null)
const messagesContainer = ref<HTMLElement>()

// Methods
const loadChatRoom = async () => {
  loading.value = true
  error.value = ''
  
  try {
    const response = await disputeApi.getChatRoom(disputeId)
    chatData.value = response.data
    
    // 滾動到底部
    await nextTick()
    scrollToBottom()
  } catch (err: any) {
    console.error('Failed to load chat room:', err)
    error.value = err.message || 'Failed to load chat room'
  } finally {
    loading.value = false
  }
}

const scrollToBottom = () => {
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

const goBack = () => {
  router.push('/task-disputes')
}

const getAvatarUrl = (avatarUrl?: string) => {
  if (!avatarUrl) {
    return '/default-avatar.png' // 預設頭像
  }
  
  // 如果是相對路徑，加上 API base URL
  if (avatarUrl.startsWith('backend/')) {
    return `${import.meta.env.VITE_API_BASE_URL}/${avatarUrl}`
  }
  
  return avatarUrl
}

const getStatusBadgeClass = (status: string) => {
  switch (status) {
    case 'submitted':
      return 'bg-yellow-100 text-yellow-800'
    case 'in_progress':
      return 'bg-blue-100 text-blue-800'
    case 'resolved':
      return 'bg-green-100 text-green-800'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

const getStatusDisplayName = (status: string) => {
  switch (status) {
    case 'submitted':
      return 'Submitted'
    case 'in_progress':
      return 'In Progress'
    case 'resolved':
      return 'Resolved'
    default:
      return status
  }
}

const formatDateTime = (dateTimeStr?: string) => {
  if (!dateTimeStr) return ''
  return new Date(dateTimeStr).toLocaleString()
}

// Lifecycle
onMounted(() => {
  loadChatRoom()
})
</script>

<style scoped>
.admin-chat-room-view {
  height: calc(100vh - 4rem); /* 減去導航欄高度 */
}

.chat-messages-container {
  max-height: calc(100vh - 300px); /* 調整最大高度 */
}
</style>
