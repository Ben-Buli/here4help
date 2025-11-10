<template>
  <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <!-- Header -->
      <div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center sticky top-0 bg-white">
        <h2 class="text-xl font-semibold text-gray-900">
          {{ isEdit ? 'Edit FAQ' : 'Create New FAQ' }}
        </h2>
        <button
          @click="$emit('close')"
          class="text-gray-400 hover:text-gray-500 transition-colors duration-200"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Body -->
      <div class="px-6 py-4 space-y-6">
        <!-- 問題 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Question <span class="text-red-500">*</span>
          </label>
          <input
            v-model="formData.question"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            placeholder="Enter question"
          />
        </div>

        <!-- 答案 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Answer <span class="text-red-500">*</span>
          </label>
          <textarea
            v-model="formData.answer"
            rows="4"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent resize-none"
            placeholder="Enter answer"
          ></textarea>
        </div>

        <!-- 語言和分類 -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Language
            </label>
            <select
              v-model="formData.language"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            >
              <option value="en">English (en)</option>
              <option value="zh-TW">繁體中文 (zh-TW)</option>
              <option value="zh-CN">简体中文 (zh-CN)</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Category
            </label>
            <input
              v-model="formData.category"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
              placeholder="General"
            />
          </div>
        </div>

        <!-- 排序和狀態 -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Sort Order
            </label>
            <input
              v-model.number="formData.sort_order"
              type="number"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Status
            </label>
            <div class="flex items-center h-10">
              <label class="flex items-center cursor-pointer">
                <input
                  v-model="formData.is_active"
                  type="checkbox"
                  class="w-4 h-4 text-cyan-600 border-gray-300 rounded focus:ring-cyan-500"
                />
                <span class="ml-2 text-sm text-gray-700">Active</span>
              </label>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="px-6 py-4 border-t border-gray-200 flex justify-end space-x-3 sticky bottom-0 bg-white">
        <button
          @click="$emit('close')"
          class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition-colors duration-200"
        >
          Cancel
        </button>
        <button
          @click="handleSave"
          :disabled="!isValid"
          class="px-4 py-2 bg-cyan-600 text-white rounded-md hover:bg-cyan-700 transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {{ isEdit ? 'Update' : 'Create' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'

interface FAQ {
  id?: number
  question: string
  answer: string
  category?: string
  language?: string
  sort_order: number
  is_active: boolean
}

const props = defineProps<{
  faq: FAQ | null
}>()

const emit = defineEmits<{
  close: []
  save: [faq: FAQ]
}>()

const formData = ref<FAQ>({
  question: '',
  answer: '',
  category: 'General',
  language: 'en',
  sort_order: 0,
  is_active: true,
})

const isEdit = computed(() => !!props.faq?.id)

const isValid = computed(() => {
  return formData.value.question.trim() !== '' && 
         formData.value.answer.trim() !== ''
})

watch(() => props.faq, (newFAQ) => {
  if (newFAQ) {
    formData.value = { ...newFAQ }
  } else {
    formData.value = {
      question: '',
      answer: '',
      category: 'General',
      language: 'en',
      sort_order: 0,
      is_active: true,
    }
  }
}, { immediate: true })

const handleSave = () => {
  if (!isValid.value) return
  emit('save', formData.value)
}
</script>

