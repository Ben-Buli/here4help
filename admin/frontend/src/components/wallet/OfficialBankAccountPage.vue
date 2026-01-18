<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">Official Bank Account</h2>
        <p class="mt-1 text-sm text-gray-500">Only one active account is effective</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="load" class="admin-button-secondary" :disabled="loading">Refresh</button>
      </div>
    </div>

    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Bank Name</label>
          <input v-model="form.bank_name" type="text" class="admin-input" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Account Number</label>
          <input v-model="form.account_number" type="text" class="admin-input" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Account Name</label>
          <input v-model="form.account_name" type="text" class="admin-input" />
        </div>
      </div>
      <div class="mt-4">
        <button @click="showConfirmDialog = true" class="admin-button-primary" :disabled="loading || !valid">Set new official bank account</button>
      </div>
    </div>

    <div class="admin-card">
      <h3 class="text-lg font-medium text-gray-900 mb-4">History Accounts</h3>
      <div v-if="loading" class="text-gray-500">Loading...</div>
      <div v-else-if="items.length === 0" class="text-gray-500">No records</div>
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Bank Name</th>
              <th>Account Number</th>
              <th>Account Name</th>
              <th>Status</th>
              <th>Created At</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="it in items" :key="it.id">
              <td>{{ it.bank_name }}</td>
              <td>{{ it.account_number }}</td>
              <td>{{ it.account_holder }}</td>
              <td>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="it.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'">
                  {{ it.is_active == 1 ? 'Active' : 'Inactive' }}
                </span>
              </td>
              <td>{{ formatDate(it.created_at) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 確認對話框 -->
    <div v-if="showConfirmDialog" class="fixed inset-0 z-[9999] overflow-y-auto">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 transition-opacity" @click="showConfirmDialog = false">
          <div class="absolute inset-0 bg-gray-500 opacity-75"></div>
        </div>

        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full relative z-10">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="sm:flex sm:items-start">
              <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100 sm:mx-0 sm:h-10 sm:w-10">
                <svg class="h-6 w-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"></path>
                </svg>
              </div>
              <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                  Confirm Official Bank Account Update
                </h3>
                
                <div class="bg-gray-50 rounded-md p-4 mb-4">
                  <p class="text-sm text-gray-700 mb-2"><strong>This will set the following as the active official bank account:</strong></p>
                  <div class="space-y-1 text-sm">
                    <p><strong>Bank Name:</strong> {{ form.bank_name }}</p>
                    <p><strong>Account Number:</strong> {{ form.account_number }}</p>
                    <p><strong>Account Name:</strong> {{ form.account_name }}</p>
                  </div>
                </div>

                <div class="bg-yellow-50 border border-yellow-200 rounded-md p-3">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-yellow-700">
                        <strong>Warning:</strong> This will deactivate any previously active bank account and set this as the new official account for receiving deposits.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button 
              @click="confirmSave" 
              :disabled="loading"
              class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ loading ? 'Saving...' : 'Confirm & Save' }}
            </button>
            <button 
              @click="showConfirmDialog = false" 
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 訊息提示 -->
    <div v-if="showMessage" class="fixed top-4 right-4 z-[10000] max-w-sm">
      <div 
        class="rounded-md p-4 shadow-lg"
        :class="message.type === 'success' ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'"
      >
        <div class="flex">
          <div class="flex-shrink-0">
            <svg 
              v-if="message.type === 'success'"
              class="h-5 w-5 text-green-400" 
              fill="currentColor" 
              viewBox="0 0 20 20"
            >
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
            </svg>
            <svg 
              v-else
              class="h-5 w-5 text-red-400" 
              fill="currentColor" 
              viewBox="0 0 20 20"
            >
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
            </svg>
          </div>
          <div class="ml-3">
            <p 
              class="text-sm font-medium"
              :class="message.type === 'success' ? 'text-green-800' : 'text-red-800'"
            >
              {{ message.text }}
            </p>
          </div>
          <div class="ml-auto pl-3">
            <div class="-mx-1.5 -my-1.5">
              <button 
                @click="showMessage = false"
                class="inline-flex rounded-md p-1.5 focus:outline-none focus:ring-2 focus:ring-offset-2"
                :class="message.type === 'success' ? 'text-green-500 hover:bg-green-100 focus:ring-green-600' : 'text-red-500 hover:bg-red-100 focus:ring-red-600'"
              >
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { paymentApi } from '@/services/api'

const loading = ref(false)
const items = ref<any[]>([])
const form = ref({ bank_name: '', account_number: '', account_name: '' })
const showConfirmDialog = ref(false)
const message = ref({ type: '', text: '' })
const showMessage = ref(false)

const valid = computed(() => form.value.bank_name && form.value.account_number && form.value.account_name)

const load = async () => {
  loading.value = true
  try {
    const res = await paymentApi.getOfficialAccounts()
    if (res.data.success && res.data.data) {
      items.value = res.data.data.items || []
      const active = items.value.find((it: any) => it.is_active)
      if (active) {
        form.value = {
          bank_name: active.bank_name,
          account_number: active.account_number,
          account_name: active.account_holder,
        }
      }
    }
  } finally {
    loading.value = false
  }
}

const confirmSave = async () => {
  if (!valid.value) return
  
  loading.value = true
  try {
    const response = await paymentApi.setOfficialAccount(form.value)
    
    if (response.data.success) {
      // 成功提示
      message.value = { type: 'success', text: 'Official bank account updated successfully!' }
      showMessage.value = true
      showConfirmDialog.value = false
      await load()
      
      // 3秒後自動隱藏成功訊息
      setTimeout(() => {
        showMessage.value = false
      }, 3000)
    } else {
      throw new Error(response.data.message || 'Failed to update official account')
    }
  } catch (error: any) {
    console.error('Failed to save official account:', error)
    
    // 錯誤提示
    const errorMessage = error.response?.data?.message || error.message || 'Failed to save official account'
    message.value = { type: 'error', text: errorMessage }
    showMessage.value = true
    
    // 5秒後自動隱藏錯誤訊息
    setTimeout(() => {
      showMessage.value = false
    }, 5000)
  } finally {
    loading.value = false
  }
}

const formatDate = (d?: string) => (d ? new Date(d).toLocaleString() : '-')

onMounted(load)
</script>

