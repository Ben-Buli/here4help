<template>
  <div class="space-y-6">
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
        Add FAQ
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
      <div class="px-6 py-4 border-b border-gray-200 bg-gray-50 flex justify-between items-center">
        <div class="text-sm text-gray-600">
          Total: <span class="font-semibold">{{ faqs.length }}</span> FAQs
        </div>
        <button
          @click="toggleEditMode"
          class="px-4 py-2 rounded-md transition-colors duration-200 flex items-center"
          :class="isEditMode ? 'bg-cyan-600 text-white hover:bg-cyan-700' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
          </svg>
          {{ isEditMode ? 'Save Order' : 'Reorder' }}
        </button>
      </div>

      <!-- FAQ 項目 -->
      <div class="divide-y divide-gray-200">
        <div
          v-for="(faq, index) in faqs"
          :key="faq.id"
          class="px-6 py-4 hover:bg-gray-50 transition-colors duration-150"
          :draggable="isEditMode"
          @dragstart="handleDragStart(index)"
          @dragover.prevent
          @drop="handleDrop(index)"
        >
          <div class="flex items-start justify-between">
            <!-- FAQ 內容 -->
            <div class="flex-1">
              <div class="flex items-center space-x-3">
                <!-- 拖曳圖標（編輯模式） -->
                <div v-if="isEditMode" class="cursor-move text-gray-400">
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
                <span
                  class="px-2 py-0.5 rounded-full text-xs font-medium"
                  :class="faq.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'"
                >
                  {{ faq.is_active ? 'Active' : 'Inactive' }}
                </span>
              </div>
            </div>

            <!-- 操作按鈕 -->
            <div v-if="!isEditMode" class="flex items-center space-x-2 ml-4">
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
                @click="toggleActive(faq)"
                class="p-2 text-gray-600 hover:bg-gray-100 rounded-md transition-colors duration-200"
                :title="faq.is_active ? 'Deactivate' : 'Activate'"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path v-if="faq.is_active" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path v-if="!faq.is_active" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
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
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import FAQEditModal from '@/components/FAQEditModal.vue'
import api from '@/services/api'

interface FAQ {
  id: number
  question: string
  answer: string
  category?: string
  language?: string
  sort_order: number
  is_active: boolean
}

const faqs = ref<FAQ[]>([])
const loading = ref(false)
const showModal = ref(false)
const editingFAQ = ref<FAQ | null>(null)
const isEditMode = ref(false)
const draggedIndex = ref<number | null>(null)

const loadFAQs = async () => {
  loading.value = true
  try {
    const response = await api.get('/admin/faqs')
    faqs.value = response.data.data
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

const openEditModal = (faq: FAQ) => {
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
      await api.put(`/admin/faqs/${editingFAQ.value.id}`, faqData)
    } else {
      // Create new FAQ
      await api.post('/admin/faqs', faqData)
    }
    await loadFAQs()
    closeModal()
  } catch (error) {
    console.error('Failed to save FAQ:', error)
    alert('Failed to save FAQ')
  }
}

const toggleActive = async (faq: FAQ) => {
  try {
    await api.put(`/admin/faqs/${faq.id}`, {
      ...faq,
      is_active: !faq.is_active
    })
    await loadFAQs()
  } catch (error) {
    console.error('Failed to toggle FAQ status:', error)
    alert('Failed to update FAQ status')
  }
}

const deleteFAQ = async (faq: FAQ) => {
  if (!confirm(`Are you sure you want to delete this FAQ: "${faq.question}"?`)) {
    return
  }
  
  try {
    await api.delete(`/admin/faqs/${faq.id}`)
    await loadFAQs()
  } catch (error) {
    console.error('Failed to delete FAQ:', error)
    alert('Failed to delete FAQ')
  }
}

const toggleEditMode = async () => {
  if (isEditMode.value) {
    // Save the new order
    try {
      const faqsWithOrder = faqs.value.map((faq, index) => ({
        id: faq.id,
        sort_order: index
      }))
      await api.post('/admin/faqs/update-order', { items: faqsWithOrder })
      await loadFAQs()
    } catch (error) {
      console.error('Failed to update FAQ order:', error)
      alert('Failed to update FAQ order')
    }
  }
  isEditMode.value = !isEditMode.value
}

const handleDragStart = (index: number) => {
  draggedIndex.value = index
}

const handleDrop = (dropIndex: number) => {
  if (draggedIndex.value === null || draggedIndex.value === dropIndex) return
  
  const draggedFAQ = faqs.value[draggedIndex.value]
  faqs.value.splice(draggedIndex.value, 1)
  faqs.value.splice(dropIndex, 0, draggedFAQ)
  
  draggedIndex.value = null
}

onMounted(() => {
  loadFAQs()
})
</script>

