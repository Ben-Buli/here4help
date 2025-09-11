<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Support Chat Detail
        </h2>
        <p class="mt-1 text-sm text-gray-500">Chat Room ID: {{ roomId }}</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="goBack" class="admin-button-secondary">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
          </svg>
          Back to List
        </button>
        <button @click="refreshData" class="admin-button-secondary" :disabled="isLoading">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
    </div>

    <div v-else-if="!chatRoom" class="text-center py-8 text-gray-500">
      Chat room not found
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- 聊天室資訊 -->
      <div class="lg:col-span-1">
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Chat Room Info</h3>
          
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Room ID</label>
              <p class="mt-1 text-sm text-gray-900">{{ chatRoom.room_id }}</p>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Status</label>
              <span 
                class="inline-flex px-2 py-1 text-xs font-semibold rounded-full mt-1" 
                :class="getStatusClass(chatRoom.status)"
              >
                {{ getStatusDisplay(chatRoom.status) }}
              </span>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Customer</label>
              <div class="mt-1 space-y-1">
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500">ID:</span>
                  <span class="text-sm font-medium text-gray-900">{{ chatRoom.user_id || '-' }}</span>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500">Name:</span>
                  <span class="text-sm font-medium text-gray-900">{{ chatRoom.user_name || '-' }}</span>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500">Nickname:</span>
                  <span class="text-sm font-medium text-gray-900">{{ chatRoom.user_nickname || '-' }}</span>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500">Email:</span>
                  <span class="text-sm text-gray-500">{{ chatRoom.user_email || 'N/A' }}</span>
                </div>
              </div>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">Created</label>
              <p class="mt-1 text-sm text-gray-900">{{ formatDateTime(chatRoom.created_at) }}</p>
            </div>
            
            <div v-if="chatRoom.last_message_time">
              <label class="block text-sm font-medium text-gray-700">Last Activity</label>
              <p class="mt-1 text-sm text-gray-900">{{ formatDateTime(chatRoom.last_message_time) }}</p>
            </div>
          </div>
          
          <!-- 操作按鈕 -->
          <div class="mt-6 space-y-3">
            <!-- Mark as Resolved 按鈕已隱藏 - 管理員目前沒有此權限 -->
          </div>
        </div>
      </div>

      <!-- 聊天訊息區域 -->
      <div class="lg:col-span-2">
        <div class="admin-card">
          <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Chat Messages</h3>
          <!-- Socket 連接狀態指示器 -->
          <div class="flex items-center space-x-2">
            <div 
              class="w-2 h-2 rounded-full"
              :class="isSocketConnected ? 'bg-green-500' : 'bg-red-500'"
            ></div>
            <span class="text-xs text-gray-500">
              {{ isSocketConnected ? 'Connected' : 'Disconnected' }}
            </span>
          </div>
        </div>
          
          <div class="space-y-4 max-h-96 overflow-y-auto messages-container">
            <div v-if="messages.length === 0" class="text-center py-8 text-gray-500">
              No messages yet
            </div>
            
            <!-- 訊息容器 -->
            <div 
              v-for="message in messages" 
              :key="message.id"
              class="flex"
              :class="{ 'justify-end': message.is_own }"
            >
              <!-- 訊息區塊 -->
              <div class="flex items-start space-x-3"
                   :class="{ 
                     'flex-row-reverse space-x-reverse': message.is_own,
                     'max-w-xs lg:max-w-md': !message.is_own
                   }">
                <!-- 頭像 -->
                <div class="h-8 w-8 rounded-full flex-shrink-0 flex items-center justify-center"
                     :class="message.kind === 'system' ? 'bg-gray-200' : 'bg-gray-100'">
                  <img 
                    v-if="message.kind !== 'system'"
                    :src="getAvatarUrl(message.sender_avatar)" 
                    :alt="message.sender_name"
                    class="h-8 w-8 rounded-full"
                  />
                  <svg 
                    v-else
                    class="h-4 w-4 text-gray-500" 
                    fill="none" 
                    stroke="currentColor" 
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                </div>
                
                <!-- 訊息內容 -->
                <div :class="message.is_own ? '' : 'flex-1 min-w-0'">
                  <!-- 發送者資訊和時間戳記 -->
                  <div class="flex items-center space-x-2 mb-1"
                       :class="{ 'flex-row-reverse space-x-reverse': message.is_own }">
                    <p class="text-sm font-medium text-gray-900">{{ message.sender_name }}</p>
                    <p class="text-xs text-gray-500">{{ formatDateTime(message.created_at) }}</p>
                    <span 
                      v-if="message.kind === 'system'"
                      class="inline-flex px-2 py-0.5 text-xs font-medium rounded-full bg-cyan-100 text-blue-800"
                    >
                      System
                    </span>
                  </div>
                  
                  <!-- 訊息內容 -->
                  <div
                    class="px-3 py-2 rounded-lg text-sm max-w-xs lg:max-w-md"
                    :class="message.is_own 
                      ? 'bg-cyan-600 text-white self-end' 
                      : message.kind === 'system' 
                        ? 'bg-gray-100 text-gray-700 self-start' 
                        : 'bg-gray-200 text-gray-900 self-start'"
                  >
                    <!-- 圖片訊息 -->
                    <div v-if="message.kind === 'image'">
                      <img 
                        :src="getImageUrl(message.content)" 
                        :alt="'Image from ' + message.sender_name"
                        class="max-w-xs rounded-lg"
                      />
                    </div>
                    <!-- 文字訊息 -->
                    <div v-else>
                      {{ message.content }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- 發送訊息區域 -->
          <div class="mt-6 border-t pt-4">
            <!-- 已解決狀態提示 -->
            <div v-if="chatRoom?.status === 'resolved'" class="mb-4 p-3 bg-gray-100 rounded-lg">
              <div class="flex items-center">
                <svg class="w-5 h-5 text-gray-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <span class="text-sm text-gray-600">此聊天室已標記為已解決，無法發送新訊息</span>
              </div>
            </div>
            
            <div class="flex space-x-3">
              <!-- 圖片上傳按鈕 -->
              <!-- <button 
                @click="triggerImageUpload"
                class="admin-button-secondary"
                :disabled="isLoading || chatRoom?.status === 'resolved'"
                title="Upload Image"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
              </button> -->
              
              <!-- 隱藏的檔案輸入 -->
              <input 
                ref="imageInput"
                type="file"
                accept="image/*"
                @change="handleImageUpload"
                class="hidden"
                :disabled="chatRoom?.status === 'resolved'"
              />
              
              <input 
                v-model="newMessage"
                type="text" 
                class="flex-1 admin-input"
                :class="{ 'bg-gray-100 cursor-not-allowed': chatRoom?.status === 'resolved' }"
                placeholder="Type your message..."
                @keyup.enter.prevent="sendMessage"
                :disabled="isLoading || chatRoom?.status === 'resolved'"
              />
              <button 
                @click="sendMessage($event)"
                class="admin-button-primary"
                :class="{ 'opacity-50 cursor-not-allowed': chatRoom?.status === 'resolved' }"
                :disabled="isLoading || !newMessage.trim() || chatRoom?.status === 'resolved'"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
                </svg>
              </button>
            </div>
            
            <!-- 圖片上傳預覽區域 -->
            <div v-if="uploadingImages.length > 0" class="mt-4 space-y-2">
              <div 
                v-for="(image, index) in uploadingImages" 
                :key="index"
                class="relative inline-block"
              >
                <div class="relative">
                  <img 
                    :src="image.preview" 
                    :alt="'Uploading image ' + (index + 1)"
                    class="w-32 h-32 object-cover rounded-lg"
                  />
                  
                  <!-- 上傳狀態遮罩 -->
                  <div 
                    v-if="image.status === 'uploading'"
                    class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center rounded-lg"
                  >
                    <div class="text-center text-white">
                      <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-white mx-auto mb-2"></div>
                      <p class="text-xs">Uploading...</p>
                      <button 
                        @click="cancelUpload(index)"
                        class="mt-1 px-2 py-1 bg-red-500 text-white text-xs rounded hover:bg-red-600"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                  
                  <!-- 上傳失敗遮罩 -->
                  <div 
                    v-if="image.status === 'failed'"
                    class="absolute inset-0 bg-red-500 bg-opacity-75 flex items-center justify-center rounded-lg"
                  >
                    <div class="text-center text-white">
                      <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                      </svg>
                      <p class="text-xs mb-2">Upload Failed</p>
                      <div class="space-x-1">
                        <button 
                          @click="retryUpload(index)"
                          class="px-2 py-1 bg-cyan-500 text-white text-xs rounded hover:bg-cyan-600"
                        >
                          Retry
                        </button>
                        <button 
                          @click="removeImage(index)"
                          class="px-2 py-1 bg-red-500 text-white text-xs rounded hover:bg-red-600"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 圖片放大檢視 Modal -->
    <div 
      v-if="showImageModal" 
      class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
      @click="closeImageModal"
    >
      <div class="relative max-w-4xl max-h-full p-4">
        <button 
          @click="closeImageModal"
          class="absolute top-4 right-4 text-white hover:text-gray-300 z-10"
        >
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
        <img 
          :src="modalImageUrl" 
          :alt="'Enlarged image'"
          class="max-w-full max-h-full object-contain rounded-lg"
          @click.stop
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { adminSupportApi } from '@/services/api'
import { socketService } from '@/services/socket'

const route = useRoute()
const router = useRouter()
const roomId = route.params.roomId as string

const isLoading = ref(false)
const chatRoom = ref<any>(null)
const messages = ref<any[]>([])
const newMessage = ref('')

// 圖片上傳相關
const uploadingImages = ref<any[]>([])
const imageInput = ref<HTMLInputElement | null>(null)

// 圖片 modal 相關
const showImageModal = ref(false)
const modalImageUrl = ref('')

// Socket 連接狀態
const isSocketConnected = ref(false)

const loadChatRoom = async (skipSocketSetup = false) => {
  try {
    isLoading.value = true
    
    // 載入聊天室資訊
    const response = await adminSupportApi.getChatRoom(roomId)
    
    if (response.data.success && response.data.data) {
      chatRoom.value = response.data.data
      
      // 載入聊天訊息
      await loadMessages()
      
      // 只在首次載入時設置 Socket 連接，避免重複連接
      if (!skipSocketSetup && !isSocketConnected.value) {
        await setupSocket()
      }
    } else {
      console.error('Failed to load chat room:', response.data.message)
    }
  } catch (error: any) {
    console.error('Failed to load chat room:', error)
    if (error.response?.status === 404) {
      console.log('Chat room not found')
    } else if (error.response?.status === 403) {
      console.log('Access denied')
    }
  } finally {
    isLoading.value = false
  }
}

const loadMessages = async () => {
  try {
    const response = await adminSupportApi.getMessages(roomId, { limit: 50 })
    
    if (response.data.success && response.data.data) {
      messages.value = response.data.data.messages || []
      
      // 標記最新訊息為已讀
      if (messages.value.length > 0) {
        const latestMessage = messages.value[messages.value.length - 1]
        if (!latestMessage.is_own) {
          await adminSupportApi.markAsRead(roomId, latestMessage.id)
        }
      }
      
      // 載入訊息後滾動到底部
      scrollToBottom()
    }
  } catch (error) {
    console.error('Failed to load messages:', error)
  }
}

const sendMessage = async (event?: Event) => {
  // 阻止默認行為（防止表單提交）
  if (event) {
    event.preventDefault()
  }
  
  if (!newMessage.value.trim()) return
  
  // 檢查聊天室狀態，如果已解決則不允許發送訊息
  if (chatRoom.value?.status === 'resolved') {
    alert('此聊天室已標記為已解決，無法發送新訊息')
    return
  }
  
  // 防止重複發送
  if (isLoading.value) return
  
  try {
    isLoading.value = true
    const messageContent = newMessage.value.trim()
    
    const response = await adminSupportApi.sendMessage(roomId, {
      content: messageContent,
      kind: 'text'
    })
    
    if (response.data.success && response.data.data) {
      // 立即清空輸入框，提供即時反饋
      newMessage.value = ''
      
      // 添加新訊息到列表
      const newMsg = {
        id: response.data.data.message_id,
        content: response.data.data.content,
        sender_name: 'Admin',
        sender_avatar: null,
        created_at: response.data.data.created_at,
        kind: response.data.data.kind,
        is_own: true
      }
      
      messages.value.push(newMsg)
      
      // 透過 Socket 發送即時訊息（讓對方即時看到）
      if (isSocketConnected.value) {
        socketService.sendMessage(
          roomId,
          messageContent,
          response.data.data.message_id.toString()
        )
      }
      
      // 滾動到底部
      await nextTick()
      scrollToBottom()
    }
  } catch (error: any) {
    console.error('Failed to send message:', error)
    alert(`Error: ${error.response?.data?.message || error.message}`)
  } finally {
    isLoading.value = false
  }
}

const updateStatus = async (status: string) => {
  try {
    isLoading.value = true
    
    const response = await adminSupportApi.updateStatus(roomId, status as 'submitted' | 'in_progress' | 'resolved')
    
    if (response.data.success) {
      // 只更新聊天室狀態，不重新載入整個聊天室（避免 Socket 重新連接）
      await loadChatRoom(true) // skipSocketSetup = true
    } else {
      throw new Error(response.data.message || 'Failed to update status')
    }
  } catch (error: any) {
    console.error('Failed to update status:', error)
    alert(`Error: ${error.message}`)
  } finally {
    isLoading.value = false
  }
}

const refreshData = async () => {
  const response = await adminSupportApi.getChatRoom(roomId)
  if (response.data.success) {
    chatRoom.value = response.data.data
  }
  scrollToBottom()
}

const goBack = () => {
  router.push('/support-chat-list')
}

const getAvatarUrl = (avatarUrl?: string) => {
  if (!avatarUrl) {
    // 使用管理員預設頭像
    return '/uploads/avatars/default.png'
  }
  
  // users.avatar_url 的路徑格式：/backend/uploads/avatars/filename
  if (avatarUrl.startsWith('/backend/')) {
    // 移除 /backend 前綴，因為 Vite 代理會處理
    return avatarUrl.replace('/backend', '')
  }
  
  // 如果是完整 URL，直接返回
  if (avatarUrl.startsWith('http')) {
    return avatarUrl
  }
  
  // 其他情況，假設是相對路徑
  return avatarUrl
}

// 圖片相關方法
const getImageUrl = (imagePath: string) => {
  if (!imagePath) return ''
  
  // 如果是完整 URL，直接返回
  if (imagePath.startsWith('http')) {
    return imagePath
  }
  
  // 修復常見的拼寫錯誤：backend/ploads/ -> backend/uploads/
  if (imagePath.startsWith('backend/ploads/')) {
    imagePath = imagePath.replace('backend/ploads/', 'backend/uploads/')
  }
  
  // 統一處理 uploads/support_chat/ 路徑
  if (imagePath.startsWith('uploads/support_chat/')) {
    // 對於客服聊天室圖片，如果檔案名以 att_ 開頭，
    // 表示檔案實際存儲在 chat 目錄中，需要調整路徑
    const fileName = imagePath.split('/').pop()
    if (fileName && fileName.startsWith('att_')) {
      // 檔案實際在 chat 目錄中
      return imagePath.replace('uploads/support_chat/', 'uploads/chat/')
    }
    // 確保路徑以 / 開頭，這樣 Vite 代理才能正確處理
    return `/${imagePath}`
  }
  
  // 處理舊格式：/backend/uploads/chat/ 或 /backend/uploads/support_chat/
  if (imagePath.startsWith('/backend/uploads/')) {
    return imagePath.replace('/backend', '')
  }
  
  // 處理舊格式：backend/uploads/chat/ 或 backend/uploads/support_chat/
  if (imagePath.startsWith('backend/uploads/')) {
    return `/${imagePath}`
  }
  
  // 其他情況，假設是相對路徑
  return imagePath
}

const openImageModal = (imagePath: string) => {
  modalImageUrl.value = getImageUrl(imagePath)
  showImageModal.value = true
}

const closeImageModal = () => {
  showImageModal.value = false
  modalImageUrl.value = ''
}

const handleImageError = () => {
  console.error('Failed to load image')
}

// 圖片上傳相關方法
const triggerImageUpload = () => {
  imageInput.value?.click()
}

const handleImageUpload = (event: Event) => {
  const target = event.target as HTMLInputElement
  const files = target.files
  
  if (!files || files.length === 0) return
  
  // 檢查聊天室狀態，如果已解決則不允許上傳圖片
  if (chatRoom.value?.status === 'resolved') {
    alert('此聊天室已標記為已解決，無法上傳圖片')
    target.value = ''
    return
  }
  
  const file = files[0]
  
  // 檢查檔案類型
  if (!file.type.startsWith('image/')) {
    alert('Please select an image file')
    return
  }
  
  // 檢查檔案大小 (5MB 限制)
  if (file.size > 5 * 1024 * 1024) {
    alert('Image size must be less than 5MB')
    return
  }
  
  // 創建預覽
  const reader = new FileReader()
  reader.onload = (e) => {
    const imageData = {
      file,
      preview: e.target?.result as string,
      status: 'uploading' as const,
      uploadProgress: 0
    }
    
    uploadingImages.value.push(imageData)
    
    // 開始上傳
    uploadImage(imageData, uploadingImages.value.length - 1)
  }
  
  reader.readAsDataURL(file)
  
  // 清空 input
  target.value = ''
}

const uploadImage = async (imageData: any, index: number) => {
  try {
    const formData = new FormData()
    formData.append('image', imageData.file)
    formData.append('room_id', roomId)
    
    // 使用管理員專用的圖片上傳 API
    const response = await fetch('/api/admin/support/upload-image', {
      method: 'POST',
      body: formData,
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('admin_token')}`
      }
    })
    
    const result = await response.json()
    
    if (result.success) {
      imageData.status = 'success'
      imageData.uploadProgress = 100
      
      // 發送圖片訊息
      await sendImageMessage(result.data.path)
      
      // 移除上傳預覽
      uploadingImages.value.splice(index, 1)
    } else {
      throw new Error(result.message || 'Upload failed')
    }
    
  } catch (error) {
    console.error('Upload failed:', error)
    imageData.status = 'failed'
  }
}

const sendImageMessage = async (imageUrl: string) => {
  try {
    const response = await adminSupportApi.sendMessage(roomId, {
      content: imageUrl,
      kind: 'image'
    })
    
    if (response.data.success && response.data.data) {
      // 添加新訊息到列表
      messages.value.push({
        id: response.data.data.message_id,
        content: imageUrl,
        sender_name: 'Admin',
        sender_avatar: null,
        created_at: response.data.data.created_at,
        kind: 'image',
        is_own: true
      })
      
      // 滾動到底部
      scrollToBottom()
    }
  } catch (error: any) {
    console.error('Failed to send image message:', error)
    alert(`Error: ${error.response?.data?.message || error.message}`)
  }
}

const cancelUpload = (index: number) => {
  uploadingImages.value.splice(index, 1)
}

const retryUpload = (index: number) => {
  const imageData = uploadingImages.value[index]
  imageData.status = 'uploading'
  uploadImage(imageData, index)
}

const removeImage = (index: number) => {
  uploadingImages.value.splice(index, 1)
}

const getStatusClass = (status: string) => {
  const statusClasses: Record<string, string> = {
    open: 'bg-yellow-100 text-yellow-800',
    in_progress: 'bg-cyan-100 text-blue-800',
    waiting_customer: 'bg-purple-100 text-purple-800',
    resolved: 'bg-green-100 text-green-800',
    closed: 'bg-gray-200 text-gray-700',
  }
  return statusClasses[status] || 'bg-gray-100 text-gray-800'
}

const getStatusDisplay = (status: string) => {
  const statusDisplays: Record<string, string> = {
    open: 'Open',
    in_progress: 'In Progress',
    waiting_customer: 'Waiting Customer',
    resolved: 'Resolved',
    closed: 'Closed'
  }
  return statusDisplays[status] || status
}

const formatDateTime = (dateTimeStr?: string) => {
  if (!dateTimeStr) return ''
  return new Date(dateTimeStr).toLocaleString()
}

// Socket 設置和事件處理
const setupSocket = async () => {
  try {
    // 如果已經連接且在同一房間，不需要重新設置
    if (isSocketConnected.value && socketService.currentRoom === roomId) {
      console.log('✅ Socket already connected to room:', roomId)
      return
    }
    
    // 連接 Socket
    await socketService.connect()
    
    // 設置事件監聽器（避免重複設置）
    socketService.addMessageListener(onSocketMessage)
    socketService.addConnectionListener(onSocketConnection)
    
    // 加入當前聊天室
    socketService.joinRoom(roomId)
    
    console.log('✅ Socket setup completed for room:', roomId)
  } catch (error) {
    console.error('❌ Socket setup failed:', error)
  }
}

// Socket 事件處理
const onSocketMessage = (data: any) => {
  console.log('📨 Received socket message:', data)
  
  // 檢查是否為當前房間的訊息
  if (data.roomId === roomId || data.room_id === roomId) {
    // 檢查是否為用戶發送的訊息（非管理員）
    if (data.fromUserId && data.fromUserId !== 'admin') {
      // 添加新訊息到列表
      const newMsg = {
        id: data.messageId || data.message_id || Date.now(),
        content: data.text || data.content,
        sender_name: chatRoom.value?.user_name || 'User',
        sender_avatar: chatRoom.value?.user_avatar,
        created_at: new Date().toISOString(),
        kind: 'text',
        is_own: false
      }
      
      messages.value.push(newMsg)

      if (!messages.value.find(m => m.id === newMsg.id)) {
    messages.value.push(newMsg)
  }

      
      // 滾動到底部
      scrollToBottom()
      
      // 標記為已讀
      if (isSocketConnected.value) {
        socketService.markAsRead(roomId, newMsg.id.toString())
      }
    }
  }
}

const onSocketConnection = (connected: boolean) => {
  isSocketConnected.value = connected
  console.log('🔌 Socket connection status:', connected)
}

// 清理 Socket 連接
const cleanupSocket = () => {
  if (socketService.currentRoom === roomId) {
    socketService.leaveRoom(roomId)
  }
  socketService.removeMessageListener(onSocketMessage)
  socketService.removeConnectionListener(onSocketConnection)
}

// 滾動到聊天室底部（優化版本）
let scrollTimeout: number | null = null
const scrollToBottom = async () => {
  await nextTick()
  
  // 清除之前的滾動定時器，避免重複滾動
  if (scrollTimeout) {
    clearTimeout(scrollTimeout)
  }
  
  scrollTimeout = setTimeout(() => {
    const messagesContainer = document.querySelector('.messages-container')
    if (messagesContainer) {
      messagesContainer.scrollTop = messagesContainer.scrollHeight
    }
    scrollTimeout = null
  }, 50) // 減少延遲時間
}

onMounted(() => {
  loadChatRoom()
})

onUnmounted(() => {
  cleanupSocket()
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

.admin-button-primary {
  @apply inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500;
}
</style>
