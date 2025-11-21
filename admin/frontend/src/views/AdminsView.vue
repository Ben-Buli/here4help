<template>
  <div class="space-y-6">
    <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-gray-900">Admin Accounts</h1>
        <p class="text-gray-500">View every admin profile and manually issue password reset links when needed.</p>
      </div>
    </div>

    <div class="admin-card space-y-5">
      <div class="flex flex-col gap-3 md:flex-row md:items-center">
        <div class="flex-1">
          <input
            v-model="filters.search"
            @input="handleSearchInput"
            type="text"
            placeholder="Search name, email, or username"
            class="admin-input"
          />
        </div>
        <div class="flex flex-col gap-2 md:flex-row md:items-center">
          <!-- <select v-model="filters.role" class="admin-input md:w-48">
            <option value="">All roles</option>
            <option v-for="role in roleOptions" :key="role.value" :value="role.value">
              {{ role.label }}
            </option>
          </select>
          <select v-model="filters.status" class="admin-input md:w-40">
            <option value="">All status</option>
            <option v-for="status in statusOptions" :key="status.value" :value="status.value">
              {{ status.label }}
            </option>
          </select> -->
          <!-- <div class="flex gap-2">
            <button class="admin-button-primary" @click="applyFilters" :disabled="isLoading">
              {{ isLoading ? 'Loading…' : 'Apply' }}
            </button>
            <button class="admin-button-secondary" @click="resetFilters" :disabled="isLoading">
              Reset
            </button>
          </div> -->
        </div>
      </div>

      <div class="relative">
        <div v-if="isLoading" class="absolute inset-0 bg-white/70 flex items-center justify-center rounded-xl">
          <div class="animate-spin h-8 w-8 border-2 border-primary-500 border-t-transparent rounded-full"></div>
        </div>
        <div class="overflow-x-auto">
          <table class="admin-table min-w-full">
            <thead>
              <tr>
                <th class="w-16">ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Last Login</th>
                <th v-if="canIssueResetLinks" class="w-56">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!admins.length">
                <td colspan="7" class="py-6 text-center text-gray-500">No administrators found.</td>
              </tr>
              <tr v-for="admin in admins" :key="admin.id">
                <td class="font-mono text-sm text-gray-500">#{{ admin.id }}</td>
                <td>
                  <div class="font-semibold text-gray-900">{{ admin.full_name }}</div>
                  <div class="text-sm text-gray-500">{{ admin.username }}</div>
                </td>
                <td class="text-sm text-gray-600">
                  <a class="text-primary-600" :href="`mailto:${admin.email}`">{{ admin.email }}</a>
                </td>
                <td>
                  <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-slate-100 text-slate-700">
                    {{ admin.role.display_name || admin.role.name || 'Unassigned' }}
                  </span>
                </td>
                <td>
                  <span
                    class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                    :class="statusBadgeClass(admin.status)"
                  >
                    {{ formatStatus(admin.status) }}
                  </span>
                </td>
                <td>
                  <div class="text-sm text-gray-900">{{ formatDateTime(admin.last_login) }}</div>
                  <div v-if="admin.locked_until" class="text-xs text-red-600">Locked until {{ formatDateTime(admin.locked_until) }}</div>
                </td>
                <td v-if="canIssueResetLinks">
                  <button
                    class="admin-button-secondary w-full"
                    :disabled="!canResetAdmin(admin) || isLoadingReset"
                    @click="requestResetLink(admin)"
                  >
                    {{ canResetAdmin(admin) ? 'Reset Password' : 'Not Authorized' }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <p v-if="actionError" class="text-sm text-red-600">{{ actionError }}</p>
    </div>

    <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
      <p class="text-sm text-gray-500">
        Showing
        <span class="font-semibold text-gray-900">
          {{ admins.length ? (pagination.per_page * (pagination.current_page - 1) + 1) : 0 }}-
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }}
        </span>
        of
        <span class="font-semibold text-gray-900">{{ pagination.total }}</span>
      </p>
      <div class="flex gap-2">
        <button class="admin-button-secondary" :disabled="pagination.current_page === 1 || isLoading" @click="changePage(-1)">
          Previous
        </button>
        <button
          class="admin-button-secondary"
          :disabled="pagination.current_page === pagination.last_page || isLoading"
          @click="changePage(1)"
        >
          Next
        </button>
      </div>
    </div>

    <transition name="fade">
      <div
        v-if="showResetModal && selectedAdmin"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-2 md:px-4"
        @click="closeResetModal"
      >
        <div class="relative bg-white rounded-2xl shadow-2xl max-w-xl w-full p-4 sm:p-6" @click.stop>
          <button class="absolute top-4 right-4 text-gray-400 hover:text-gray-600" @click="closeResetModal">✕</button>
          <div class="space-y-4">
            <div>
              <h2 class="text-xl font-semibold text-gray-900">Manual Password Reset</h2>
              <p class="text-sm text-gray-500">Share the details below with {{ selectedAdmin.full_name }}.</p>
            </div>

            <div v-if="isLoadingReset" class="py-12 text-center text-gray-500">
              Generating secure link…
            </div>

            <template v-else-if="resetLinkInfo">
              <div v-if="resetLinkInfo.was_existing_link" class="text-xs text-amber-700 bg-amber-50 border border-amber-100 rounded-xl px-3 py-2">
                An active link already existed for this admin. Please send the same link again.
              </div>

             
              <p class="text-sm font-semibold text-gray-900">Reset Notification Message:</p>
              <div class="relative bg-gray-50 border border-gray-200 rounded-2xl p-4 overflow-x-auto">
                <button class="absolute top-3 right-3 flex items-center gap-1 text-gray-500 hover:text-gray-900"
                  @click="copyResetMessage" :title="resetCopyTooltip">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V5a4 4 0 118 0v2m-9 4h10a2 2 0 012 2v6a2 2 0 01-2 2H7a2 2 0 01-2-2v-6a2 2 0 012-2z" />
                  </svg>
                  <span class="text-xs">{{ resetCopyTooltip }}</span>
                </button>
                <pre class="font-mono text-sm whitespace-pre-wrap break-words pr-10">{{ resetMessage }}</pre>
              </div>

              <p class="text-xs text-gray-500">
                Shared by <span class="font-semibold text-gray-700">{{ currentAdminName }}</span>
              </p>
              <p class="text-xs text-gray-500">Expires {{ formatDateTime(resetLinkInfo.expires_at) }} ({{ resetCountdown || 'Expired' }})</p>

              <div class="space-y-1 text-sm">
                <p class="text-gray-500">Reset link</p>
                <a :href="resetLinkInfo.reset_link" target="_blank" rel="noopener"
                  class="text-primary-600 break-all block">
                  {{ resetLinkInfo.reset_link }}
                </a>
              </div>
            </template>

            <p v-if="resetModalError" class="text-sm text-red-600">{{ resetModalError }}</p>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { adminAccountsApi, type AdminAccount, type AdminPasswordResetLinkResponse } from '@/services/api'
