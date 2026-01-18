<template>
  <div class="space-y-6">
    <transition name="toast-fade">
      <div
        v-if="toastMessage"
        class="fixed right-6 top-6 z-50 max-w-sm rounded-lg border px-4 py-3 text-sm font-medium shadow-lg"
        :class="toastClasses"
      >
        {{ toastMessage?.message }}
      </div>
    </transition>
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
          <div class="relative w-40">
            <input 
              v-model.number="percentage" 
              type="number" 
              min="0" 
              max="100" 
              step="0.1" 
              class="admin-input w-full pr-8" 
              placeholder="0.0"
            />
            <span class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none select-none">%</span>
          </div>
        </div>
       
        <button 
          @click="save" 
          class="admin-button-primary" 
          :disabled="loading || percentage === null || percentage < 0"
        >
          <!-- <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M5 13l4 4L19 7"
            />
          </svg> -->
          Update
        </button>
      </div>
      
      <!-- 計算範例 -->
      <div class="mt-4 p-4 rounded-md bg-blue-50">
        <h4 class="text-sm font-medium text-blue-900 mb-2">Fee Rate Application Explanation</h4>
        <p class="text-sm text-gray-800">
          <span v-if="percentage !== null">
            After updating this setting, the configured fee rate will be applied to user withdrawal requests submitted from now on. 
            Users will incur an additional fee based on the newly set rate for each withdrawal they make.<br>
            For example: If a user requests to withdraw <strong>{{ exampleWithdrawPoints }}</strong> points, an additional fee of <strong>{{ exampleFeePoints }}</strong> points ({{ percentageDisplay }}) will be charged as a transaction fee.
          </span>
          <span v-else>
            No effective fee rate is set yet. Please save a fee rate to see how it will be applied.
          </span>
        </p>
        <div
          v-if="percentage !== null"
          class="mt-3 grid grid-cols-1 gap-2 text-sm text-gray-700 bg-white p-3 rounded-lg border border-blue-100"
        >
          <p>
            For example: If a user requests to withdraw <strong>{{ exampleWithdrawPoints }}</strong> points, the platform will deduct an additional fee of <strong>{{ exampleFeePoints }}</strong> points ({{ percentageDisplay }}) from the withdrawal. 
          </p>
          <p>
            The user will actually receive <strong>{{ exampleReceivePoints }}</strong> points. The field <code>total_deduct_points</code> will display the total deduction of <strong>{{ exampleWithdrawPoints }}</strong> points (including the fee), and the system will record <strong>{{ exampleFeePoints }}</strong> points in the <code>fee_points</code> field as the platform fee.
          </p>
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
              <th>Setting Date</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="item in items" :key="item.id" class="hover:bg-gray-50">
              <td class="text-sm font-medium text-gray-900">
                {{ formatPercentage(item.percentage) }}%
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
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { paymentApi } from '@/services/api'

// State
const loading = ref(false)
const items = ref<any[]>([])
const percentage = ref<number | null>(null)
const toastMessage = ref<{ message: string; type: 'success' | 'error' } | null>(null)
let toastTimer: ReturnType<typeof setTimeout> | null = null

const toastClasses = computed(() => {
  if (!toastMessage.value) return ''
  return toastMessage.value.type === 'success'
    ? 'bg-green-50 border-green-200 text-green-800'
    : 'bg-red-50 border-red-200 text-red-800'
})

const showToast = (message: string, type: 'success' | 'error' = 'success') => {
  toastMessage.value = { message, type }
  if (toastTimer) {
    clearTimeout(toastTimer)
  }
  toastTimer = setTimeout(() => {
    toastMessage.value = null
    toastTimer = null
  }, 4000)
}

const buildBackendErrorMessage = (error: any) => {
  const baseMessage =
    error?.response?.data?.message || error?.message || 'Failed to update fee setting'
  const laravelLog = error?.response?.data?.laravel_log
  return laravelLog ? `${baseMessage}（Laravel log: ${laravelLog}）` : baseMessage
}

const normalizePercentage = (value: any): number | null => {
  if (value === null || value === undefined) return null
  const num = Number(value)
  return Number.isNaN(num) ? null : num
}

// 載入手續費設定
const load = async () => {
  loading.value = true
  try {
    const res = await paymentApi.getFeeSettings()
    if (res.data.success && res.data.data) {
      const rows = res.data.data.items || []
      items.value = rows.map((item: any) => {
        const percentageValue =
          normalizePercentage(item.percentage) ??
          (item.rate !== undefined && item.rate !== null ? Number(item.rate) * 100 : null)

        return {
          ...item,
          percentage: percentageValue,
          rate: item.rate ?? (percentageValue !== null ? percentageValue / 100 : null),
        }
      })
      const active = items.value.find((it: any) => it.is_active)
      percentage.value = active ? normalizePercentage(active.percentage) : null
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
    const res = await paymentApi.setFeeSettings(percentage.value)
    showToast(res.data.message || 'Fee setting updated', 'success')
    await load() // 重新載入以更新列表
  } catch (error) {
    console.error('Failed to save fee settings:', error)
    showToast(buildBackendErrorMessage(error), 'error')
  } finally {
    loading.value = false
  }
}

// 計算手續費
const calculateFee = (amount: number) => {
  if (percentage.value === null || percentage.value <= 0) return 0
  return Math.round(amount * (percentage.value / 100))
}

const exampleWithdrawPoints = 100
const exampleFeePoints = computed(() => calculateFee(exampleWithdrawPoints))
const exampleReceivePoints = computed(() =>
  Math.max(exampleWithdrawPoints - exampleFeePoints.value, 0),
)
const percentageDisplay = computed(() =>
  percentage.value !== null ? `${percentage.value.toFixed(2)}%` : '—',
)

const formatPercentage = (value?: number | null) => {
  if (value === null || value === undefined || Number.isNaN(value)) return '-'
  return Number(value).toFixed(2)
}

// 格式化日期
const formatDate = (dateString?: string) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleString()
}

// 初始化
onUnmounted(() => {
  if (toastTimer) {
    clearTimeout(toastTimer)
    toastTimer = null
  }
})
onMounted(() => {
  load()
})
</script>
