<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">Referral Codes</h2>
        <p class="mt-1 text-sm text-gray-500">View each user’s invite code and intro referral code</p>
      </div>
    </div>

    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Name / Email / Code</label>
          <input
            v-model="filters.search"
            type="text"
            placeholder="Search keyword..."
            class="admin-input"
            @input="debouncedSearch"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">User ID</label>
          <input
            v-model="filters.user_id"
            type="number"
            min="1"
            placeholder="e.g. 1024"
            class="admin-input"
            @input="debouncedSearch"
          />
        </div>
      <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Per Page</label>
          <select v-model.number="filters.per_page" class="admin-input" @change="handlePerPageChange">
            <option value="10">10</option>
            <option value="20">20</option>
            <option value="50">50</option>
            <option value="100">100</option>
          </select>
        </div>
        <div>
        <!-- <div class="flex items-end">
          <button class="admin-button-secondary" @click="resetFilters">Reset</button>
        </div> -->
      </div>
      </div>
    </div>

    <div class="admin-card overflow-x-auto">
      <table class="min-w-full w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="admin-th cursor-pointer" @click="setSort('id')">
              <span class="flex items-center gap-1">
                ID
                <span class="inline-flex flex-col leading-none">
                  <svg
                    class="w-3 h-3"
                    :class="sortIconClass('id', 'desc')"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                  <svg
                    class="w-3 h-3 -mt-1"
                    :class="sortIconClass('id', 'asc')"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </span>
              </span>
            </th>
            <th class="admin-th cursor-pointer" @click="setSort('name')">
              <span class="flex items-center gap-1">
                Name
                <span class="inline-flex flex-col leading-none">
                  <svg class="w-3 h-3" :class="sortIconClass('name', 'desc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                  <svg class="w-3 h-3 -mt-1" :class="sortIconClass('name', 'asc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </span>
              </span>
            </th>
            <!-- <th class="admin-th cursor-pointer" @click="setSort('email')">Email</th> -->
            <th class="admin-th cursor-pointer" @click="setSort('permission')">
              <span class="flex items-center gap-1">
                Permission
                <span class="inline-flex flex-col leading-none">
                  <svg class="w-3 h-3" :class="sortIconClass('permission', 'desc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                  <svg class="w-3 h-3 -mt-1" :class="sortIconClass('permission', 'asc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </span>
              </span>
            </th>
            <th class="admin-th cursor-pointer" @click="setSort('referral_code')">
              <span class="flex items-center gap-1">
                Invite Code
                <span class="inline-flex flex-col leading-none">
                  <svg class="w-3 h-3" :class="sortIconClass('referral_code', 'desc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                  <svg class="w-3 h-3 -mt-1" :class="sortIconClass('referral_code', 'asc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </span>
              </span>
            </th>
            <th class="admin-th cursor-pointer" @click="setSort('intro_referral_code')">
              <span class="flex items-center gap-1">
                Referral Code
                <span class="inline-flex flex-col leading-none">
                  <svg class="w-3 h-3" :class="sortIconClass('intro_referral_code', 'desc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                  <svg class="w-3 h-3 -mt-1" :class="sortIconClass('intro_referral_code', 'asc')" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </span>
              </span>
            </th>
            <!-- <th class="admin-th cursor-pointer" @click="setSort('updated_at')">Updated At</th> -->
            <th class="admin-th text-right">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-if="loading">
            <td colspan="6" class="px-6 py-6 text-center text-gray-500">Loading...</td>
          </tr>
          <tr v-else-if="records.length === 0">
            <td colspan="6" class="px-6 py-6 text-center text-gray-500">No records</td>
          </tr>
          <tr v-for="record in records" :key="record.id">
            <td class="admin-td font-medium text-gray-900">{{ record.id }}</td>
            <td class="admin-td">
              <div class="font-medium text-gray-900">{{ record.name || '—' }}</div>
            </td>
            <!-- <td class="admin-td text-gray-600">{{ record.email }}</td> -->
            <td class="admin-td">
              <span class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold"
                :class="getPermissionBadgeClass(record.permission)">
                <!-- {{ getPermissionText(record.permission) }} ({{ record.permission }}) -->
                {{ getPermissionText(record.permission) }} 
              </span>
            </td>
            <td class="admin-td font-mono text-sm">
              <span v-if="record.referral_code"
                class="inline-flex items-center rounded-full bg-gray-100 px-3 py-0.5 text-xs font-semibold text-gray-700"
              >{{ record.referral_code }}</span>
              <span v-else class="inline-flex items-center rounded-full bg-gray-100 px-3 py-0.5 text-xs font-semibold text-gray-400">—</span>
            </td>
            <td class="admin-td font-mono text-sm">
              <span v-if="record.intro_referral_code"
                class="inline-flex items-center rounded-full bg-gray-100 px-3 py-0.5 text-xs font-semibold text-gray-700"
              >{{ record.intro_referral_code }}</span>
              <span v-else class="inline-flex items-center rounded-full bg-gray-100 px-3 py-0.5 text-xs font-semibold text-gray-400">—</span>
            </td>
            <!-- <td class="admin-td text-sm text-gray-500">{{ formatDate(record.updated_at) }}</td> -->
            <td class="admin-td text-right">
              <button class="text-cyan-600 hover:text-cyan-900 text-sm font-semibold" @click="goUser(record.id)">
                View user
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="flex items-center justify-between">
      <div class="text-sm text-gray-600">
        Showing
        <span class="font-medium">{{ pagination.current_page }}</span>
        of
        <span class="font-medium">{{ pagination.last_page }}</span>
        • Total {{ pagination.total }} users
      </div>
      <div class="flex gap-2">
        <button class="admin-button-secondary text-sm" :disabled="pagination.current_page === 1" @click="changePage(pagination.current_page - 1)">
          Previous
        </button>
        <button
          class="admin-button-secondary text-sm"
          :disabled="pagination.current_page === pagination.last_page"
          @click="changePage(pagination.current_page + 1)"
        >
          Next
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import api, { type ApiResponse } from '@/services/api'
import { API_ENDPOINTS } from '@/config/api'

interface ReferralRecord {
  id: number
  name: string | null
  email: string
  permission: number
  referral_code: string | null
  intro_referral_code: string | null
  updated_at: string
}

const router = useRouter()
const records = ref<ReferralRecord[]>([])
const loading = ref(false)
const pagination = reactive({
  current_page: 1,
  per_page: 20,
  total: 0,
  last_page: 1,
})

const filters = reactive({
  search: '',
  user_id: '',
  sort_by: 'updated_at',
  sort_order: 'desc',
  page: 1,
  per_page: 20,
})

const loadRecords = async (page = filters.page) => {
  loading.value = true
  filters.page = page
  try {
    const params = {
      page: filters.page,
      per_page: filters.per_page,
      sort_by: filters.sort_by,
      sort_order: filters.sort_order,
      search: filters.search || undefined,
      user_id: filters.user_id || undefined,
    }
    const response = await api.get<ApiResponse<{ items: ReferralRecord[]; pagination: typeof pagination }>>(
      API_ENDPOINTS.users.referralCodes(),
      { params },
    )
    const payload = response.data.data
    records.value = payload?.items ?? []
    if (payload?.pagination) {
      Object.assign(pagination, payload.pagination)
    }
  } catch (error) {
    console.error('Failed to load referral codes', error)
  } finally {
    loading.value = false
  }
}

let searchTimeout: number
const debouncedSearch = () => {
  if (searchTimeout) {
    clearTimeout(searchTimeout)
  }
  searchTimeout = window.setTimeout(() => loadRecords(1), 500)
}

const setSort = (field: string) => {
  if (filters.sort_by === field) {
    filters.sort_order = filters.sort_order === 'asc' ? 'desc' : 'asc'
  } else {
    filters.sort_by = field
    filters.sort_order = 'desc'
  }
  loadRecords(1)
}

const handlePerPageChange = () => {
  filters.page = 1
  loadRecords()
}

const changePage = (page: number) => loadRecords(page)

const goUser = (id: number) => {
  router.push(`/users/${id}`)
}

const sortIconClass = (field: string, direction: 'asc' | 'desc') => {
  const isFieldActive = filters.sort_by === field
  if (!isFieldActive) return 'text-gray-300'
  const isDirectionActive = filters.sort_order === direction
  return isDirectionActive ? 'text-cyan-600' : 'text-gray-400'
}

const getPermissionBadgeClass = (permission: number) => {
  if (permission >= 99) return 'bg-purple-100 text-purple-800'
  if (permission >= 1) return 'bg-green-100 text-green-800'
  if (permission === 0) return 'bg-yellow-100 text-yellow-800'
  if (permission === -1) return 'bg-yellow-100 text-yellow-900'
  if (permission === -2) return 'bg-orange-100 text-orange-800'
  if (permission === -3) return 'bg-red-100 text-red-800'
  if (permission === -4) return 'bg-gray-100 text-gray-500'
  return 'bg-gray-100 text-gray-700'
}

const getPermissionText = (permission: number) => {
  if (permission >= 99) return 'Master User'
  if (permission >= 1) return 'Verified User'
  if (permission === 0) return 'New User in Verification'
  if (permission === -1) return 'Admin Suspended'
  if (permission === -2) return 'Admin Soft Deleted'
  if (permission === -3) return 'Self Suspended'
  if (permission === -4) return 'Self Soft Deleted'
  return `Level ${permission}`
}

loadRecords()
</script>
