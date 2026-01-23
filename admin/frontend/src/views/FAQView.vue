<template>
    <!-- 頁面標題和操作按鈕 -->
    <div class="flex justify-between items-center">
      <h1 class="text-2xl font-semibold text-gray-900">FAQ Management</h1>
      <button
      @click="openCreateModal"
      class="px-4 py-2 bg-cyan-600 text-white rounded-md hover:bg-cyan-700 transition-colors duration-200 flex items-center"
      >
      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
      </svg>
      Add New FAQ
    </button>
  </div>
  
    <!-- Loading -->
    <div v-if="loading" class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-cyan-600"></div>
      <p class="mt-2 text-gray-600">Loading...</p>
    </div>

    <!-- FAQ List -->
    <div v-else class="bg-white shadow rounded-lg overflow-hidden">
      <!-- 編輯排序模式切換 -->
      <div
        class="px-6 py-4 border-b border-gray-200 flex justify-between items-center"
        :class="isEditMode ? 'bg-cyan-50' : 'bg-gray-50'"
      >
        <div class="text-sm text-gray-600">
          Total:
          <span class="font-semibold">
            {{ isEditMode ? '[Move to reorder items]' : faqs.length }}
          </span>
          <span v-if="!isEditMode"> FAQs</span>
        </div>
        <button
          type="button"
          @click="toggleEditMode"
          class="px-4 py-2 rounded-md transition-colors duration-200 flex items-center"
          :class="isEditMode ? 'bg-teal-600 text-white hover:bg-teal-700' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'"
          :disabled="savingOrder"
        >
        <template v-if="isEditMode">
            <svg v-if="savingOrder" class="w-4 h-4 mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            <transition name="fade">
              <span v-if="saveOrderSuccess" class="inline-flex items-center">
                <svg class="w-4 h-4 mr-2 text-green-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                <span>Saved!</span>
              </span>
            </transition>
            <span v-if="!savingOrder && !saveOrderSuccess" class="inline-flex items-center">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
              </svg>
              <span>Save Order</span>
            </span>
            <span v-if="savingOrder">Saving...</span>
          </template>
          <template v-else>
            <svg class="w-4 h-4 mr-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <circle cx="6" cy="6" r="1.5" />
              <circle cx="6" cy="12" r="1.5" />
              <circle cx="6" cy="18" r="1.5" />
              <circle cx="12" cy="6" r="1.5" />
              <circle cx="12" cy="12" r="1.5" />
              <circle cx="12" cy="18" r="1.5" />
              <circle cx="18" cy="6" r="1.5" />
              <circle cx="18" cy="12" r="1.5" />
              <circle cx="18" cy="18" r="1.5" />
            </svg>
            <span>Reorder</span>
          </template>
        </button>
      </div>

      <!-- FAQ 項目 -->
      <div class="divide-y divide-gray-200">
        <div
          v-for="(faq, index) in faqs"
          :key="faq.id"
          class="px-6 py-4 transition-all duration-200 bg-white"
          :class="{
            'hover:bg-gray-50': !isEditMode,
            'active:bg-cyan-50': isEditMode && draggedIndex === index,
            'opacity-50': isEditMode && draggedIndex === index,
            'bg-cyan-50 border-l-4 border-cyan-500': isEditMode && dragOverIndex === index && draggedIndex !== index,
            'cursor-move': isEditMode
          }"
          :draggable="isEditMode"
          @dragstart="handleDragStart(index, $event)"
          @dragenter.prevent="handleDragEnter(index)"
          @dragover.prevent="handleDragOver(index)"
          @dragleave="handleDragLeave(index)"
          @drop="handleDrop()"
          @dragend="handleDragEnd"
        >
          <div class="flex items-start justify-between">
            <!-- FAQ 內容 -->
            <div class="flex-1">
              <div class="flex items-center space-x-3">
                <!-- 拖曳圖標（編輯模式） -->
                <div v-if="isEditMode" class="cursor-move text-orange-300">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
                  </svg>
                </div>
                
                <!-- 問題 -->
                <div class="flex-1">
                  <h3 class="text-base font-medium text-gray-900">{{ faq.question }}</h3>
                  <p class="mt-1 text-sm text-gray-600 line-clamp-2">{{ faq.answer }}</p>
                </div>
              </div>

              <!-- 狀態和排序 -->
              <div class="mt-2 flex items-center space-x-4 text-xs text-gray-500">
                <span class="flex items-center">
                  <span class="font-semibold">Order:</span> 
                  <span class="ml-1 px-2 py-0.5 bg-gray-100 rounded">{{ faq.sort_order }}</span>
                </span>
                <div class="flex items-center space-x-2">
                  <span
                    class="px-2 py-0.5 rounded-full text-xs font-medium"
                    :class="faq.is_active 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-gray-100 text-gray-600 cursor-help'"
                    :title="faq.is_active ? '' : 'Inactive items will not be displayed in the Here4Help App'"
                  >
                    {{ faq.is_active ? 'Active' : 'Inactive' }}
                  </span>
                  <!-- Toggle Switch -->
                  <label v-if="!isEditMode" class="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      :checked="faq.is_active"
                      @change="toggleActive(faq)"
                      class="sr-only peer"
                    />
                    <div class="relative w-9 h-5 rounded-full transition-colors duration-200" :class="faq.is_active ? 'bg-cyan-600' : 'bg-gray-200'">
                      <div class="absolute top-[2px] left-[2px] bg-white rounded-full h-4 w-4 transition-all duration-200 shadow-sm" :class="faq.is_active ? 'translate-x-4' : 'translate-x-0'"></div>
                    </div>
                  </label>
                </div>
              </div>
            </div>

            <!-- 操作按鈕 -->
            <div v-if="!isEditMode" class="flex items-center space-x-3 ml-4">
              <button
                @click="openEditModal(faq)"
                class="p-2 text-cyan-600 hover:bg-cyan-50 rounded-md transition-colors duration-200"
                title="Edit"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>
              
              <button
                @click="deleteFAQ(faq)"
                class="p-2 text-red-600 hover:bg-red-50 rounded-md transition-colors duration-200"
                title="Delete"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Empty State -->
      <div v-if="!loading && faqs.length === 0" class="px-6 py-12 text-center">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No FAQs</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by creating a new FAQ.</p>
      </div>
    </div>

    <!-- Edit/Create Modal -->
    <FAQEditModal
      v-if="showModal"
      :faq="editingFAQ"
      @close="closeModal"
      @save="handleSave"
    />
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import FAQEditModal from '@/components/FAQEditModal.vue'
import api from '@/services/api'
import { API_ENDPOINTS } from '@/config/api'
import type { FAQ } from '@/types/faq'

