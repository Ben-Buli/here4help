<template>
  <div class="message-bubble-container">
    <!-- 爭議提交分界線 -->
    <div v-if="isDisputeSubmissionPoint" class="dispute-divider my-6">
      <div class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-orange-300"></div>
        </div>
        <div class="relative flex justify-center">
          <span class="bg-white px-3 text-sm font-medium text-orange-600 flex items-center">
            <Icon name="alert-triangle" class="mr-2 h-4 w-4" />
            Dispute Submitted Here
          </span>
        </div>
      </div>
    </div>
    
    <!-- 訊息氣泡 -->
    <div class="flex items-start space-x-3">
      <!-- 用戶頭像 -->
      <div class="flex-shrink-0">
        <img 
          :src="getAvatarUrl()" 
          :alt="getUserName()"
          class="h-8 w-8 rounded-full"
        />
      </div>
      
      <!-- 訊息內容 -->
      <div class="min-w-0 flex-1">
        <!-- 用戶資訊 -->
        <div class="flex items-center space-x-2 mb-1">
          <p class="text-sm font-medium text-gray-900">
            {{ getUserName() }}
          </p>
          <span :class="getUserRoleBadgeClass()" class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium">
            {{ getUserRole() }}
          </span>
          <p class="text-xs text-gray-500">
            {{ formatDateTime(message.created_at) }}
          </p>
        </div>
        
        <!-- 訊息內容區 -->
        <div class="bg-white rounded-lg border border-gray-200 p-3 shadow-sm">
          <MessageContentRenderer 
            :message="message"
            :is-admin-view="true"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import Icon from '@/components/Icon.vue'
import MessageContentRenderer from '@/components/MessageContentRenderer.vue'

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
}

interface Props {
  message: ChatMessage
  users: Record<number, UserInfo>
  task: TaskInfo
  disputeSubmittedAt?: string
}

const props = defineProps<Props>()

// Computed
const isDisputeSubmissionPoint = computed(() => {
  if (!props.disputeSubmittedAt) return false
  
  // 檢查這則訊息是否在爭議提交時間點附近（前後5分鐘內）
  const messageTime = new Date(props.message.created_at).getTime()
  const disputeTime = new Date(props.disputeSubmittedAt).getTime()
  const timeDiff = Math.abs(messageTime - disputeTime)
  
  // 如果時間差在5分鐘內，且是爭議提交後的第一則訊息
  return timeDiff <= 5 * 60 * 1000 && messageTime >= disputeTime
})

// Methods
const getUserName = () => {
  if (props.message.kind === 'system') {
    return 'System'
  }
  
  if (props.message.from_user_id && props.users[props.message.from_user_id]) {
    return props.users[props.message.from_user_id].name
  }
  
  return props.message.user_name || 'Unknown User'
}

const getUserRole = () => {
  if (props.message.kind === 'system') {
    return 'System'
  }
  
  if (!props.message.from_user_id) {
    return 'Unknown'
  }
  
  if (props.message.from_user_id === props.task.creator_id) {
    return 'Creator'
  }
  
  if (props.message.from_user_id === props.task.participant_id) {
    return 'Tasker'
  }
  
  return 'Other'
}

const getUserRoleBadgeClass = () => {
  const role = getUserRole()
  
  switch (role) {
    case 'System':
      return 'bg-gray-100 text-gray-800'
    case 'Creator':
      return 'bg-blue-100 text-blue-800'
    case 'Tasker':
      return 'bg-green-100 text-green-800'
    default:
      return 'bg-gray-100 text-gray-600'
  }
}

const getAvatarUrl = () => {
  if (props.message.kind === 'system') {
    return '/system-avatar.png' // 系統訊息的預設頭像
  }
  
  let avatarUrl = ''
  
  if (props.message.from_user_id && props.users[props.message.from_user_id]) {
    avatarUrl = props.users[props.message.from_user_id].avatar_url || ''
  } else {
    avatarUrl = props.message.user_avatar || ''
  }
  
  if (!avatarUrl) {
    return '/default-avatar.png' // 預設頭像
  }
  
  // 如果是相對路徑，加上 API base URL
  if (avatarUrl.startsWith('backend/')) {
    return `${import.meta.env.VITE_API_BASE_URL}/${avatarUrl}`
  }
  
  return avatarUrl
}

const formatDateTime = (dateTimeStr: string) => {
  const date = new Date(dateTimeStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffHours = diffMs / (1000 * 60 * 60)
  
  if (diffHours < 24) {
    // 24小時內顯示時間
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  } else if (diffHours < 24 * 7) {
    // 一週內顯示星期和時間
    return date.toLocaleDateString([], { weekday: 'short', hour: '2-digit', minute: '2-digit' })
  } else {
    // 超過一週顯示完整日期時間
    return date.toLocaleDateString([], { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric',
      hour: '2-digit', 
      minute: '2-digit' 
    })
  }
}
</script>

<style scoped>
.dispute-divider {
  margin: 1.5rem 0;
}
</style>
