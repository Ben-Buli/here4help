<template>
  <div class="space-y-6">
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          User Withdraw Approval Management
        </h2>
        <p class="mt-1 text-sm text-gray-500">
          Review withdraw requests, approve or reject with admin replies
        </p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="refreshData" class="admin-button-secondary" :disabled="loading">
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

    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select v-model="filters.status" @change="loadWithdraws" class="admin-input">
            <option value="">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
            <option value="cancelled">Cancelled</option>
            <option value="paid">Paid</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
          <input type="date" v-model="filters.fromDate" @change="loadWithdraws" class="admin-input" />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
          <input type="date" v-model="filters.toDate" @change="loadWithdraws" class="admin-input" />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Per Page</label>
          <select v-model="pagination.per_page" @change="handlePerPageChange" class="admin-input">
            <option value="10">10</option>
            <option value="15">15</option>
            <option value="25">25</option>
            <option value="50">50</option>
          </select>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-amber-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3" />
                <circle cx="12" cy="12" r="9" stroke-width="2" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Pending</dt>
              <dd class="text-lg font-medium text-gray-900">{{ statistics?.pending || 0 }}</dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4" />
                <circle cx="12" cy="12" r="9" stroke-width="2" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Approved Today</dt>
              <dd class="text-lg font-medium text-gray-900">{{ statistics?.approved_today || 0 }}</dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8V7m0 9v1" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Payout</dt>
              <dd class="text-lg font-medium text-gray-900">{{ formatPoints(statistics?.total_amount || 0) }}</dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12h18" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v18" />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Requests</dt>
              <dd class="text-lg font-medium text-gray-900">{{ pagination?.total || 0 }}</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Withdraw Requests</h3>
        <div class="text-sm text-gray-500">
          Showing {{ (pagination?.current_page - 1) * pagination?.per_page + 1 }} to
          {{ Math.min(pagination?.current_page * pagination?.per_page, pagination?.total) }} of
          {{ pagination?.total }} results
        </div>
      </div>

      <div v-if="loading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <div v-else-if="withdraws.length === 0" class="text-center py-8">
        <h3 class="mt-2 text-sm font-medium text-gray-900">No withdraw requests</h3>
        <p class="mt-1 text-sm text-gray-500">No withdraw requests match your criteria.</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>User</th>
              <th>Request</th>
              <th>Fee</th>
              <th>Total Deduct</th>
              <th>Status</th>
              <th>Created</th>
              <th>Admin Reply</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="item in withdraws" :key="item.id" class="hover:bg-gray-50">
              <td class="text-sm text-gray-900">#{{ item.id }}</td>
              <td>
                <div class="text-sm text-gray-900">{{ item.user_name }}</div>
                <div class="text-xs text-gray-500">{{ item.user_email }}</div>
              </td>
              <td class="text-sm text-gray-900">{{ formatPoints(item.amount_points) }}</td>
              <td class="text-sm text-gray-900">{{ formatPoints(item.fee_points) }}</td>
              <td class="text-sm text-gray-900">{{ formatPoints(item.total_deduct_points) }}</td>
              <td>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(item.status)"
                >
                  {{ getStatusText(item.status) }}
                </span>
              </td>
              <td class="text-sm text-gray-500">{{ formatDate(item.created_at) }}</td>
              <td class="text-sm text-gray-500">{{ item.admin_reply || '-' }}</td>
              <td class="text-sm text-gray-500">
                <div v-if="item.status === 'pending'" class="flex flex-col space-y-1">
                  <button class="admin-button-primary text-xs" @click="openActionModal(item, 'approve')">
                    Approve
                  </button>
                  <button class="admin-button-danger text-xs" @click="openActionModal(item, 'reject')">
                    Reject
                  </button>
                </div>
                <div v-else-if="item.status === 'approved'" class="flex flex-col space-y-1">
                  <button class="admin-button-secondary text-xs" @click="markPaid(item)">
                    Mark Paid
                  </button>
                </div>
                <div v-else>-</div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="showActionModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md p-6">
        <h3 class="text-lg font-semibold text-gray-900">
          {{ actionTitle }}
        </h3>
        <p class="text-sm text-gray-500 mt-1">
          Request #{{ selectedWithdraw?.id }} · {{ formatPoints(selectedWithdraw?.amount_points || 0) }} points
        </p>
        <div class="mt-4">
          <label class="block text-sm font-medium text-gray-700">Reply Message</label>
          <textarea v-model="actionNote" rows="3" class="admin-input mt-2 w-full" placeholder="Optional reply..."></textarea>
        </div>
        <div class="mt-6 flex justify-end space-x-3">
          <button class="admin-button-secondary" @click="closeActionModal">Cancel</button>
          <button class="admin-button-primary" @click="submitAction" :disabled="actionSubmitting">
            <span v-if="actionSubmitting">Processing...</span>
            <span v-else>Confirm</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { paymentApi } from '@/services/api'

