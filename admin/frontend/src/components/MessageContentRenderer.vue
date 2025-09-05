<template>
  <div class="message-content">
    <!-- 文字訊息 -->
    <div v-if="message.kind === 'text'" class="text-content">
      <p class="text-sm text-gray-900 whitespace-pre-wrap">{{ message.content }}</p>
    </div>
    
    <!-- 系統訊息 -->
    <div v-else-if="message.kind === 'system'" class="system-content">
      <div class="flex items-start space-x-2">
        <Icon name="info-circle" class="flex-shrink-0 h-4 w-4 text-blue-500 mt-0.5" />
        <div class="flex-1">
          <p class="text-sm text-gray-700 whitespace-pre-wrap">{{ message.content }}</p>
        </div>
      </div>
    </div>
    
    <!-- 圖片訊息 -->
    <div v-else-if="message.kind === 'image'" class="image-content">
      <div class="space-y-2">
        <p v-if="message.content" class="text-sm text-gray-900">{{ message.content }}</p>
        <div v-if="message.image_url" class="image-container">
          <img 
            :src="getImageUrl(message.image_url)" 
            :alt="message.content || 'Shared image'"
            class="max-w-xs rounded-lg shadow-sm cursor-pointer hover:shadow-md transition-shadow"
            @click="openImageModal"
            @error="handleImageError"
          />
        </div>
      </div>
    </div>
    
    <!-- Resume 訊息 -->
    <div v-else-if="message.kind === 'resume'" class="resume-content">
      <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
        <div class="flex items-start space-x-3">
          <Icon name="document-text" class="flex-shrink-0 h-6 w-6 text-indigo-500" />
          <div class="flex-1 min-w-0">
            <h4 class="text-sm font-medium text-gray-900 mb-2">Application Resume</h4>
            
            <div v-if="resumeData" class="space-y-3">
              <!-- 基本資訊 -->
              <div v-if="resumeData.name || resumeData.email || resumeData.phone" class="space-y-1">
                <p v-if="resumeData.name" class="text-sm">
                  <span class="font-medium text-gray-700">Name:</span> {{ resumeData.name }}
                </p>
                <p v-if="resumeData.email" class="text-sm">
                  <span class="font-medium text-gray-700">Email:</span> {{ resumeData.email }}
                </p>
                <p v-if="resumeData.phone" class="text-sm">
                  <span class="font-medium text-gray-700">Phone:</span> {{ resumeData.phone }}
                </p>
              </div>
              
              <!-- 經驗描述 -->
              <div v-if="resumeData.experience" class="space-y-1">
                <p class="text-sm font-medium text-gray-700">Experience:</p>
                <p class="text-sm text-gray-600 whitespace-pre-wrap">{{ resumeData.experience }}</p>
              </div>
              
              <!-- 技能 -->
              <div v-if="resumeData.skills && resumeData.skills.length > 0" class="space-y-1">
                <p class="text-sm font-medium text-gray-700">Skills:</p>
                <div class="flex flex-wrap gap-1">
                  <span 
                    v-for="skill in resumeData.skills" 
                    :key="skill"
                    class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                  >
                    {{ skill }}
                  </span>
                </div>
              </div>
              
              <!-- 預期價格 -->
              <div v-if="resumeData.expected_price" class="space-y-1">
                <p class="text-sm">
                  <span class="font-medium text-gray-700">Expected Price:</span> 
                  <span class="text-green-600 font-medium">{{ resumeData.expected_price }} points</span>
                </p>
              </div>
              
              <!-- 其他資訊 -->
              <div v-if="resumeData.additional_info" class="space-y-1">
                <p class="text-sm font-medium text-gray-700">Additional Information:</p>
                <p class="text-sm text-gray-600 whitespace-pre-wrap">{{ resumeData.additional_info }}</p>
              </div>
            </div>
            
            <!-- 如果沒有 resume 資料，顯示原始內容 -->
            <div v-else class="text-sm text-gray-600">
              <p>{{ message.content }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 未知訊息類型 -->
    <div v-else class="unknown-content">
      <div class="flex items-start space-x-2">
        <Icon name="question-mark-circle" class="flex-shrink-0 h-4 w-4 text-gray-400 mt-0.5" />
        <div class="flex-1">
          <p class="text-sm text-gray-500">
            Unknown message type: {{ message.kind }}
          </p>
          <p v-if="message.content" class="text-sm text-gray-600 mt-1">{{ message.content }}</p>
        </div>
      </div>
    </div>
    
    <!-- 管理員檢視標記 -->
    <div v-if="isAdminView" class="admin-view-indicator mt-2 pt-2 border-t border-gray-100">
      <div class="flex items-center space-x-2 text-xs text-gray-400">
        <Icon name="eye" class="h-3 w-3" />
        <span>Admin View</span>
        <span>•</span>
        <span>Message ID: {{ message.id }}</span>
        <span>•</span>
        <span>Room: {{ message.room_id }}</span>
      </div>
    </div>
  </div>
  
  <!-- 圖片模態框 -->
  <div 
    v-if="showImageModal" 
    class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75"
    @click="closeImageModal"
  >
    <div class="max-w-4xl max-h-full p-4">
      <img 
        :src="getImageUrl(message.image_url)" 
        :alt="message.content || 'Shared image'"
        class="max-w-full max-h-full rounded-lg shadow-2xl"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import Icon from '@/components/Icon.vue'

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

interface Props {
  message: ChatMessage
  isAdminView?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  isAdminView: false
})

// Data
const showImageModal = ref(false)

// Computed
const resumeData = computed(() => {
  if (props.message.kind === 'resume' && props.message.resume_data) {
    try {
      return typeof props.message.resume_data === 'string' 
        ? JSON.parse(props.message.resume_data)
        : props.message.resume_data
    } catch (e) {
      console.error('Failed to parse resume data:', e)
      return null
    }
  }
  return null
})

// Methods
const getImageUrl = (imageUrl?: string) => {
  if (!imageUrl) return ''
  
  // 如果是相對路徑，加上 API base URL
  if (imageUrl.startsWith('backend/')) {
    return `${import.meta.env.VITE_API_BASE_URL}/${imageUrl}`
  }
  
  return imageUrl
}

const openImageModal = () => {
  showImageModal.value = true
}

const closeImageModal = () => {
  showImageModal.value = false
}

const handleImageError = (event: Event) => {
  const img = event.target as HTMLImageElement
  img.src = '/image-placeholder.png' // 圖片載入失敗時的預設圖片
}
</script>

<style scoped>
.message-content {
  word-wrap: break-word;
  overflow-wrap: break-word;
}

.image-container img {
  max-width: 300px;
  max-height: 200px;
  object-fit: cover;
}

.admin-view-indicator {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
}
</style>
