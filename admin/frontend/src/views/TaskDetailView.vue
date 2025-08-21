<template>
  <div class="space-y-6">
    <!-- Loading State -->
    <div v-if="isLoading" class="flex justify-center py-12">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-center py-12">
      <div class="text-red-600 mb-4">{{ error }}</div>
      <button @click="loadTask" class="admin-button-primary">Retry</button>
    </div>

    <!-- Task Detail Content -->
    <div v-else-if="task">
      <!-- Header -->
      <div class="md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <nav class="flex mb-4" aria-label="Breadcrumb">
            <ol class="flex items-center space-x-4">
              <li>
                <router-link to="/tasks" class="text-gray-400 hover:text-gray-500">
                  <svg class="flex-shrink-0 h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"
                    />
                  </svg>
                </router-link>
              </li>
              <li>
                <div class="flex items-center">
                  <svg
                    class="flex-shrink-0 h-5 w-5 text-gray-300"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <router-link
                    to="/tasks"
                    class="ml-4 text-sm font-medium text-gray-500 hover:text-gray-700"
                  >
                    Tasks
                  </router-link>
                </div>
              </li>
              <li>
                <div class="flex items-center">
                  <svg
                    class="flex-shrink-0 h-5 w-5 text-gray-300"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <span class="ml-4 text-sm font-medium text-gray-900">{{ task.title }}</span>
                </div>
              </li>
            </ol>
          </nav>

          <div class="flex items-start space-x-4">
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-gray-900">{{ task.title }}</h1>
              <p class="text-sm text-gray-500 mt-1">{{ task.description }}</p>
              <div class="flex items-center space-x-4 mt-2">
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(task.status_name)"
                >
                  {{ task.status_display_name || task.status_name }}
                </span>
                <span class="text-sm text-gray-500">ID: {{ task.id }}</span>
              </div>
            </div>
          </div>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
          <button @click="editTaskStatus" class="admin-button-primary">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              />
            </svg>
            Edit Status
          </button>
          <button @click="refreshData" class="admin-button-secondary">
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

      <!-- Task Information Cards -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- Basic Information -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Task Information</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Task ID</dt>
              <dd class="text-sm text-gray-900">{{ task.id }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Title</dt>
              <dd class="text-sm text-gray-900">{{ task.title }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Description</dt>
              <dd class="text-sm text-gray-900">{{ task.description || 'No description' }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Reward</dt>
              <dd class="text-sm text-gray-900">{{ task.reward || 0 }} points</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Location</dt>
              <dd class="text-sm text-gray-900">{{ task.location || 'Not specified' }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Deadline</dt>
              <dd class="text-sm text-gray-900">{{ formatDate(task.deadline) }}</dd>
            </div>
          </dl>
        </div>

        <!-- People Involved -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">People Involved</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Creator</dt>
              <dd class="text-sm text-gray-900">
                {{ task.creator_name || 'Unknown' }}
                <span class="text-gray-500">(ID: {{ task.creator_id }})</span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Participant</dt>
              <dd class="text-sm text-gray-900">
                <span v-if="task.participant_id">
                  {{ task.participant_name || 'Unknown' }}
                  <span class="text-gray-500">(ID: {{ task.participant_id }})</span>
                </span>
                <span v-else class="text-gray-500">No participant assigned</span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(task.status_name)"
                >
                  {{ task.status_display_name || task.status_name }}
                </span>
              </dd>
            </div>
          </dl>
        </div>

        <!-- Timestamps -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Timeline</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Created</dt>
              <dd class="text-sm text-gray-900">{{ formatDateTime(task.created_at) }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Last Updated</dt>
              <dd class="text-sm text-gray-900">{{ formatDateTime(task.updated_at) }}</dd>
            </div>
            <div v-if="task.accepted_at">
              <dt class="text-sm font-medium text-gray-500">Accepted</dt>
              <dd class="text-sm text-gray-900">{{ formatDateTime(task.accepted_at) }}</dd>
            </div>
            <div v-if="task.completed_at">
              <dt class="text-sm font-medium text-gray-500">Completed</dt>
              <dd class="text-sm text-gray-900">{{ formatDateTime(task.completed_at) }}</dd>
            </div>
          </dl>
        </div>
      </div>

      <!-- Task Applications -->
      <div v-if="applications && applications.length > 0" class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Applications</h3>
        <div class="space-y-3">
          <div
            v-for="application in applications"
            :key="application.id"
            class="flex items-center justify-between py-3 border-b border-gray-200 last:border-b-0"
          >
            <div class="flex items-center space-x-3">
              <div
                class="flex-shrink-0 w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center"
              >
                <span class="text-sm font-medium text-gray-700">
                  {{ getUserInitials(application.user_name) }}
                </span>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">{{ application.user_name }}</p>
                <p class="text-sm text-gray-500">
                  Applied: {{ formatDateTime(application.created_at) }}
                </p>
              </div>
            </div>
            <div class="text-sm text-gray-400">ID: {{ application.user_id }}</div>
          </div>
        </div>
      </div>

      <!-- Task Status Edit Modal -->
      <TaskStatusModal
        v-if="showStatusModal"
        :task="task"
        :statuses="taskStatuses"
        @close="showStatusModal = false"
        @saved="handleTaskSaved"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { taskApi } from '@/services/api'
import TaskStatusModal from '@/components/TaskStatusModal.vue'

const route = useRoute()
const router = useRouter()

// State
const isLoading = ref(false)
const error = ref('')
const task = ref<any>(null)
const applications = ref<any[]>([])
const taskStatuses = ref<any[]>([])
const showStatusModal = ref(false)

// Methods
const loadTask = async () => {
  try {
    isLoading.value = true
    error.value = ''

    const taskId = route.params.id as string
    if (!taskId) {
      throw new Error('Invalid task ID')
    }

    const response = await taskApi.show(taskId)

    if (response.data.success && response.data.data) {
      const data = response.data.data as any
      task.value = data.task
      applications.value = data.applications || data.task?.applications || []
    } else {
      throw new Error('Task not found')
    }
  } catch (err: any) {
    error.value = err.response?.data?.message || err.message || 'Failed to load task'
    if (err.response?.status === 404) {
      router.push('/tasks')
    }
  } finally {
    isLoading.value = false
  }
}

const loadTaskStatuses = async () => {
  try {
    // This would be a separate API call to get task statuses
    // For now, we'll use hardcoded statuses
    taskStatuses.value = [
      { id: 1, name: 'open', display_name: 'Open' },
      { id: 2, name: 'in_progress', display_name: 'In Progress' },
      { id: 3, name: 'completed', display_name: 'Completed' },
      { id: 4, name: 'cancelled', display_name: 'Cancelled' },
      { id: 5, name: 'disputed', display_name: 'Disputed' },
      { id: 6, name: 'pending_confirmation', display_name: 'Pending Confirmation' },
    ]
  } catch (error) {
    console.error('Failed to load task statuses:', error)
  }
}

const refreshData = () => {
  loadTask()
}

const editTaskStatus = () => {
  showStatusModal.value = true
}

const handleTaskSaved = () => {
  showStatusModal.value = false
  refreshData()
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

const getUserInitials = (name: string) => {
  if (!name) return '?'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
}

const formatDate = (dateString: string | null) => {
  if (!dateString) return 'Not set'
  return new Date(dateString).toLocaleDateString()
}

const formatDateTime = (dateString: string | null) => {
  if (!dateString) return 'Not set'
  return new Date(dateString).toLocaleString()
}

// Lifecycle
onMounted(() => {
  loadTaskStatuses()
  loadTask()
})
</script>
