<template>
  <div class="admin-chat-room-view h-full flex flex-col">
    <!-- 頁面標題區 -->
    <div class="chat-header bg-gray-50 p-2 border-b border-gray-200 flex-shrink-0">
      <div class="flex items-center justify-between">
        <div class="min-w-0 flex-1">
          <div class="mt-1 text-sm text-gray-600">
            <p><span class="font-medium">Task Title:</span> {{ chatData?.task?.title || 'Loading...' }}</p>
            <p><span class="font-medium">Dispute ID:</span> {{ chatData?.task?.id }} | 
               <span class="font-medium">Status:</span> 
               <span :class="getStatusBadgeClass(chatData?.dispute_info?.status || '')" 
                     class="inline-flex px-2 py-1 text-xs font-semibold rounded-full ml-1">
                 {{ getStatusDisplayName(chatData?.dispute_info?.status || '') }}
               </span>
            </p>
          </div>
        </div>
        <div class="flex space-x-3">
          <button 
            @click="goBack" 
            class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            <Icon name="arrow-left" class="mr-2 h-4 w-4" />
            Back to Disputes
          </button>
          
          <button 
            v-if="chatData?.dispute_info && chatData.dispute_info.status !== 'resolved'"
            @click="openReviewDialog" 
            class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            <Icon name="gavel" class="mr-2 h-4 w-4" />
            Review
          </button>
        </div>
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
          <!-- Creator -->
          <div class="flex items-center space-x-3">
            <div class="flex-shrink-0">
              <template v-if="!shouldShowFallbackAvatar('creator', chatData?.member_status?.creator?.avatar_url)">
                <img 
                  :src="resolveAvatarUrl(chatData?.member_status?.creator?.avatar_url) || ''" 
                  :alt="chatData?.member_status?.creator?.name"
                  class="h-8 w-8 rounded-full"
                  :class="{ 'opacity-50': !chatData?.member_status?.creator?.is_active }"
                  @error="handleAvatarError('creator')"
                />
              </template>
              <div
                v-else
                class="h-8 w-8 rounded-full flex items-center justify-center text-white"
                :style="{ backgroundColor: getAvatarColor(chatData?.member_status?.creator?.name) }"
                :class="{ 'opacity-50': !chatData?.member_status?.creator?.is_active }"
              >
                <Icon name="user" class="h-4 w-4" />
              </div>
            </div>
            <div>
              <p class="text-sm font-medium" :class="getMemberTextClass(chatData?.member_status?.creator?.is_active)">
                {{ chatData?.member_status?.creator?.name }}
                <span class="text-gray-400 ml-1">({{ chatData?.member_status?.creator?.user_id }})</span>
              </p>
              <p class="text-xs" :class="getMemberRoleClass(chatData?.member_status?.creator?.is_active)">
                {{ chatData?.member_status?.creator?.role }}
                <span v-if="chatData?.member_status?.creator?.is_disputer" class="ml-1 text-cyan-600">(Disputer)</span>
                <span v-if="!chatData?.member_status?.creator?.is_active" class="ml-1 text-amber-600">(Removed)</span>
              </p>
            </div>
          </div>
          
          <!-- Participant -->
          <div v-if="chatData?.member_status?.participant?.user_id" class="flex items-center space-x-3">
            <div class="flex-shrink-0">
              <template v-if="!shouldShowFallbackAvatar('participant', chatData?.member_status?.participant?.avatar_url)">
                <img 
                  :src="resolveAvatarUrl(chatData?.member_status?.participant?.avatar_url) || ''" 
                  :alt="chatData?.member_status?.participant?.name"
                  class="h-8 w-8 rounded-full"
                  :class="{ 'opacity-50': !chatData?.member_status?.participant?.is_active }"
                  @error="handleAvatarError('participant')"
                />
              </template>
              <div
                v-else
                class="h-8 w-8 rounded-full flex items-center justify-center text-white"
                :style="{ backgroundColor: getAvatarColor(chatData?.member_status?.participant?.name) }"
                :class="{ 'opacity-50': !chatData?.member_status?.participant?.is_active }"
              >
                <Icon name="user" class="h-4 w-4" />
              </div>
            </div>
            <div>
              <p class="text-sm font-medium" :class="getMemberTextClass(chatData?.member_status?.participant?.is_active)">
                {{ chatData?.member_status?.participant?.name }}
                <span class="text-gray-400 ml-1">({{ chatData?.member_status?.participant?.user_id }})</span>
              </p>
              <p class="text-xs" :class="getMemberRoleClass(chatData?.member_status?.participant?.is_active)">
                {{ chatData?.member_status?.participant?.role }}
                <span v-if="chatData?.member_status?.participant?.is_disputer" class="ml-1 text-cyan-600">(Disputer)</span>
                <span v-if="!chatData?.member_status?.participant?.is_active" class="ml-1 text-amber-600">(Removed)</span>
              </p>
            </div>
          </div>

          <div class="flex-1"></div>

          <div class="text-sm text-gray-500 text-right">
            <p><span class="font-medium">Reward:&emsp;</span> {{ chatData?.task?.reward_point }} points</p>
            <p><span class="font-medium">Task Status:&emsp;</span> 
              <span :class="getStatusClass(chatData?.task?.status?.code, 'task')">
                {{ chatData?.task?.status?.display_name }}
              </span>
            </p>
            <p v-if="chatData?.member_status?.participant?.user_id">
              <span class="font-medium">Tasker Status:&emsp;</span> 
              <span :class="getStatusClass(chatData?.member_status?.participant?.application_status, 'applicant')">
                {{ getApplicantStatusDisplay(chatData?.member_status?.participant?.application_status)?.charAt(0).toUpperCase() + getApplicantStatusDisplay(chatData?.member_status?.participant?.application_status)?.slice(1) }}
              </span>
            </p>
          </div>
        </div>
      </div>

      <!-- 聊天訊息區域 -->
      <div class="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50" ref="messagesContainer">
        <div v-if="chatData && chatData.messages && chatData.messages.length > 0" class="space-y-4">
          <AdminMessageBubble
            v-for="message in chatData.messages"
            :key="message.id"
            :message="message"
            :users="chatData.users"
            :task="chatData.task"
            :chat-room="chatData.chat_room"
            :dispute-submitted-at="chatData.dispute_info?.created_at"
            :right-side-user-id="chatData.dispute_info?.applicant_user_id ? Number(chatData.dispute_info?.applicant_user_id) : undefined"
            :admin-id="chatData.meta?.admin_id"
          />
        </div>
        
        <div v-else class="text-center py-8">
          <Icon name="chat-bubble" class="h-12 w-12 mx-auto text-gray-400" />
          <p class="mt-2 text-sm text-gray-500">No messages in this chat room</p>
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
    
    <!-- Dispute Operation Dialog -->
    <DisputeOperationDialog
      v-if="showReviewDialog"
      :dispute="disputeForDialog"
      @close="showReviewDialog = false"
      @resolved="handleDisputeResolved"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick, computed, reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { disputeApi } from '@/services/api'