import { useAuthStore } from '@/stores/auth'

const admins = ref<AdminAccount[]>([])
const pagination = reactive({ current_page: 1, per_page: 10, total: 0, last_page: 1 })
const filters = reactive({ search: '', role: '', status: '' })
const isLoading = ref(false)
const isLoadingReset = ref(false)
const actionError = ref('')
const resetModalError = ref('')
const showResetModal = ref(false)
const selectedAdmin = ref<AdminAccount | null>(null)
const resetLinkInfo = ref<AdminPasswordResetLinkResponse | null>(null)
const resetCopyTooltip = ref('Copy')
const resetCountdown = ref('')

let countdownTimer: number | null = null
let copyTimer: number | null = null
let searchDebounceTimer: number | null = null

const authStore = useAuthStore()

const roleOptions = [
  { value: 'super_admin', label: 'Super Admin' },
  { value: 'admin', label: 'Admin' },
  { value: 'moderator', label: 'Moderator' },
  { value: 'developer', label: 'Developer' },
  { value: 'support', label: 'Support' },
]

const statusOptions = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'suspended', label: 'Suspended' },
  { value: 'locked', label: 'Locked' },
]

const currentAdminRole = computed(() => authStore.user?.role?.name || '')
const currentAdminName = computed(() => authStore.user?.full_name || authStore.user?.username || 'Here4Help Admin')
const canIssueResetLinks = computed(() => {
  const role = currentAdminRole.value
  return role === 'super_admin' || role === 'developer'
})

const canResetAdmin = (admin: AdminAccount): boolean => {
  const role = currentAdminRole.value
  if (!role || !['super_admin', 'developer'].includes(role)) {
    return false
  }
  if (role === 'super_admin' && admin.role.name === 'developer') {
    return false
  }
  return true
}

const formatStatus = (status?: string | null) => {
  if (!status) return 'Unknown'
  return status.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase())
}

const statusBadgeClass = (status?: string | null) => {
  switch (status) {
    case 'active':
      return 'bg-green-100 text-green-800'
    case 'inactive':
      return 'bg-gray-100 text-gray-600'
    case 'suspended':
      return 'bg-orange-100 text-orange-700'
    case 'locked':
      return 'bg-red-100 text-red-700'
    default:
      return 'bg-gray-100 text-gray-600'
  }
}

const formatDateTime = (value?: string | null) => {
  if (!value) return 'Never'
  const date = new Date(value)
  return date.toLocaleString()
}

