<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">官方銀行帳戶</h2>
        <p class="mt-1 text-sm text-gray-500">僅一組 active 生效</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="load" class="admin-button-secondary" :disabled="loading">Refresh</button>
      </div>
    </div>

    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">銀行名稱</label>
          <input v-model="form.bank_name" type="text" class="admin-input" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">帳號</label>
          <input v-model="form.account_number" type="text" class="admin-input" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">戶名</label>
          <input v-model="form.account_name" type="text" class="admin-input" />
        </div>
      </div>
      <div class="mt-4">
        <button @click="save" class="admin-button-primary" :disabled="loading || !valid">Save as active</button>
      </div>
    </div>

    <div class="admin-card">
      <h3 class="text-lg font-medium text-gray-900 mb-4">歷史帳戶</h3>
      <div v-if="loading" class="text-gray-500">Loading...</div>
      <div v-else-if="items.length === 0" class="text-gray-500">No records</div>
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>銀行</th>
              <th>帳號</th>
              <th>戶名</th>
              <th>狀態</th>
              <th>建立時間</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="it in items" :key="it.id">
              <td>{{ it.bank_name }}</td>
              <td>{{ it.account_number }}</td>
              <td>{{ it.account_holder }}</td>
              <td>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="it.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'">
                  {{ it.is_active ? 'active' : 'inactive' }}
                </span>
              </td>
              <td>{{ formatDate(it.created_at) }}</td>
            </tr>
          </tbody>
        </table>
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

const save = async () => {
  if (!valid.value) return
  loading.value = true
  try {
    await paymentApi.setOfficialAccount(form.value)
    await load()
  } finally {
    loading.value = false
  }
}

const formatDate = (d?: string) => (d ? new Date(d).toLocaleString() : '-')

onMounted(load)
</script>


