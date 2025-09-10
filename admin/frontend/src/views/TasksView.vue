<template>
  <div class="space-y-6">
    <!-- 頁面標題與操作 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          Task Management
        </h2>
        <p class="mt-1 text-sm text-gray-500">
          Monitor and manage tasks, applications, and disputes
        </p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <!-- <button @click="refreshData" class="admin-button-secondary" :disabled="isLoading">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
            />
          </svg>
          Refresh
        </button> -->
        <!-- <button @click="exportTasks" class="admin-button-primary">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          Export
        </button> -->
      </div>
    </div>

    <!-- 篩選與搜尋 -->
    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <!-- 搜尋 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
          <input
            v-model="filters.search"
            type="text"
            placeholder="Task title, creator, participant..."
            class="admin-input"
            @input="debouncedSearch"
          />
        </div>

        <!-- 狀態篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select v-model="filters.status_id" @change="() => loadTasks()" class="admin-input">
            <option value="">All Status</option>
            <option v-for="status in taskStatuses" :key="status.id" :value="status.id">
              {{ status.display_name }}
            </option>
          </select>
        </div>

        <!-- 創建者篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Creator</label>
          <input
            v-model="filters.creator_id"
            type="number"
            placeholder="Creator ID"
            class="admin-input"
            @input="() => loadTasks()"
          />
        </div>

        <!-- 參與者篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Participant</label>
          <input
            v-model="filters.participant_id"
            type="number"
            placeholder="Participant ID"
            class="admin-input"
            @input="() => loadTasks()"
          />
        </div>

        <!-- 排序 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Sort By</label>
          <select v-model="filters.sort_by" @change="() => loadTasks()" class="admin-input">
            <option value="created_at">Created Date</option>
            <option value="updated_at">Updated Date</option>
            <option value="title">Title</option>
            <option value="reward">Reward</option>
            <option value="deadline">Deadline</option>
          </select>
        </div>
      </div>

      <!-- 日期範圍與排序方向 -->
      <div class="mt-4 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Date From</label>
            <input
              v-model="filters.date_from"
              type="date"
              class="admin-input"
              @change="() => loadTasks()"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Date To</label>
            <input
              v-model="filters.date_to"
              type="date"
              class="admin-input"
              @change="() => loadTasks()"
            />
          </div>
        </div>
        <div class="flex items-center space-x-4">
          <label class="flex items-center">
            <input
              v-model="filters.sort_order"
              type="radio"
              value="desc"
              @change="() => loadTasks()"
              class="mr-2"
            />
            Newest First
          </label>
          <label class="flex items-center">
            <input
              v-model="filters.sort_order"
              type="radio"
              value="asc"
              @change="() => loadTasks()"
              class="mr-2"
            />
            Oldest First
          </label>
        </div>
      </div>
    </div>

 

    <!-- 任務列表 -->
    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Tasks</h3>
        <div class="text-sm text-gray-500">
          Showing {{ (pagination.current_page - 1) * pagination.per_page + 1 }} to
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }} of
          {{ pagination.total }} results
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="flex justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>

      <!-- Empty State -->
      <div v-else-if="tasks.length === 0" class="text-center py-8">
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
            d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
          />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No tasks found</h3>
        <p class="mt-1 text-sm text-gray-500">Try adjusting your search or filter criteria.</p>
      </div>

      <!-- Tasks Table -->
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Task</th>
              <th>Creator</th>
              <th>Participant</th>
              <th>Status</th>
              <th>Reward</th>
              <th>Deadline</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr 
              v-for="task in tasks" 
              :key="task.id" 
              class="hover:bg-gray-50 cursor-pointer"
              @click="viewTask(task.id)"
            >
              <td>
                <div class="max-w-xs">
                  <div class="text-sm font-medium text-gray-900 truncate">
                    {{ task.title }}
                  </div>
                  <div class="text-sm text-gray-500 truncate">
                    {{ task.description }}
                  </div>
                  <div class="text-xs text-gray-400">ID: {{ task.id }}</div>
                </div>
              </td>
              <td>
                <div class="text-sm text-gray-900">
                  {{ task.creator_name || 'Unknown' }}
                </div>
                <div class="text-xs text-gray-500">ID: {{ task.creator_id }}</div>
              </td>
              <td>
                <div v-if="task.participant_id" class="text-sm text-gray-900">
                  {{ task.participant_name || 'Unknown' }}
                </div>
                <div v-else class="text-sm text-gray-500">No participant</div>
                <div v-if="task.participant_id" class="text-xs text-gray-500">
                  ID: {{ task.participant_id }}
                </div>
              </td>
              <td>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(task.status_code)"
                >
                  {{ task.status_display || task.status_code }}
                </span>
              </td>
              <td class="text-sm text-gray-900">{{ task.reward_point || task.reward || 0 }} points</td>
              <td class="text-sm text-gray-500">{{ formatDate(task.deadline || task.task_date) }}</td>
              <td class="text-sm text-gray-500">
                {{ formatDate(task.created_at) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div
        v-if="pagination.total > pagination.per_page"
        class="mt-6 flex items-center justify-between"
      >
        <div class="text-sm text-gray-700">
          Page {{ pagination.current_page }} of {{ pagination.last_page }}
        </div>
        <div class="flex space-x-2">
          <button
            @click="changePage(pagination.current_page - 1)"
            :disabled="pagination.current_page <= 1"
            class="admin-button-secondary text-sm"
            :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }"
          >
            Previous
          </button>
          <button
            @click="changePage(pagination.current_page + 1)"
            :disabled="pagination.current_page >= pagination.last_page"
            class="admin-button-secondary text-sm"
            :class="{
              'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page,
            }"
          >
            Next
          </button>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { taskApi } from '@/services/api'