const loadAdmins = async () => {
  isLoading.value = true
  actionError.value = ''
  try {
    const response = await adminAccountsApi.list({
      page: pagination.current_page,
      per_page: pagination.per_page,
      search: filters.search || undefined,
      role: filters.role || undefined,
      status: filters.status || undefined,
    })

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || 'Failed to fetch admins')
    }

    admins.value = response.data.data.items || []
    const meta = response.data.data.pagination
    if (meta) {
      pagination.current_page = Number(meta.current_page)
      pagination.per_page = Number(meta.per_page)
      pagination.total = Number(meta.total)
      pagination.last_page = Number(meta.last_page)
    }
  } catch (error: any) {
    actionError.value = error?.response?.data?.message || error.message || 'Failed to fetch admins'
  } finally {
    isLoading.value = false
  }
}

const applyFilters = () => {
  pagination.current_page = 1
  loadAdmins()
}

const handleSearchInput = () => {
  // 清除之前的計時器
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
  }
  // 設置新的防抖計時器（500ms 延遲）
  searchDebounceTimer = window.setTimeout(() => {
    applyFilters()
    searchDebounceTimer = null
  }, 500)
}

const resetFilters = () => {
  filters.search = ''
  filters.role = ''
  filters.status = ''
  applyFilters()
}

const changePage = (delta: number) => {
  const nextPage = pagination.current_page + delta
  if (nextPage < 1 || nextPage > pagination.last_page) return
  pagination.current_page = nextPage
  loadAdmins()
}

const getFriendlyAdminResetError = (err: any): string => {
  const rawMessage = err?.response?.data?.message || err?.message || ''
  const normalized = rawMessage.toLowerCase()

  if (normalized.includes("unknown column 'updated_at'")) {
    return 'The admin_verification_tokens table is missing the updated_at column. Please run the latest migration to add timestamps.'
  }

  if (normalized.includes("unknown column 'created_by'")) {
    return 'The admin_verification_tokens table is missing the created_by column. Please sync the database schema.'
  }

  if (normalized.includes('sqlstate')) {
    return 'Backend reported a database error while creating the reset link. Please check the server logs.'
  }

  if (err?.response?.status === 403) {
    return rawMessage || 'You do not have permission to reset this admin password.'
  }

  return rawMessage || 'Failed to Reset Password. Please try again later.'
}

const requestResetLink = async (admin: AdminAccount) => {
  if (!canResetAdmin(admin)) return
  selectedAdmin.value = admin
  resetModalError.value = ''
  showResetModal.value = true
  isLoadingReset.value = true
  try {
    const response = await adminAccountsApi.passwordResetLink(admin.id)
    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || 'Failed to Reset Password')
    }
    resetLinkInfo.value = response.data.data
    startCountdown()
  } catch (error: any) {
    resetModalError.value = getFriendlyAdminResetError(error)
    resetLinkInfo.value = null
  } finally {
    isLoadingReset.value = false
  }
}

const startCountdown = () => {
  stopCountdown()
  updateCountdown()
  countdownTimer = window.setInterval(updateCountdown, 1000)
}

const stopCountdown = () => {
  if (countdownTimer) {
    clearInterval(countdownTimer)
    countdownTimer = null
  }
}

const updateCountdown = () => {
  if (!resetLinkInfo.value) {
    resetCountdown.value = ''
    return
  }
  const expires = new Date(resetLinkInfo.value.expires_at).getTime()
  const diff = expires - Date.now()
  if (diff <= 0) {
    resetCountdown.value = 'Expired'
    stopCountdown()
    return
  }
  const minutes = Math.floor(diff / 1000 / 60)
  const seconds = Math.floor((diff / 1000) % 60)
  resetCountdown.value = `${minutes}m ${seconds.toString().padStart(2, '0')}s`
}

const resetMessage = computed(() => {
  if (!selectedAdmin.value || !resetLinkInfo.value) return ''
  return (
    `Hello ${selectedAdmin.value.full_name},\n\n` +
    `Here is your Here4Help admin password reset link (valid for 1 hour):\n${resetLinkInfo.value.reset_link}\n\n` +
    `Shared by ${currentAdminName.value}`
  )
})

const copyResetMessage = async () => {
  if (!resetMessage.value) return
  try {
    await navigator.clipboard.writeText(resetMessage.value)
    resetCopyTooltip.value = 'Copied!'
    if (copyTimer) window.clearTimeout(copyTimer)
    copyTimer = window.setTimeout(() => {
      resetCopyTooltip.value = 'Copy'
      copyTimer = null
    }, 2000)
    resetModalError.value = ''
  } catch (error) {
    resetModalError.value = 'Unable to copy automatically. Please select and copy manually.'
  }
}

const closeResetModal = () => {
  showResetModal.value = false
  selectedAdmin.value = null
  resetLinkInfo.value = null
  resetModalError.value = ''
  isLoadingReset.value = false
  stopCountdown()
  resetCopyTooltip.value = 'Copy'
}

onMounted(() => {
  loadAdmins()
})

onBeforeUnmount(() => {
  stopCountdown()
  if (copyTimer) {
    clearTimeout(copyTimer)
    copyTimer = null
  }
  if (searchDebounceTimer) {
    clearTimeout(searchDebounceTimer)
    searchDebounceTimer = null
  }
})
</script>