const loading = ref(false)
const withdraws = ref<any[]>([])
const statistics = ref<any>(null)

const pagination = ref({
  current_page: 1,
  per_page: 20,
  total: 0,
  last_page: 1,
})

const filters = ref<{
  status: '' | 'pending' | 'approved' | 'rejected' | 'cancelled' | 'paid'
  fromDate: string
  toDate: string
}>({
  status: '',
  fromDate: '',
  toDate: '',
})

const showActionModal = ref(false)
const selectedWithdraw = ref<any>(null)
const actionNote = ref('')
const actionType = ref<'approve' | 'reject'>('approve')
const actionSubmitting = ref(false)

const loadWithdraws = async () => {
  loading.value = true
  try {
    const response = await paymentApi.withdrawRequests({
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
      status: filters.value.status || undefined,
      from_date: filters.value.fromDate || undefined,
      to_date: filters.value.toDate || undefined,
    })
    const data = (response.data.data || {}) as {
      items?: any[]
      pagination?: typeof pagination.value
      stats?: any
    }
    withdraws.value = data.items || []
    pagination.value = data.pagination || pagination.value
    statistics.value = data.stats || {}
  } catch (error) {
    console.error('Failed to load withdraw requests:', error)
  } finally {
    loading.value = false
  }
}

const refreshData = () => {
  pagination.value.current_page = 1
  loadWithdraws()
}

const handlePerPageChange = () => {
  pagination.value.current_page = 1
  loadWithdraws()
}

const openActionModal = (item: any, type: 'approve' | 'reject') => {
  selectedWithdraw.value = item
  actionType.value = type
  actionNote.value = ''
  showActionModal.value = true
}

const closeActionModal = () => {
  showActionModal.value = false
  selectedWithdraw.value = null
  actionNote.value = ''
}

const submitAction = async () => {
  if (!selectedWithdraw.value) return
  actionSubmitting.value = true
  try {
    const id = selectedWithdraw.value.id
    if (actionType.value === 'approve') {
      await paymentApi.approveWithdraw(id, actionNote.value)
    } else {
      await paymentApi.rejectWithdraw(id, actionNote.value)
    }
    closeActionModal()
    await loadWithdraws()
  } catch (error) {
    console.error('Failed to update withdraw request:', error)
  } finally {
    actionSubmitting.value = false
  }
}

const markPaid = async (item: any) => {
  try {
    await paymentApi.markWithdrawPaid(item.id)
    await loadWithdraws()
  } catch (error) {
    console.error('Failed to mark withdraw as paid:', error)
  }
}

const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    pending: 'Pending',
    approved: 'Approved',
    rejected: 'Rejected',
    cancelled: 'Cancelled',
    paid: 'Paid',
  }
  return map[status] || status
}

const getStatusBadgeClass = (status: string) => {
  const map: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
    cancelled: 'bg-gray-100 text-gray-800',
    paid: 'bg-blue-100 text-blue-800',
  }
  return map[status] || 'bg-gray-100 text-gray-800'
}

const formatPoints = (points: number | null | undefined) => {
  const normalized = Number(points ?? 0)
  if (!Number.isFinite(normalized)) return '0'
  return normalized.toLocaleString()
}

const formatDate = (dateString?: string) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleString()
}

const actionTitle = computed(() =>
  actionType.value === 'approve' ? 'Approve Withdraw Request' : 'Reject Withdraw Request',
)

onMounted(() => {
  loadWithdraws()
})
</script>
