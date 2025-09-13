<template>
  <div class="space-y-6">
    <!-- 頁面標題 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          Task Disputes Management
        </h2>
        <div class="mt-1 flex flex-col sm:mt-0 sm:flex-row sm:flex-wrap sm:space-x-6">
          <div class="mt-2 flex items-center text-sm text-gray-500">
            <Icon name="report-problem" class="mr-1.5 h-5 w-5 flex-shrink-0 text-gray-400" />
            {{ statistics.total_disputes }} Total Disputes
          </div>
        </div>
      </div>
    </div>


    <!-- 篩選器 -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Filters</h3>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <!-- 狀態篩選 -->
          <div>
            <label for="status-filter" class="block text-sm font-medium text-gray-700">Status</label>
            <select
              id="status-filter"
              v-model="filters.status"
              @change="applyFilters"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <option value="">All Statuses</option>
              <option value="submitted">Submitted</option>
              <option value="in_progress">In Progress</option>
              <option value="resolved">Resolved</option>
            </select>
          </div>

          <!-- 日期範圍 -->
          <div>
            <label for="date-from" class="block text-sm font-medium text-gray-700">Date From</label>
            <input
              id="date-from"
              v-model="filters.dateFrom"
              type="date"
              @change="applyFilters"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div>
            <label for="date-to" class="block text-sm font-medium text-gray-700">Date To</label>
            <input
              id="date-to"
              v-model="filters.dateTo"
              type="date"
              @change="applyFilters"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <!-- 排序 -->
          <div>
            <label for="sort-by" class="block text-sm font-medium text-gray-700">Sort By</label>
            <select
              id="sort-by"
              v-model="filters.sortBy"
              @change="applyFilters"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            >
              <option value="created_at">Created Date</option>
              <option value="updated_at">Updated Date</option>
              <option value="status">Status</option>
            </select>
          </div>
        </div>

        <div class="mt-4 flex justify-end space-x-3">
          <button
            @click="resetFilters"
            class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Reset
          </button>
          <button
            @click="refreshData"
            :disabled="loading"
            class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
          >
            <Icon v-if="loading" name="loading" class="animate-spin -ml-1 mr-2 h-4 w-4" />
            Refresh
          </button>
        </div>
      </div>
    </div>

    <!-- 爭議列表表格 -->
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
        <h3 class="text-lg leading-6 font-medium text-gray-900">
          Disputes List
        </h3>
        <p class="mt-1 max-w-2xl text-sm text-gray-500">
          Manage and resolve task disputes
        </p>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="p-8 text-center">
        <Icon name="loading" class="animate-spin h-8 w-8 mx-auto text-gray-400" />
        <p class="mt-2 text-sm text-gray-500">Loading disputes...</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="disputes.length === 0" class="p-8 text-center">
        <Icon name="inbox" class="h-12 w-12 mx-auto text-gray-400" />
        <h3 class="mt-2 text-sm font-medium text-gray-900">No disputes found</h3>
        <p class="mt-1 text-sm text-gray-500">No disputes match your current filters.</p>
      </div>

      <!-- Disputes Table -->
      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Dispute Task
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Reward Point
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Applied User
              </th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Created
              </th>
            
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="dispute in disputes" :key="dispute.id" class="hover:bg-gray-50 cursor-pointer" @click="viewChatRoom(dispute)">
              <!-- Dispute Info -->
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div>
                    <div class="text-sm font-medium text-gray-900">
                      {{ dispute.dispute_title }}
                    </div>
                    <div class="text-sm text-gray-400 max-w-xs truncate">
                      Task ID: {{ dispute.task?.id }}
                    </div>
                  </div>
                </div>
              </td>

              <!-- Task Info -->
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-500">
                  {{ dispute.task?.reward_point || 'N/A' }} points
                </div>
              </td>

              <!-- Submitter -->
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900">
                  {{ dispute.submitter?.name || 'N/A' }}
                </div>
                <div class="text-sm text-gray-500">
                  {{ dispute.submitter?.email || 'N/A' }}
                </div>
              </td>

              <!-- Status -->
              <td class="px-6 py-4 whitespace-nowrap">
                <span
                  :class="getStatusBadgeClass(dispute.status)"
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                >
                  {{ getStatusDisplayName(dispute.status) }}
                </span>
                <div v-if="dispute.admin_username" class="text-xs text-gray-500 mt-1">
                  by {{ dispute.admin_username }}
                </div>
              </td>

              <!-- Created Date -->
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ formatDateTime(dispute.created_at) }}
              </td>

              <!-- Actions -->
              <!-- <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                <button
                  @click="viewChatRoom(dispute)"
                  class="text-indigo-600 hover:text-indigo-900"
                  title="View Chat Room"
                >
                  <Icon name="chat" class="h-4 w-4" />
                </button>
                <button
                  v-if="dispute.status !== 'resolved'"
                  @click="openReviewDialog(dispute)"
                  class="text-green-600 hover:text-green-900"
                  title="Review Dispute"
                >
                  <Icon name="gavel" class="h-4 w-4" />
                </button>
                <button
                  @click="viewDisputeDetail(dispute)"
                  class="text-gray-600 hover:text-gray-900"
                  title="View Details"
                >
                  <Icon name="eye" class="h-4 w-4" />
                </button>
              </td> -->
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="pagination.last_page > 1" class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
        <div class="flex items-center justify-between">
          <div class="flex-1 flex justify-between sm:hidden">
            <button
              @click="changePage(pagination.current_page - 1)"
              :disabled="pagination.current_page <= 1"
              class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>
            <button
              @click="changePage(pagination.current_page + 1)"
              :disabled="pagination.current_page >= pagination.last_page"
              class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
          </div>
          <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
            <div>
              <p class="text-sm text-gray-700">
                Showing
                <span class="font-medium">{{ (pagination.current_page - 1) * pagination.per_page + 1 }}</span>
                to
                <span class="font-medium">{{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }}</span>
                of
                <span class="font-medium">{{ pagination.total }}</span>
                results
              </p>
            </div>
            <div>
              <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
                <button
                  @click="changePage(pagination.current_page - 1)"
                  :disabled="pagination.current_page <= 1"
                  class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Icon name="chevron-left" class="h-5 w-5" />
                </button>
                <button
                  v-for="page in visiblePages"
                  :key="page"
                  @click="changePage(page)"
                  :class="[
                    page === pagination.current_page
                      ? 'z-10 bg-indigo-50 border-indigo-500 text-indigo-600'
                      : 'bg-white border-gray-300 text-gray-500 hover:bg-gray-50',
                    'relative inline-flex items-center px-4 py-2 border text-sm font-medium'
                  ]"
                >
                  {{ page }}
                </button>
                <button
                  @click="changePage(pagination.current_page + 1)"
                  :disabled="pagination.current_page >= pagination.last_page"
                  class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Icon name="chevron-right" class="h-5 w-5" />
                </button>
              </nav>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Dispute Operation Dialog -->
    <DisputeOperationDialog
      v-if="showReviewDialog"
      :dispute="selectedDispute"
      @close="closeReviewDialog"
      @resolved="handleDisputeResolved"
    />

    <!-- Dispute Detail Dialog -->
    <DisputeDetailDialog
      v-if="showDetailDialog"
      :dispute="selectedDispute"
      @close="closeDetailDialog"
      @openOperation="handleOpenOperation"
    />

    <!-- Dispute Chat Room Modal -->
    <DisputeChatRoomModal
      :show="showChatRoomModal"
      :dispute-id="selectedDisputeId"
      @close="closeChatRoomModal"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { disputeApi } from '@/services/api'
