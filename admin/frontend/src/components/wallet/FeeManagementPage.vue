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
          Withdraw Fee Management
        </h2>
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
          <label class="block text-sm font-medium text-gray-700 mb-1">Fee Percentage (%) <span class="text-red-500 text-sm">*</span></label>
          <div class="relative w-40">
            <input 
              v-model="percentageInput" 
              type="text" 
              class="admin-input w-full pr-8" 
              placeholder="0.0"
              @input="handlePercentageInput"
              @keypress="handleKeyPress"
              required
            />
            <span class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none select-none">%</span>
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Minimum Withdraw (points) <span class="text-red-500 text-sm">*</span></label>
          <div class="relative w-48">
            <input
              v-model="minWithdrawInput"
              type="text"
              class="admin-input w-full"
              placeholder="Required"
              @input="handleMinWithdrawInput"
              @keypress="handleMinWithdrawKeyPress"
              required
            />
          </div>
        </div>
      
      <div class="flex-1">
          <label class="block text-sm font-medium text-gray-700 mb-1">Description <span class="text-red-500 text-sm">*</span></label>
          <input
            maxlength="255"
            type="text"
            v-model="description"
            class="admin-input w-full"
            placeholder="Enter a description for this fee setting"
            required
          />
        </div>
       
        <button
          @click="save"
          class="admin-button-primary"
        >
          Apply
        </button>
      </div>
      
      <!-- 計算範例 -->
      <div class="mt-4 p-4 rounded-md bg-blue-50">
        <h4 class="text-sm font-medium text-blue-900 mb-2">How Withdrawal Fees Work</h4>
        <p class="text-sm text-gray-800">
          <span v-if="percentage !== null">
            This fee rate applies to all user withdrawal requests. When a user requests to withdraw points, the platform will charge an additional transaction fee based on this percentage. Users must also meet the configured minimum withdrawal threshold.<br><br>
            <strong>Example:</strong> If a user requests to withdraw <strong>{{ exampleWithdrawPoints }}</strong> points with a fee rate of {{ percentageDisplay }}, the platform will charge an additional <strong>{{ exampleFeePoints }}</strong> points as a transaction fee.
          </span>
          <span v-else>
            No withdrawal fee rate is currently configured. Set a fee rate above to see how it will be applied to user withdrawals.
          </span>
        </p>
        <div
          v-if="percentage !== null"
          class="mt-3 grid grid-cols-1 gap-2 text-sm text-gray-700 bg-white p-3 rounded-lg border border-blue-100"
        >
          <h4 class="font-medium text-gray-900 mb-2">Withdrawal Fee Calculation Example:</h4>
          <div class="font-mono text-sm space-y-1">
            <div class="flex justify-between items-center">
              <span class="text-gray-600">User Requested:</span>
              <span class="font-semibold text-gray-900">{{ exampleWithdrawPoints }} points</span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-gray-600">Platform Fee ({{ percentageDisplay }}):</span>
              <span class="font-semibold text-gray-900">+ {{ exampleFeePoints }} points</span>
            </div>
            <div class="border-t border-gray-300 my-1"></div>
            <div class="flex justify-between items-center">
              <span class="text-gray-600">Total Deducted:</span>
              <span class="font-semibold text-red-500">{{ exampleWithdrawPoints + exampleFeePoints }} points </span>
              
             
            </div>
            <div class="border-t border-gray-300 my-1"></div>
            <div class="flex justify-between items-center">
              <span class="text-gray-600">User Finally Receives:</span>
              <span class="font-semibold text-yellow-500">NT$ {{ exampleReceivePoints }} (TWD)</span>
            </div>
          </div>
          <p class="mt-3 text-xs text-gray-600">
            <strong>Note:</strong> The fee is calculated from the withdrawal amount and added to the total deduction. Users must meet the minimum withdraw threshold and have sufficient balance to cover both the withdrawal amount and the fee.
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
      <div v-else class="max-h-[480px] overflow-x-auto overflow-y-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Percentage</th>
              <th>Minimum</th>
              <th>Status</th>
              <th>Description</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="item in items" :key="item.id" class="hover:bg-gray-50">
              <td class="text-sm font-medium text-gray-900">
                {{ formatPercentage(item.percentage) }}%
              </td>
              <td class="text-sm text-gray-700">
                {{ formatMinWithdraw(item.min_withdraw_points) }}
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
                {{ item.description }}
              </td>
              <td class="text-sm text-gray-500">
                <small class="text-xs text-gray-500">{{ formatDate(item.created_at).split(' ')[0] }}</small>
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
const percentageInput = ref<string>('')
const minWithdrawPoints = ref<number | null>(null)
const minWithdrawInput = ref<string>('')
const description = ref<string>('')
const toastMessage = ref<{ message: string; type: 'success' | 'error' | 'warning' } | null>(null)
let toastTimer: ReturnType<typeof setTimeout> | null = null