import Icon from '@/components/Icon.vue'
import AdminMessageBubble from '@/components/AdminMessageBubble.vue'
import DisputeOperationDialog from '@/components/DisputeOperationDialog.vue'
import { getImageUrl } from '@/config/api'

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
  applicant_user_id?: number
  title: string
  description: string
  status: string
  decision_result?: string
  decision_note?: string
  created_at: string
  updated_at: string
}

interface MemberStatus {
  creator: {
    user_id: number
    name: string
    avatar_url?: string
    is_active: boolean
    role: string
    is_disputer: boolean
  }
  participant: {
    user_id: number
    name: string
    avatar_url?: string
    is_active: boolean
    role: string
    is_disputer: boolean
    application_status?: string
  }
}

interface ChatRoomData {
  chat_room: {
    id: string
    type: string
    task_id: string
    creator_id: number
    participant_id: number
    created_at: string
  }
  task: TaskInfo
  member_status: MemberStatus
  messages: ChatMessage[]
  users: Record<number, UserInfo>
  dispute_info: DisputeInfo
  meta: {
    total_messages: number
    viewed_by_admin: string
    admin_id: number
    viewed_at: string
  }
}

const route = useRoute()
const router = useRouter()

// Data
const taskId = route.params.taskId as string
const loading = ref(false)
const error = ref('')
const chatData = ref<ChatRoomData | null>(null)
const messagesContainer = ref<HTMLElement>()

// Review Dialog State
const showReviewDialog = ref(false)

// Computed
const disputeForDialog = computed(() => {
  if (!chatData.value?.dispute_info) return null
  
  return {
    id: chatData.value.dispute_info.id,
    task_id: taskId,
    dispute_title: chatData.value.dispute_info.title || 'Task Dispute',
    description: chatData.value.dispute_info.description || '',
    status: chatData.value.dispute_info.status || 'submitted',
    created_at: chatData.value.dispute_info.created_at || '',
    task: {
      title: chatData.value.task?.title || 'Unknown Task',
      reward_point: chatData.value.task?.reward_point || 0,
    },
    submitter: {
      name: 'Unknown User', // 從 dispute_info 中無法直接獲取，使用預設值
    }
  }
})

