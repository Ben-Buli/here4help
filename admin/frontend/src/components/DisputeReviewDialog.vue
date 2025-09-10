<template>
  <div class="fixed inset-0 z-50 overflow-y-auto" v-if="show">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
      <!-- 背景遮罩 -->
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" @click="$emit('close')"></div>

      <!-- Dialog 內容 -->
      <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
          <div class="sm:flex sm:items-start">
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg class="h-6 w-6 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                爭議處理 - {{ dispute?.dispute_title || `爭議 #${dispute?.id}` }}
              </h3>
              <div class="mt-2">
                <div class="text-sm text-gray-500 space-y-2">
                  <p><strong>任務：</strong>{{ dispute?.task?.title || 'N/A' }}</p>
                  <p><strong>獎勵：</strong>{{ dispute?.task?.reward_point || dispute?.task?.reward || 0 }} 點數</p>
                  <p><strong>提交者：</strong>{{ dispute?.submitter?.name || 'N/A' }}</p>
                  <p><strong>狀態：</strong>{{ getStatusDisplayName(dispute?.status) }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 決定選項 -->
        <div class="bg-gray-50 px-4 py-3 sm:px-6">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">處理決定</label>
              <div class="space-y-2">
                <label class="flex items-center">
                  <input
                    type="radio"
                    v-model="decision"
                    value="completed"
                    class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300"
                  />
                  <span class="ml-2 text-sm text-gray-900">
                    <span class="font-medium text-green-600">完成 (Completed)</span>
                    - 任務判定完成，自動審核並完成轉移點數流程
                  </span>
                </label>
                <label class="flex items-center">
                  <input
                    type="radio"
                    v-model="decision"
                    value="reject"
                    class="h-4 w-4 text-yellow-600 focus:ring-yellow-500 border-gray-300"
                  />
                  <span class="ml-2 text-sm text-gray-900">
                    <span class="font-medium text-yellow-600">駁回 (Reject)</span>
                    - 駁回爭議，任務回到進行中狀態
                  </span>
                </label>
                <label class="flex items-center">
                  <input
                    type="radio"
                    v-model="decision"
                    value="restart"
                    class="h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300"
                  />
                  <span class="ml-2 text-sm text-gray-900">
                    <span class="font-medium text-red-600">重新開始 (Restart)</span>
                    - 移除參與者，任務回到開放狀態
                  </span>
                </label>
              </div>
            </div>

            <div>
              <label for="review-note" class="block text-sm font-medium text-gray-700">處理說明</label>
              <textarea
                id="review-note"
                v-model="note"
                rows="3"
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                placeholder="請輸入處理說明..."
              ></textarea>
            </div>
          </div>
        </div>

        <!-- 按鈕 -->
        <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
          <button
            type="button"
            @click="handleSubmit"
            :disabled="!decision || isSubmitting"
            class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg v-if="isSubmitting" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ isSubmitting ? '處理中...' : '確認處理' }}
          </button>
          <button
            type="button"
            @click="$emit('close')"
            :disabled="isSubmitting"
            class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { disputeApi } from '@/services/api'

interface Props {
  show: boolean
  dispute: any
}

interface Emits {
  (e: 'close'): void
  (e: 'resolved'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const decision = ref('')
const note = ref('')
const isSubmitting = ref(false)

const getStatusDisplayName = (status: string) => {
  switch (status) {
    case 'submitted':
      return '已提交'
    case 'in_progress':
      return '處理中'
    case 'resolved':
      return '已解決'
    default:
      return status
  }
}

const handleSubmit = async () => {
  if (!decision.value) {
    alert('請選擇處理決定')
    return
  }

  try {
    isSubmitting.value = true

    const response = await disputeApi.resolve(
      props.dispute.id,
      decision.value,
      note.value.trim()
    )

    if (response.data.success) {
      // 顯示成功訊息
      const actionText = {
        completed: '任務已標記為完成，點數轉移流程已啟動',
        reject: '爭議已駁回，任務回到進行中狀態',
        restart: '任務已重新開始，參與者已移除'
      }[decision.value] || '處理完成'

      alert(`處理成功：${actionText}`)
      
      emit('resolved')
      emit('close')
    } else {
      throw new Error(response.data.message || '處理失敗')
    }
  } catch (error: any) {
    console.error('Failed to resolve dispute:', error)
    const message = error.response?.data?.message || error.message || '處理失敗'
    alert(`錯誤：${message}`)
  } finally {
    isSubmitting.value = false
  }
}
</script>
