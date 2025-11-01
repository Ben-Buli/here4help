<template>
  <div class="message-content">
    <!-- 文字訊息 -->
    <div v-if="message.kind === 'text'" class="text-content">
      <p class="text-sm text-gray-900 whitespace-pre-wrap">{{ message.content }}</p>
    </div>
    
    <!-- 系統訊息 -->
    <div v-else-if="message.kind === 'system'" class="system-content">
      <div class="flex items-start">
        <div class="flex-1">
          <p class="text-sm text-gray-700 whitespace-pre-wrap">{{ message.content }}</p>
        </div>
      </div>
    </div>
    
    <!-- 圖片訊息 -->
    <div v-else-if="isImageMessage" class="image-content">
      <div class="space-y-2">
        <p v-if="message.content && message.content !== message.media_url" class="text-sm text-gray-900">{{ message.content }}</p>
        <div v-if="imageSource" class="image-container">
          <img 
            :src="imageSource" 
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
        <details class="group">
          <summary class="flex items-center space-x-3 cursor-pointer list-none">
            <div class="flex-shrink-0">
              <Icon name="document-text" class="h-6 w-6 text-indigo-500" />
            </div>
            <h4 class="text-sm font-medium text-gray-900">Application Resume</h4>
            <Icon name="chevron-down" class="h-4 w-4 text-gray-400 group-open:rotate-180 transition-transform" />
          </summary>
          
          <div class="mt-4 space-y-3">
            <div v-if="resumeData" class="space-y-3">
              <!-- Self Introduction (統一使用這個，優先顯示 cover_letter 或 applyIntroduction) -->
              <div v-if="resumeData.cover_letter || resumeData.applyIntroduction" class="space-y-1">
                <p class="text-sm font-medium text-gray-700">Self Introduction:</p>
                <div class="bg-white rounded-lg p-3 border border-gray-100">
                  <p class="text-sm text-gray-600 whitespace-pre-wrap">
                    {{ resumeData.cover_letter || resumeData.applyIntroduction }}
                  </p>
                </div>
              </div>
              
              <!-- 申請問題和回答 (Apply Responses) -->
              <div v-if="resumeData.applyResponses && resumeData.applyResponses.length > 0" class="space-y-3">
                <p class="text-sm font-medium text-gray-700">Application Questions & Answers:</p>
                <div class="space-y-3">
                  <div 
                    v-for="(response, index) in resumeData.applyResponses" 
                    :key="index"
                    class="bg-white rounded-lg p-3 border border-gray-100"
                  >
                    <div class="space-y-2">
                      <p class="text-sm font-medium text-gray-800">
                        <span class="text-indigo-600">Q{{ index + 1 }}:</span> {{ response.applyQuestion }}
                      </p>
                      <div class="bg-white rounded-lg p-3 border border-gray-100">
                        <p class="text-sm text-gray-600 whitespace-pre-wrap">
                          {{ response.applyReply }}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- 如果沒有任何資料，顯示原始內容 -->
              <div v-if="!resumeData.cover_letter && !resumeData.applyIntroduction && (!resumeData.applyResponses || resumeData.applyResponses.length === 0)" class="bg-white rounded-lg p-3 border border-gray-100">
                <p class="text-sm text-gray-600">{{ message.content }}</p>
              </div>
            </div>
            
            <!-- 如果沒有 resume 資料，顯示原始內容 -->
            <div v-else class="bg-white rounded-lg p-3 border border-gray-100">
              <p class="text-sm text-gray-600">{{ message.content }}</p>
            </div>
          </div>
        </details>
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
    
    <!-- 管理員檢視標記 - 只有 developer (ID = 3) 才顯示 -->
    <div v-if="isAdminView && currentAdminId === 3" class="admin-view-indicator mt-2 pt-2 border-t border-gray-100">
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
    <div class="relative max-w-4xl max-h-full p-4">
      <button 
        @click="closeImageModal"
        class="absolute top-4 right-4 text-white hover:text-gray-300 z-10"
      >
        <Icon name="x-mark" class="w-8 h-8" />
      </button>
      <img 
        :src="imageSource || ''" 
        :alt="message.content || 'Shared image'"
        class="max-w-full max-h-full object-contain rounded-lg"
        @click.stop
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import Icon from '@/components/Icon.vue'
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
  media_url?: string
  mime_type?: string
  resume_data?: any
}

interface Props {
  message: ChatMessage
  isAdminView?: boolean
  currentAdminId?: number | null
}

const props = withDefaults(defineProps<Props>(), {
  isAdminView: false,
  currentAdminId: undefined
})

// Data
const showImageModal = ref(false)

// Computed
const resumeData = computed(() => {
  if (props.message.kind === 'resume') {
    try {
      // 優先使用 resume_data 欄位
      if (props.message.resume_data) {
        return typeof props.message.resume_data === 'string' 
          ? JSON.parse(props.message.resume_data)
          : props.message.resume_data
      }
      
      // 如果沒有 resume_data，嘗試從 content 解析 JSON
      if (props.message.content) {
        const parsed = JSON.parse(props.message.content)
        return parsed
      }
    } catch (e) {
      console.error('Failed to parse resume data:', e)
      return null
    }
  }
  return null
})

// Image helpers
const isImageExtension = (value?: string) => {
  if (!value) return false
  return /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(value.split('?')[0])
}

const normalizeMediaPath = (raw?: string): string | null => {
  if (!raw) return null
  let path = raw.trim()
  if (!path) return null

  if (/^https?:\/\//i.test(path)) {
    return path
  }

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

const imageSource = computed(() => {
  const raw =
    props.message.media_url ||
    props.message.image_url ||
    (isImageExtension(props.message.content) ? props.message.content : '')

  const normalized = normalizeMediaPath(raw)
  if (!normalized) return null

  if (/^https?:\/\//i.test(normalized)) {
    return normalized
  }

  return getImageUrl(normalized.replace(/^uploads\//, ''))
})

const isImageMessage = computed(() => {
  if (props.message.kind === 'image') return true
  if (props.message.mime_type && props.message.mime_type.startsWith('image/')) return true
  if (props.message.media_url && isImageExtension(props.message.media_url)) return true
  if (props.message.image_url && isImageExtension(props.message.image_url)) return true
  if (props.message.content && isImageExtension(props.message.content)) return true
  return false
})

const openImageModal = () => {
  if (!imageSource.value) return
  showImageModal.value = true
}

const closeImageModal = () => {
  showImageModal.value = false
}

const handleImageError = (event: Event) => {
  const img = event.target as HTMLImageElement
  img.src =
    'data:image/svg+xml;utf8,' +
    encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200"><rect width="100%" height="100%" fill="#e5e7eb"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" fill="#6b7280" font-family="sans-serif" font-size="16">Image unavailable</text></svg>',
    )
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