const router = useRouter()
const authStore = useAuthStore()

// State
const isLoading = ref(false)
const tasks = ref<any[]>([])
const taskStatuses = ref<any[]>([])

const stats = ref({
  total_tasks: 0,
  active_tasks: 0,
  pending_tasks: 0,
  disputed_tasks: 0,
})

const pagination = ref({
  current_page: 1,
  per_page: 25,
  total: 0,
  last_page: 1,
})

const filters = reactive({
  search: '',
  status_id: '',
  creator_id: '',
  participant_id: '',
  date_from: '',
  date_to: '',
  sort_by: 'created_at',
  sort_order: 'desc' as 'asc' | 'desc',
})

// Methods
const loadTasks = async (page = 1) => {
  try {
    isLoading.value = true

    const params = {
      page,
      per_page: pagination.value.per_page,
      search: filters.search || undefined,
      status_id: filters.status_id ? parseInt(filters.status_id) : undefined,
      creator_id: filters.creator_id ? parseInt(filters.creator_id) : undefined,
      participant_id: filters.participant_id ? parseInt(filters.participant_id) : undefined,
      date_from: filters.date_from || undefined,
      date_to: filters.date_to || undefined,
      sort_by: filters.sort_by,
      sort_order: filters.sort_order,
    }

    const response = await taskApi.list(params)

    if (response.data.success && response.data.data) {
      // 後端回傳鍵為 data.tasks
      const data = response.data.data as any
      tasks.value = data.tasks || data.items || []

      // 使用後端返回的分頁信息
      if (data.pagination) {
        pagination.value = data.pagination
      }
      
      // 使用後端返回的統計信息
      if (data.stats) {
        stats.value = data.stats
      }
    }
  } catch (error) {
    console.error('Failed to load tasks:', error)
  } finally {
    isLoading.value = false
  }
}

const refreshData = () => {
  loadTasks(pagination.value.current_page)
}

const changePage = (page: number) => {
  if (page >= 1 && page <= pagination.value.last_page) {
    loadTasks(page)
  }
}

const viewTask = (taskId: string | number) => {
  router.push(`/tasks/${taskId}`)
}

const exportTasks = () => {
  // TODO: Implement task export functionality
  alert('Export functionality coming soon!')
}

// Debounced search
let searchTimeout: number
const debouncedSearch = () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    loadTasks(1)
  }, 500)
}

// Utility functions
const getStatusBadgeClass = (status: string) => {
  const classes = {
    open: 'bg-blue-100 text-blue-800',
    in_progress: 'bg-yellow-100 text-yellow-800',
    completed: 'bg-green-100 text-green-800',
    cancelled: 'bg-gray-100 text-gray-800',
    disputed: 'bg-red-100 text-red-800',
    pending_confirmation: 'bg-purple-100 text-purple-800',
  }
  return classes[status as keyof typeof classes] || 'bg-gray-100 text-gray-800'
}

const formatDate = (dateString: string | null) => {
  if (!dateString) return 'Not set'
  return new Date(dateString).toLocaleDateString()
}

// Load task statuses
const loadTaskStatuses = async () => {
  try {
    const response = await taskApi.statuses()
    
    if (response.data.success && response.data.data) {
      taskStatuses.value = response.data.data
    }
  } catch (error) {
    console.error('Failed to load task statuses:', error)
    // Fallback to hardcoded statuses
    taskStatuses.value = [
      { id: 1, code: 'open', display_name: 'Open' },
      { id: 2, code: 'in_progress', display_name: 'In Progress' },
      { id: 3, code: 'completed', display_name: 'Completed' },
      { id: 4, code: 'cancelled', display_name: 'Cancelled' },
      { id: 5, code: 'disputed', display_name: 'Disputed' },
      { id: 6, code: 'pending_confirmation', display_name: 'Pending Confirmation' },
    ]
  }
}

// Lifecycle
onMounted(() => {
  loadTaskStatuses()
  loadTasks()
})
</script>
