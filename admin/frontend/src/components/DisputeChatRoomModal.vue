<template>
  <div class="fixed inset-0 z-50 overflow-y-auto" v-if="show">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
      <!-- 背景遮罩 -->
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" @click="$emit('close')"></div>

      <!-- Dialog 內容 -->
      <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
        <!-- Header -->
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                爭議聊天記錄 - {{ disputeData?.dispute?.dispute_title || `爭議 #${disputeData?.dispute?.id}` }}
              </h3>
              <div class="mt-2 text-sm text-gray-500">
                <p><strong>任務：</strong>{{ disputeData?.dispute?.task?.title }}</p>
                <p><strong>獎勵：</strong>{{ disputeData?.dispute?.task?.reward_point }} 點數</p>
              </div>
            </div>
            <button
              @click="$emit('close')"
              class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              <span class="sr-only">Close</span>
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <!-- 參與者信息 -->
        <div class="bg-gray-50 px-4 py-3 sm:px-6">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="flex items-center space-x-3">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">A</span>
                </div>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">任務創建者</p>
                <p class="text-sm text-gray-500">{{ disputeData?.dispute?.creator?.name }}</p>
              </div>
            </div>
            <div class="flex items-center space-x-3">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                  <span class="text-white text-sm font-medium">B</span>
                </div>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">任務參與者</p>
                <p class="text-sm text-gray-500">{{ disputeData?.dispute?.participant?.name }}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- 聊天記錄 -->
        <div class="bg-white px-4 py-4 sm:px-6" style="max-height: 500px;">
          <!-- Loading State -->
          <div v-if="loading" class="flex justify-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
          </div>

          <!-- Empty State -->
          <div v-else-if="!disputeData?.messages || disputeData.messages.length === 0" class="text-center py-8">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-3.582 8-8 8a8.955 8.955 0 01-2.126-.275c-1.15-.29-2.046-1.186-2.336-2.336A8.955 8.955 0 018 21c-4.418 0-8-3.582-8-8s3.582-8 8-8 8 3.582 8 8z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">沒有聊天記錄</h3>
            <p class="mt-1 text-sm text-gray-500">此任務暫無雙方對話記錄</p>
          </div>

          <!-- 聊天記錄列表 -->
          <div v-else class="space-y-4 overflow-y-auto" style="max-height: 400px;">
            <div
              v-for="message in disputeData.messages"
              :key="message.id"
              class="flex"
              :class="message.sender_role === 'creator' ? 'justify-start' : 'justify-end'"
            >
              <div class="flex max-w-xs lg:max-w-md">
                <!-- 創建者消息 (左側) -->
                <div v-if="message.sender_role === 'creator'" class="flex items-start space-x-2">
                  <div class="flex-shrink-0">
                    <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                      <span class="text-white text-xs font-medium">A</span>
                    </div>
                  </div>
                  <div>
                    <div class="bg-gray-100 rounded-lg px-3 py-2">
                      <p class="text-sm text-gray-900">{{ message.content }}</p>
                    </div>
                    <div class="mt-1 text-xs text-gray-500">
                      {{ message.sender_name }} · {{ formatDateTime(message.created_at) }}
                    </div>
                  </div>
                </div>

                <!-- 參與者消息 (右側) -->
                <div v-else-if="message.sender_role === 'participant'" class="flex items-start space-x-2 flex-row-reverse">
                  <div class="flex-shrink-0">
                    <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                      <span class="text-white text-xs font-medium">B</span>
                    </div>
                  </div>
                  <div>
                    <div class="bg-indigo-500 text-white rounded-lg px-3 py-2">
                      <p class="text-sm">{{ message.content }}</p>
                    </div>
                    <div class="mt-1 text-xs text-gray-500 text-right">
                      {{ message.sender_name }} · {{ formatDateTime(message.created_at) }}
                    </div>
                  </div>
                </div>

                <!-- 其他用戶消息 -->
                <div v-else class="flex items-start space-x-2">
                  <div class="flex-shrink-0">
                    <div class="w-8 h-8 bg-gray-400 rounded-full flex items-center justify-center">
                      <span class="text-white text-xs font-medium">?</span>
                    </div>
                  </div>
                  <div>
                    <div class="bg-yellow-100 border border-yellow-200 rounded-lg px-3 py-2">
                      <p class="text-sm text-gray-900">{{ message.content }}</p>
                    </div>
                    <div class="mt-1 text-xs text-gray-500">
                      {{ message.sender_name }} · {{ formatDateTime(message.created_at) }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
          <button
            type="button"
            @click="$emit('close')"
            class="w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:w-auto sm:text-sm"
          >
            關閉
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { disputeApi } from '@/services/api'

interface Props {
  show: boolean
  disputeId: number | null
}

interface Emits {
  (e: 'close'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const loading = ref(false)
const disputeData = ref<any>(null)

// 監聽 disputeId 變化，載入聊天記錄
watch(() => props.disputeId, async (newDisputeId) => {
  if (newDisputeId && props.show) {
    await loadDisputeChatMessages(newDisputeId)
  }
}, { immediate: true })

// 監聽 show 變化
watch(() => props.show, async (newShow) => {
  if (newShow && props.disputeId) {
    await loadDisputeChatMessages(props.disputeId)
  }
})

const loadDisputeChatMessages = async (disputeId: number) => {
  try {
    loading.value = true
    
    const response = await disputeApi.getChatMessages(disputeId)
    
    if (response.data.success && response.data.data) {
      disputeData.value = response.data.data
    } else {
      throw new Error(response.data.message || 'Failed to load dispute chat messages')
    }
  } catch (error: any) {
    console.error('Failed to load dispute chat messages:', error)
    
    // 顯示錯誤訊息
    const message = error.response?.data?.message || error.message || 'Failed to load chat messages'
    alert(`錯誤：${message}`)
  } finally {
    loading.value = false
  }
}

const formatDateTime = (dateTimeStr: string) => {
  const date = new Date(dateTimeStr)
  return date.toLocaleString('zh-TW', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>
