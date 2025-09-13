<template>
  <div class="message-bubble-container">
    <!-- 爭議提交分界線 -->
    <div v-if="isDisputeSubmissionPoint" class="dispute-divider my-6">
      <div class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-orange-300"></div>
        </div>
        <div class="relative flex justify-center">
          <span class="bg-white px-3 text-sm font-medium text-orange-600 flex items-center rounded-full">
            <Icon name="exclamation-triangle" class="mr-2 h-4 w-4" />
            Dispute Submitted Here
          </span>
        </div>
      </div>
    </div>
    
    <!-- 訊息氣泡 -->
    <div class="flex items-start" :class="getContainerAlignClass()">
      <!-- 左側訊息佈局 -->
      <template v-if="!isRightSide()">
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
            <div class="rounded-lg border p-3 shadow-sm" :class="getBubbleColorClass()">
              <div :class="getBubbleAlignClass()">
                <MessageContentRenderer 
                  :message="message"
                  :is-admin-view="true"
                  :current-admin-id="currentAdminId"
                />
              </div>
            </div>
          </div>
        </div>
      </template>
      
      <!-- 右側訊息佈局（水平翻轉） -->
      <template v-else>
        <div class="flex items-start space-x-reverse space-x-3">
          <!-- 訊息內容 -->
          <div class="min-w-0 flex-1">
            <!-- 用戶資訊（右對齊） -->
            <div class="flex items-center justify-end mb-1">
              <p class="text-xs text-gray-500">
                {{ formatDateTime(message.created_at) }}
              </p>
              <span :class="getUserRoleBadgeClass()" class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ml-2">
                {{ getUserRole() }}
              </span>
              <p class="text-sm font-medium text-gray-900 ml-2">
                {{ getUserName() }}
              </p>
            </div>
            
            <!-- 訊息內容區 -->
            <div class="rounded-lg border p-3 shadow-sm" :class="getBubbleColorClass()">
              <div :class="getBubbleAlignClass()">
                <MessageContentRenderer 
                  :message="message"
                  :is-admin-view="true"
                  :current-admin-id="currentAdminId"
                />
              </div>
            </div>
          </div>
          
          <!-- 用戶頭像 -->
          <div class="flex-shrink-0">
            <img 
              :src="getAvatarUrl()" 
              :alt="getUserName()"
              class="h-8 w-8 rounded-full"
            />
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
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
  media_url?: string
  mime_type?: string
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
  rightSideUserId?: number
  adminId?: number
}

const props = defineProps<Props>()

// Data
const currentAdminId = computed(() => {
  // 優先使用 prop 中的 adminId
  if (props.adminId !== undefined) {
    return props.adminId
  }
  
  // 備用方案：從 localStorage 獲取
  try {
    const adminUser = localStorage.getItem('admin_user')
    if (adminUser) {
      const user = JSON.parse(adminUser)
      const idNum = Number(user.id || user.admin_id)
      return Number.isFinite(idNum) ? idNum : undefined
    }
  } catch (e) {
    console.warn('Failed to get current admin ID:', e)
  }
  
  return undefined
})

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
  
  // 檢查是否為爭議申請人
  const isDisputer = props.message.from_user_id === props.rightSideUserId
  
  if (props.message.from_user_id === props.task.creator_id) {
    return isDisputer ? 'Creator (Disputer)' : 'Creator'
  }
  
  if (props.message.from_user_id === props.task.participant_id) {
    return isDisputer ? 'Tasker (Disputer)' : 'Tasker'
  }
  
  return isDisputer ? 'Other (Disputer)' : 'Other'
}

const isRightSide = () => {
  // 如果沒有指定右側用戶ID，預設靠左
  if (!props.rightSideUserId) return false
  
  // 如果訊息沒有發送者ID，預設靠左
  if (!props.message.from_user_id) return false
  
  // 只要是爭議申請人的訊息，不管 kind 類型都靠右顯示
  return props.message.from_user_id === props.rightSideUserId
}

const getContainerAlignClass = () => {
  // 系統訊息如果是爭議申請人發送的，也要靠右
  if (props.message.kind === 'system' && isRightSide()) {
    return 'justify-end'
  }
  // 系統訊息如果是其他人發送的，居中顯示
  if (props.message.kind === 'system') {
    return 'justify-center'
  }
  return isRightSide() ? 'justify-end' : 'justify-start'
}

const getBubbleAlignClass = () => {
  // 系統訊息如果是爭議申請人發送的，也要右對齊
  if (props.message.kind === 'system' && isRightSide()) {
    return 'text-right'
  }
  // 系統訊息如果是其他人發送的，居中顯示
  if (props.message.kind === 'system') {
    return 'text-center'
  }
  return isRightSide() ? 'text-right' : 'text-left'
}

const getBubbleColorClass = () => {
  // 如果是爭議申請人的訊息，不管 kind 類型都使用藍色系
  if (isRightSide()) {
    return 'bg-indigo-50 border-indigo-200'
  }
  
  // 系統訊息使用灰色背景
  if (props.message.kind === 'system') {
    return 'bg-gray-50 border-gray-200'
  }
  
  // 其他訊息使用白色背景
  return 'bg-white border-gray-200'
}

const getUserRoleBadgeClass = () => {
  const role = getUserRole()
  
  // 處理帶有 (Disputer) 備註的角色
  if (role.includes('(Disputer)')) {
    if (role.includes('Creator')) {
      return 'bg-orange-100 text-orange-800 border border-orange-200'
    } else if (role.includes('Tasker')) {
      return 'bg-green-100 text-green-800 border border-orange-200'
    } else {
      return 'bg-gray-100 text-gray-600 border border-orange-200'
    }
  }
  
  // 處理一般角色
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
  let avatarUrl = ''
  
  if (props.message.from_user_id && props.users[props.message.from_user_id]) {
    avatarUrl = props.users[props.message.from_user_id].avatar_url || ''
  } else {
    avatarUrl = props.message.user_avatar || ''
  }
  
  if (!avatarUrl) {
    return '/default-avatar.png' // 預設頭像
  }
  
  // 使用與 MessageContentRenderer 相同的圖片處理邏輯
  return getImageUrl(avatarUrl)
}

const getImageUrl = (imagePath?: string) => {
  if (!imagePath) return ''
  
  // 如果是完整 URL，直接返回
  if (imagePath.startsWith('http')) {
    return imagePath
  }
  
  // 修復常見的拼寫錯誤：backend/ploads/ -> backend/uploads/
  if (imagePath.startsWith('backend/ploads/')) {
    imagePath = imagePath.replace('backend/ploads/', 'backend/uploads/')
  }
  
  // 統一處理 uploads/ 路徑
  if (imagePath.startsWith('uploads/')) {
    // 確保路徑以 / 開頭，這樣 Vite 代理才能正確處理
    return `/${imagePath}`
  }
  
  // 處理舊格式：/backend/uploads/
  if (imagePath.startsWith('/backend/uploads/')) {
    return imagePath.replace('/backend', '')
  }
  
  // 處理舊格式：backend/uploads/
  if (imagePath.startsWith('backend/uploads/')) {
    return `/${imagePath}`
  }
  
  // 其他情況，假設是相對路徑
  return imagePath
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
