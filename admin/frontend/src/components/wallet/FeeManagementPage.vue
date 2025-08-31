<template>
  <div class="space-y-6">
    <!-- 頁面標題與操作 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Task Completion Fee Management
        </h2>
        <p class="mt-1 text-sm text-gray-500">
          Only the active setting takes effect
        </p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="load" class="admin-button-secondary" :disabled="loading">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- 當前設定 -->
    <div class="admin-card">
      <div class="flex items-end space-x-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Fee Percentage (%)</label>
          <input 
            v-model.number="percentage" 
            type="number" 
            min="0" 
            max="100" 
            step="0.1" 
            class="admin-input w-40" 
            placeholder="0.0"
          />
        </div>
        <button 
          @click="save" 
          class="admin-button-primary" 
          :disabled="loading || percentage === null || percentage < 0"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M5 13l4 4L19 7"
            />
          </svg>
          Save as active
        </button>
      </div>
      
      <!-- 計算範例 -->
      <div v-if="percentage !== null && percentage > 0" class="mt-4 p-4 bg-blue-50 rounded-md">
        <h4 class="text-sm font-medium text-blue-900 mb-2">Calculation Example</h4>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
          <div>
            <span class="text-blue-700">Task Reward:</span>
            <span class="font-medium">1,000 Points</span>
          </div>
          <div>
            <span class="text-blue-700">Fee:</span>
            <span class="font-medium">{{ calculateFee(1000) }} Points</span>
          </div>
          <div>
            <span class="text-blue-700">Publisher Pays:</span>
            <span class="font-medium">{{ 1000 + calculateFee(1000) }} Points</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 歷史設定 -->
    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">History Settings</h3>
        <div class="text-sm text-gray-500">
          {{ items.length }} Records
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <!-- Empty State -->
      <div v-else-if="items.length === 0" class="text-center py-8">
        <svg
          class="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"
          />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No Fee Settings</h3>
        <p class="mt-1 text-sm text-gray-500">No fee settings have been configured yet.</p>
      </div>

      <!-- Settings Table -->
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Percentage</th>
              <th>Status</th>
              <th>Created Time</th>
              <th>Updated Time</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="item in items" :key="item.id" class="hover:bg-gray-50">
              <td class="text-sm font-medium text-gray-900">
                {{ item.percentage }}%
              </td>
              <td>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="item.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'"
                >
                  {{ item.is_active ? 'Active' : 'Inactive' }}
                </span>
              </td>
              <td class="text-sm text-gray-500">
                {{ formatDate(item.created_at) }}
              </td>
              <td class="text-sm text-gray-500">
                {{ formatDate(item.updated_at) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { paymentApi } from '@/services/api'

// State
const loading = ref(false)
const items = ref<any[]>([])
const percentage = ref<number | null>(null)

// 載入手續費設定
const load = async () => {
  loading.value = true
  try {
    const res = await paymentApi.getFeeSettings()
    if (res.data.success && res.data.data) {
      items.value = res.data.data.items || []
      const active = items.value.find((it: any) => it.is_active)
      percentage.value = active ? Number(active.percentage) : null
    }
  } catch (error) {
    console.error('Failed to load fee settings:', error)
  } finally {
    loading.value = false
  }
}

// 儲存手續費設定
const save = async () => {
  if (percentage.value === null || percentage.value < 0) return
  
  loading.value = true
  try {
    await paymentApi.setFeeSettings(percentage.value)
    await load() // 重新載入以更新列表
  } catch (error) {
    console.error('Failed to save fee settings:', error)
  } finally {
    loading.value = false
  }
}

// 計算手續費
const calculateFee = (amount: number) => {
  if (percentage.value === null || percentage.value <= 0) return 0
  return Math.round(amount * (percentage.value / 100))
}

// 格式化日期
const formatDate = (dateString?: string) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleString()
}

// 初始化
onMounted(() => {
  load()
})
</script>