import Icon from '@/components/Icon.vue'
import DisputeOperationDialog from '@/components/DisputeOperationDialog.vue'
import DisputeDetailDialog from '@/components/DisputeDetailDialog.vue'
import DisputeChatRoomModal from '@/components/DisputeChatRoomModal.vue'

interface Dispute {
  id: number
  task_id: string
  dispute_title: string
  description: string
  status: 'submitted' | 'in_progress' | 'resolved'
  decision_result?: string
  decision_note?: string
  admin_id?: number
  admin_username?: string
  created_at: string
  updated_at: string
  task: {
    id: string
    title: string
    reward_point: number
    creator_id: number
    participant_id?: number
    creator_name: string
    participant_name?: string
  }
  submitter: {
    id: number
    name: string
    email: string
  }
}

interface Pagination {
  current_page: number
  per_page: number
  total: number
  last_page: number
}

interface Statistics {
  total_disputes: number
  submitted_count: number
  in_progress_count: number
  resolved_count: number
}

const router = useRouter()

// Data
const disputes = ref<Dispute[]>([])
const loading = ref(false)
const pagination = ref<Pagination>({
  current_page: 1,
  per_page: 20,
  total: 0,
  last_page: 1
})

const statistics = ref<Statistics>({
  total_disputes: 0,
  submitted_count: 0,
  in_progress_count: 0,
  resolved_count: 0
})

const filters = reactive({
  status: '',
  dateFrom: '',
  dateTo: '',
  sortBy: 'created_at',
  sortOrder: 'desc' as 'asc' | 'desc'
})

// Dialog states
const showReviewDialog = ref(false)
const showDetailDialog = ref(false)
const showChatRoomModal = ref(false)
const selectedDispute = ref<Dispute | null>(null)
const selectedDisputeId = ref<number | null>(null)