const toastClasses = computed(() => {
  if (!toastMessage.value) return ''
  if (toastMessage.value.type === 'success') return 'bg-green-50 border-green-200 text-green-800'
  if (toastMessage.value.type === 'warning') return 'bg-yellow-50 border-yellow-200 text-yellow-800'
  if (toastMessage.value.type === 'error') return 'bg-red-50 border-red-200 text-red-800'
  return 'bg-gray-50 border-gray-200 text-gray-800'
})

const showToast = (message: string, type: 'success' | 'warning' | 'error') => {
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

// 獲取當前 active 的百分比值
const activePercentage = computed(() => {
  const active = items.value.find((it: any) => it.is_active)
  return active ? normalizePercentage(active.percentage) : null
})

const activeMinWithdrawPoints = computed(() => {
  const active = items.value.find((it: any) => it.is_active)
  if (!active) return null
  const raw = active.min_withdraw_points
  if (raw === null || raw === undefined) return null
  const parsed = Number(raw)
  return Number.isNaN(parsed) ? null : parsed
})

// 處理輸入，只允許數字和小數點
const handlePercentageInput = (event: Event) => {
  const target = event.target as HTMLInputElement
  let value = target.value
  
  // 如果為空，設為空字符串
  if (value === '') {
    percentageInput.value = ''
    percentage.value = null
    return
  }
  
  // 只允許數字和小數點
  value = value.replace(/[^0-9.]/g, '')
  
  // 確保只有一個小數點
  const parts = value.split('.')
  if (parts.length > 2) {
    value = parts[0] + '.' + parts.slice(1).join('')
  }
  
  // 限制小數點後最多2位
  if (parts.length === 2 && parts[1].length > 2) {
    value = parts[0] + '.' + parts[1].substring(0, 2)
  }
  
  // 限制最大值為100
  const numValue = parseFloat(value)
  if (!isNaN(numValue) && numValue > 100) {
    value = '100'
  }
  
  percentageInput.value = value
  const num = parseFloat(value)
  percentage.value = isNaN(num) || value === '' ? null : num
}

// 處理鍵盤輸入，阻止非數字和小數點的字符
const handleKeyPress = (event: KeyboardEvent) => {
  const char = event.key
  // 允許：數字、小數點、退格、刪除、Tab、方向鍵等
  if (
    /[0-9.]/.test(char) ||
    ['Backspace', 'Delete', 'Tab', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'].includes(char) ||
    (event.ctrlKey || event.metaKey) // 允許 Ctrl/Cmd + A, C, V 等
  ) {
    // 如果已經有小數點，阻止再次輸入小數點
    if (char === '.' && percentageInput.value.includes('.')) {
      event.preventDefault()
    }
    return
  }
  event.preventDefault()
}

// 處理最低提領輸入，只允許整數
const handleMinWithdrawInput = (event: Event) => {
  const target = event.target as HTMLInputElement
  let value = target.value

  if (value === '') {
    minWithdrawInput.value = ''
    minWithdrawPoints.value = null
    return
  }

  value = value.replace(/[^0-9]/g, '')
  minWithdrawInput.value = value
  const num = parseInt(value, 10)
  minWithdrawPoints.value = Number.isNaN(num) ? null : num
}

const handleMinWithdrawKeyPress = (event: KeyboardEvent) => {
  const char = event.key
  if (
    /[0-9]/.test(char) ||
    ['Backspace', 'Delete', 'Tab', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'].includes(char) ||
    (event.ctrlKey || event.metaKey)
  ) {
    return
  }
  event.preventDefault()
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
      const activeValue = active ? normalizePercentage(active.percentage) : null
      percentage.value = activeValue
      percentageInput.value = activeValue !== null ? activeValue.toString() : ''

      const activeMin = active?.min_withdraw_points
      const minValue =
        activeMin === null || activeMin === undefined ? null : Number(activeMin)
      minWithdrawPoints.value = minValue
      minWithdrawInput.value = minValue !== null && !Number.isNaN(minValue) ? String(minValue) : ''
      description.value = active?.description ?? ''
    }
  } catch (error) {
    console.error('Failed to load fee settings:', error)
  } finally {
    loading.value = false
  }
}

// 儲存手續費設定
const save = async () => {
  if (loading.value) return
  if (percentage.value === null || percentage.value === undefined || Number.isNaN(Number(percentage.value))) {
    alert('Fee percentage is required.')
    return
  }
  if (Number(percentage.value) < 0) {
    alert('Fee percentage cannot be negative.')
    return
  }
  if (minWithdrawPoints.value === null || Number.isNaN(minWithdrawPoints.value)) {
    alert('Minimum withdraw is required.')
    return
  }
  if (!description.value.trim()) {
    alert('Description is required.')
    return
  }

  const num = Number(percentage.value)
  if (Number.isNaN(num) || num < 0) {
    alert('Fee percentage is invalid.')
    return
  }
  const minPoints = Number(minWithdrawPoints.value)

  // 檢查是否與當前 active 值一致
  if (
    activePercentage.value !== null &&
    Math.abs(num - activePercentage.value) < 0.01 &&
    activeMinWithdrawPoints.value !== null &&
    activeMinWithdrawPoints.value === minPoints
  ) {
    alert('Fee percentage and minimum withdraw already match the current active settings.')
    return
  }

  if (minPoints === 0) {
    const zeroConfirmMessage =
      'Minimum withdraw is set to 0. This will allow withdrawals of any size.\n\nAre you sure you want to continue?'
    if (!confirm(zeroConfirmMessage)) {
      return
    }
  }

  // 二次確認對話框
  const confirmMessage = `Are you sure you want to update the withdrawal fee settings?\n\n⚠️ WARNING: This change will affect the platform's fee policy and withdrawal rules. All user withdrawal requests submitted after this update will apply these settings.\n\nCurrent active rate: ${activePercentage.value !== null ? activePercentage.value.toFixed(2) + '%' : 'None'}\nNew rate: ${num.toFixed(2)}%\n\nCurrent minimum withdraw: ${activeMinWithdrawPoints.value !== null ? activeMinWithdrawPoints.value : 'Not set'}\nNew minimum withdraw: ${minPoints}\n\nDescription: ${description.value.trim()}\n\nPlease confirm to proceed with this update.`
  
  if (!confirm(confirmMessage)) {
    return
  }

  loading.value = true
  try {
    const res = await paymentApi.setFeeSettings(num, minPoints, description.value.trim())
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
  if (percentage.value === null || percentage.value === undefined || percentage.value <= 0) return 0
  const num = Number(percentage.value)
  if (Number.isNaN(num)) return 0
  return Math.round(amount * (num / 100))
}

const exampleWithdrawPoints = computed(() => {
  if (minWithdrawPoints.value === null || Number.isNaN(minWithdrawPoints.value)) {
    return 100
  }
  return Math.max(0, Math.trunc(minWithdrawPoints.value))
})

const exampleMinimumWithdraw = computed(() => {
  if (minWithdrawPoints.value === null || Number.isNaN(minWithdrawPoints.value)) {
    return 0
  }
  return Math.max(0, Math.trunc(minWithdrawPoints.value))
})

const exampleFeePoints = computed(() => calculateFee(exampleWithdrawPoints.value))
const exampleReceivePoints = computed(() => exampleWithdrawPoints.value)
const percentageDisplay = computed(() => {
  if (percentage.value === null || percentage.value === undefined) return '—'
  const num = Number(percentage.value)
  if (Number.isNaN(num)) return '—'
  return `${num.toFixed(2)}%`
})

const formatPercentage = (value?: number | null) => {
  if (value === null || value === undefined || Number.isNaN(value)) return '-'
  return Number(value).toFixed(2)
}

const formatMinWithdraw = (value?: number | null) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return 'Not set'
  return Number(value).toLocaleString()
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