type PersistedFAQ = FAQ & { id: number }

const faqs = ref<PersistedFAQ[]>([])
const loading = ref(false)
const showModal = ref(false)
const editingFAQ = ref<PersistedFAQ | null>(null)
const isEditMode = ref(false)
const draggedIndex = ref<number | null>(null)
const dragOverIndex = ref<number | null>(null)
const originalDragIndex = ref<number | null>(null) // 保存原始拖曳索引
const savingOrder = ref(false)
const saveOrderSuccess = ref(false)

const loadFAQs = async () => {
  loading.value = true
  try {
    const response = await api.get(API_ENDPOINTS.faq.list())
    // 確保 items 陣列存在，並驗證每個 FAQ 都有有效的 ID
    faqs.value = (response.data.data?.items || response.data.data || [])
      .map((faq: any, idx: number) => ({
        ...faq,
        id: faq.id ? Number(faq.id) : undefined,
        // 後端返回的 0/1 或 '0'/'1' 正規化為 boolean，避免 toggle 判斷錯誤
        is_active: faq.is_active === true || faq.is_active === 1 || faq.is_active === '1',
        sort_order: faq.sort_order ? Number(faq.sort_order) : idx + 1,
      }))
      .filter((faq: any) => faq.id !== undefined)
  } catch (error) {
    console.error('Failed to load FAQs:', error)
    alert('Failed to load FAQs')
  } finally {
    loading.value = false
  }
}

const openCreateModal = () => {
  editingFAQ.value = null
  showModal.value = true
}

const openEditModal = (faq: PersistedFAQ) => {
  editingFAQ.value = { ...faq }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingFAQ.value = null
}

const handleSave = async (faqData: FAQ) => {
  try {
    if (editingFAQ.value?.id) {
      // Update existing FAQ
      await api.put(API_ENDPOINTS.faq.update(editingFAQ.value.id), faqData)
    } else {
      // Create new FAQ
      await api.post(API_ENDPOINTS.faq.create(), faqData)
    }
    await loadFAQs()
    closeModal()
  } catch (error) {
    console.error('Failed to save FAQ:', error)
    alert('Failed to save FAQ')
  }
}

const toggleActive = async (faq: PersistedFAQ) => {
  if (!faq.id) {
    console.error('FAQ ID is missing')
    alert('Invalid FAQ: missing ID')
    return
  }
  
  // 樂觀更新：立即更新 UI
  const previousState = faq.is_active
  const targetIndex = faqs.value.findIndex(f => f.id === faq.id)
  if (targetIndex !== -1) {
    faqs.value[targetIndex].is_active = !previousState
  }
  
  try {
    const response = await api.put(API_ENDPOINTS.faq.update(faq.id), {
      ...faq,
      is_active: !previousState
    })
    
    // 檢查 API 回應是否成功
    if (!response.data.success) {
      // 如果失敗，恢復原狀態
      if (targetIndex !== -1) {
        faqs.value[targetIndex].is_active = previousState
      }
      throw new Error(response.data.message || 'Failed to update FAQ status')
    }
  } catch (error: any) {
    // 恢復原狀態
    if (targetIndex !== -1) {
      faqs.value[targetIndex].is_active = previousState
    }
    console.error('Failed to toggle FAQ status:', error)
    alert(`Failed to update FAQ status: ${error.response?.data?.message || error.message || 'Unknown error'}`)
  }
}