// Computed
const resolutionRate = computed(() => {
  if (statistics.value.total_disputes === 0) return 0
  return Math.round((statistics.value.resolved_count / statistics.value.total_disputes) * 100)
})

const visiblePages = computed(() => {
  const current = pagination.value.current_page
  const total = pagination.value.last_page
  const pages = []
  
  const start = Math.max(1, current - 2)
  const end = Math.min(total, current + 2)
  
  for (let i = start; i <= end; i++) {
    pages.push(i)
  }
  
  return pages
})

// Methods
const fetchDisputes = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
      status: filters.status || undefined,
      date_from: filters.dateFrom || undefined,
      date_to: filters.dateTo || undefined,
      sort_by: filters.sortBy,
      sort_order: filters.sortOrder,
    }

    const response = await disputeApi.list(params)

    if (response.data.success) {
      // 注意：目前後端 DisputeController@index 回傳結構為
      // { success, data: items[], pagination: {...}, stats: {...} }
      // 或者在部分情況下包在 data 物件中。兩者皆容錯支援。
      const body: any = response.data
      const items = (body.data && body.data.items) ? body.data.items : (Array.isArray(body.data) ? body.data : [])
      disputes.value = items || []

      const pg = body.pagination || body.data?.pagination
      if (pg) {
        pagination.value = {
          current_page: pg.current_page || 1,
          per_page: pg.per_page || 20,
          total: pg.total || 0,
          last_page: pg.last_page || 1,
        }
      }

      const st = body.stats || body.data?.stats
      if (st) {
        statistics.value = {
          total_disputes: st.total_disputes ?? st.total ?? 0,
          submitted_count: st.submitted_count ?? st.open ?? 0,
          in_progress_count: st.in_progress_count ?? st.in_review ?? 0,
          resolved_count: st.resolved_count ?? st.resolved ?? 0,
        }
      }
    }
  } catch (error) {
    console.error('Failed to fetch disputes:', error)
    // Handle error (show notification, etc.)
  } finally {
    loading.value = false
  }
}

const applyFilters = () => {
  pagination.value.current_page = 1
  fetchDisputes()
}

const resetFilters = () => {
  Object.assign(filters, {
    status: '',
    dateFrom: '',
    dateTo: '',
    sortBy: 'created_at',
    sortOrder: 'desc'
  })
  applyFilters()
}

const refreshData = () => {
  fetchDisputes()
}

const changePage = (page: number) => {
  if (page >= 1 && page <= pagination.value.last_page) {
    pagination.value.current_page = page
    fetchDisputes()
  }
}

const getStatusBadgeClass = (status: string) => {
  switch (status) {
    case 'submitted':
      return 'bg-yellow-100 text-yellow-800'
    case 'in_progress':
      return 'bg-blue-100 text-blue-800'
    case 'resolved':
      return 'bg-green-100 text-green-800'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

const getStatusDisplayName = (status: string) => {
  switch (status) {
    case 'submitted':
      return 'Submitted'
    case 'in_progress':
      return 'In Progress'
    case 'resolved':
      return 'Resolved'
    default:
      return status
  }
}

const formatDateTime = (dateTimeStr: string) => {
  return new Date(dateTimeStr).toLocaleString()
}

const viewChatRoom = (dispute: Dispute) => {
  router.push(`/task-disputes/${dispute.task.id}/chat-room`)
}

const handleOpenOperation = async () => {
  console.log('🔍 Opening operation dialog, selectedDispute:', selectedDispute.value)
  
  // 先關閉詳情對話框
  showDetailDialog.value = false
  
  // 等待下一個 tick 確保詳情對話框完全關閉
  await nextTick()
  
  // 確保 selectedDispute 有值（應該已經從之前的操作中設置）
  if (!selectedDispute.value) {
    console.error('selectedDispute is null when opening operation dialog')
    return
  }
  
  // 然後打開審核對話框
  showReviewDialog.value = true
}

const openReviewDialog = (dispute: Dispute) => {
  selectedDispute.value = dispute
  showReviewDialog.value = true
}

const closeReviewDialog = () => {
  showReviewDialog.value = false
  selectedDispute.value = null
}

const closeChatRoomModal = () => {
  showChatRoomModal.value = false
  selectedDispute.value = null
  selectedDisputeId.value = null
}

const handleDisputeResolved = () => {
  closeReviewDialog()
  refreshData()
}

const viewDisputeDetail = (dispute: Dispute) => {
  console.log('🔍 Opening dispute detail:', dispute)
  selectedDispute.value = dispute
  showDetailDialog.value = true
}

const closeDetailDialog = () => {
  showDetailDialog.value = false
  selectedDispute.value = null
}

// Lifecycle
onMounted(() => {
  fetchDisputes()
})
</script>