// Methods
const loadChatRoom = async () => {
  loading.value = true
  error.value = ''
  
  try {
    const response = await disputeApi.getChatRoomByTask(taskId)
    const body: any = response.data
    const data = body?.data ?? body
    chatData.value = data
    
    await nextTick()
    scrollToBottom()
  } catch (err: any) {
    console.error('Failed to load chat room:', err)
    error.value = err?.response?.data?.message || err.message || 'Failed to load chat room'
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

const openReviewDialog = () => {
  showReviewDialog.value = true
}

const handleDisputeResolved = async () => {
  showReviewDialog.value = false
  
  // 重新加載聊天室數據以獲取最新狀態
  await loadChatRoom()
  
  // 可以添加成功提示
  console.log('Dispute resolved successfully')
}

const avatarFallbackMap = reactive<Record<string, boolean>>({})

const normalizeAvatarPath = (raw?: string): string | null => {
  if (!raw) return null
  let path = raw.trim()
  if (!path) return null

  // 若為完整 URL 直接使用
  if (/^https?:\/\//i.test(path)) {
    return path
  }

  // 去除 domain 或重複的 /backend
  path = path.replace(/^https?:\/\/[^/]+/i, '')
  path = path.replace(/^\/+/, '')
  path = path.replace(/(^|\/)backend\//g, '$1')

  if (path.startsWith('uploads/')) {
    path = path.replace(/^uploads\//, '')
  }

  const match = path.match(/uploads\/(.+)$/)
  if (match) {
    path = match[1]
  }

  return path || null
}

const resolveAvatarUrl = (avatarUrl?: string): string | null => {
  const normalized = normalizeAvatarPath(avatarUrl)
  if (!normalized) return null

  if (/^https?:\/\//i.test(normalized)) {
    return normalized
  }

  const cleanPath = normalized.replace(/^uploads\//, '')
  return getImageUrl(cleanPath)
}

const handleAvatarError = (key: string) => {
  avatarFallbackMap[key] = true
}

const shouldShowFallbackAvatar = (key: string, avatarUrl?: string) => {
  if (avatarFallbackMap[key]) return true
  return !resolveAvatarUrl(avatarUrl)
}

const avatarColors = [
  '#1E40AF', '#9333EA', '#059669', '#DC2626', '#2563EB',
  '#F59E0B', '#10B981', '#EC4899', '#0EA5E9', '#F97316'
]

const getAvatarColor = (name?: string) => {
  const base = name && name.trim() ? name.trim().toLowerCase() : 'user'
  let hash = 0
  for (let i = 0; i < base.length; i += 1) {
    hash = (hash << 5) - hash + base.charCodeAt(i)
    hash |= 0
  }
  const index = Math.abs(hash) % avatarColors.length
  return avatarColors[index]
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

const getMemberTextClass = (isActive?: boolean) => {
  return isActive ? 'text-gray-900' : 'text-gray-500'
}

const getMemberRoleClass = (isActive?: boolean) => {
  return isActive ? 'text-gray-500' : 'text-gray-400'
}

const getStatusClass = (status?: string, type: 'task' | 'applicant' = 'task') => {
  if (type === 'task') {
    // Task Status 顏色
    switch (status) {
      case 'open':
        return 'text-blue-600'
      case 'in_progress':
        return 'text-yellow-600'
      case 'pending_confirmation':
        return 'text-orange-600'
      case 'completed':
        return 'text-lime-600'
      case 'dispute':
        return 'text-indigo-600'
      case 'cancelled':
        return 'text-stone-600'
      case 'closed':
        return 'text-stone-500'
      default:
        return 'text-gray-500'
    }
  } else {
    // Applicant Status 顏色
    switch (status) {
      case 'pending':
        return 'text-amber-600'
      case 'accepted':
        return 'text-lime-600'
      case 'in_progress':
        return 'text-sky-600'
      case 'completed':
        return 'text-green-600'
      case 'rejected':
        return 'text-violet-600'
      case 'cancelled':
        return 'text-stone-600'
      default:
        return 'text-gray-500'
    }
  }
}

const getApplicantStatusDisplay = (status?: string) => {
  switch (status) {
    case 'pending':
      return 'Pending'
    case 'accepted':
      return 'Accepted'
    case 'in_progress':
      return 'In Progress'
    case 'completed':
      return 'Completed'
    case 'rejected':
      return 'Rejected'
    case 'cancelled':
      return 'Cancelled'
    default:
      return status || 'Unknown'
  }
}

onMounted(() => {
  loadChatRoom()
})
</script>

<style scoped>
.admin-chat-room-view {
  height: calc(100vh - 4rem);
}

.chat-messages-container {
  max-height: calc(100vh - 300px);
}
</style>