const deleteFAQ = async (faq: PersistedFAQ) => {
  if (!faq.id) {
    console.error('FAQ ID is missing')
    alert('Invalid FAQ: missing ID')
    return
  }
  
  if (!confirm(`Are you sure you want to delete this FAQ: "${faq.question}"? \n\n🚫 This action cannot be reverted.🚫`)) {
    return
  }
  
  try {
    await api.delete(API_ENDPOINTS.faq.destroy(faq.id))
    await loadFAQs()
  } catch (error) {
    console.error('Failed to delete FAQ:', error)
    alert('Failed to delete FAQ')
  }
}

const toggleEditMode = async () => {
  if (isEditMode.value) {
    // Save the new order
    savingOrder.value = true
    saveOrderSuccess.value = false
    
    try {
      const faqsWithOrder = faqs.value.map((faq, index) => ({
        id: faq.id,
        sort_order: index + 1  // 從 1 開始，而不是 0
      }))
      
      const response = await api.post(API_ENDPOINTS.faq.updateOrder(), { items: faqsWithOrder })
      
      // 檢查 API 回應是否成功
      if (response.data.success) {
        saveOrderSuccess.value = true
        await loadFAQs()
        
        // 1秒後重置成功狀態並退出編輯模式
        setTimeout(() => {
          saveOrderSuccess.value = false
          isEditMode.value = false
        }, 1000)
      } else {
        throw new Error(response.data.message || 'Failed to save order')
      }
    } catch (error: any) {
      console.error('Failed to update FAQ order:', error)
      savingOrder.value = false
      saveOrderSuccess.value = false
      alert(`Failed to update FAQ order: ${error.response?.data?.message || error.message || 'Unknown error'}`)
    } finally {
      // 確保按鈕恢復可用狀態
      savingOrder.value = false
    }
  } else {
    isEditMode.value = true
    saveOrderSuccess.value = false
  }
}

const handleDragStart = (index: number, event: DragEvent) => {
  originalDragIndex.value = index
  draggedIndex.value = index
  dragOverIndex.value = null
  
  // 設置拖曳圖像
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
  }
}

const handleDragEnter = (index: number) => {
  if (draggedIndex.value === null || draggedIndex.value === index) return
  dragOverIndex.value = index
  updateVisualOrder(index)
}

const handleDragOver = (index: number) => {
  if (draggedIndex.value === null || draggedIndex.value === index) return
  
  if (dragOverIndex.value !== index) {
    dragOverIndex.value = index
    updateVisualOrder(index)
  }
}

const updateVisualOrder = (targetIndex: number) => {
  if (draggedIndex.value === null || originalDragIndex.value === null) return
  
  // 從當前陣列開始計算（因為順序已經在變化）
  const newFaqs = [...faqs.value]
  const currentDragIndex = draggedIndex.value
  const draggedFAQ = newFaqs[currentDragIndex]
  
  // 移除被拖曳的項目
  newFaqs.splice(currentDragIndex, 1)
  
  // 計算插入位置
  let insertIndex = targetIndex
  if (currentDragIndex < targetIndex) {
    // 向下拖曳，目標索引需要減1（因為已經移除了項目）
    insertIndex = targetIndex
  } else {
    // 向上拖曳，直接使用目標索引
    insertIndex = targetIndex
  }
  
  // 插入到新位置
  newFaqs.splice(insertIndex, 0, draggedFAQ)
  faqs.value = newFaqs
  
  // 更新被拖曳項目的索引
  draggedIndex.value = insertIndex
}

const handleDragLeave = (index: number) => {
  // 延遲清除，避免快速移動時閃爍
  setTimeout(() => {
    if (dragOverIndex.value === index) {
      dragOverIndex.value = null
    }
  }, 50)
}

const handleDrop = () => {
  // 順序已經在 updateVisualOrder 中更新了，這裡只需要清理狀態
  draggedIndex.value = null
  dragOverIndex.value = null
  originalDragIndex.value = null
}

const handleDragEnd = () => {
  // 清理所有拖曳相關狀態
  draggedIndex.value = null
  dragOverIndex.value = null
  originalDragIndex.value = null
}

onMounted(() => {
  loadFAQs()
})
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.fade-enter-to,
.fade-leave-from {
  opacity: 1;
}
</style>
