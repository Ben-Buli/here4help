<template>
  <div class="fixed inset-0 z-50 overflow-y-auto">
    <div
      class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0"
    >
      <!-- Background overlay -->
      <div
        class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
        @click="$emit('close')"
      ></div>

      <!-- Modal panel -->
      <div
        class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6"
      >
        <div class="sm:flex sm:items-start">
          <div class="w-full">
            <!-- Header -->
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">Edit Task Status</h3>
              <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <!-- Task Info -->
            <div class="mb-6 p-4 bg-gray-50 rounded-lg">
              <div class="space-y-2">
                <div class="text-sm font-medium text-gray-900">{{ task.title }}</div>
                <div class="text-sm text-gray-500">{{ task.description }}</div>
                <div class="flex items-center space-x-4 text-xs text-gray-400">
                  <span>ID: {{ task.id }}</span>
                  <span>Creator: {{ task.creator_name }} ({{ task.creator_id }})</span>
                  <span v-if="task.participant_id">
                    Participant: {{ task.participant_name }} ({{ task.participant_id }})
                  </span>
                </div>
              </div>
            </div>

            <!-- Form -->
            <form @submit.prevent="handleSubmit" class="space-y-4">
              <!-- Current Status -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Current Status</label>
                <div class="p-3 bg-gray-100 rounded-md">
                  <span
                    class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                    :class="getStatusBadgeClass(task.status_name)"
                  >
                    {{ task.status_display_name || task.status_name }}
                  </span>
                </div>
              </div>

              <!-- New Status -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">New Status</label>
                <select v-model="form.status_id" class="admin-input" required>
                  <option value="">Select new status...</option>
                  <option v-for="status in statuses" :key="status.id" :value="status.id">
                    {{ status.display_name }}
                  </option>
                </select>
              </div>

              <!-- Reason -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Reason for Change <span class="text-red-500">*</span>
                </label>
                <textarea
                  v-model="form.reason"
                  rows="3"
                  class="admin-input"
                  placeholder="Please provide a reason for this status change..."
                  required
                ></textarea>
              </div>

              <!-- Task Details (Read-only) -->
              <div class="border-t pt-4">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Task Details</h4>
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-gray-500">Reward:</span>
                    <span class="ml-2 font-medium">{{ task.reward || 0 }} points</span>
                  </div>
                  <div>
                    <span class="text-gray-500">Deadline:</span>
                    <span class="ml-2 font-medium">{{ formatDate(task.deadline) }}</span>
                  </div>
                  <div>
                    <span class="text-gray-500">Created:</span>
                    <span class="ml-2 font-medium">{{ formatDate(task.created_at) }}</span>
                  </div>
                  <div>
                    <span class="text-gray-500">Updated:</span>
                    <span class="ml-2 font-medium">{{ formatDate(task.updated_at) }}</span>
                  </div>
                </div>
              </div>

              <!-- Status Change Impact Warning -->
              <div v-if="form.status_id" class="rounded-md bg-yellow-50 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path
                        fill-rule="evenodd"
                        d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-yellow-800">Status Change Impact</h3>
                    <div class="mt-2 text-sm text-yellow-700">
                      <p>{{ getStatusChangeWarning(form.status_id) }}</p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Error Message -->
              <div v-if="error" class="rounded-md bg-red-50 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                      <path
                        fill-rule="evenodd"
                        d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-red-800">Error</h3>
                    <div class="mt-2 text-sm text-red-700">{{ error }}</div>
                  </div>
                </div>
              </div>

              <!-- Actions -->
              <div class="flex justify-end space-x-3 pt-4">
                <button
                  type="button"
                  @click="$emit('close')"
                  class="admin-button-secondary"
                  :disabled="isLoading"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="admin-button-primary"
                  :disabled="isLoading || !form.status_id || !form.reason.trim()"
                >
                  <span v-if="isLoading" class="flex items-center">
                    <svg
                      class="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      ></circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      ></path>
                    </svg>
                    Updating...
                  </span>
                  <span v-else>Update Status</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { taskApi } from '@/services/api'

interface Props {
  task: any
  statuses: any[]
}

interface Emits {
  (e: 'close'): void
  (e: 'saved'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

// State
const isLoading = ref(false)
const error = ref('')

const form = reactive({
  status_id: '',
  reason: '',
})

// Methods
const handleSubmit = async () => {
  try {
    isLoading.value = true
    error.value = ''

    await taskApi.updateStatus(props.task.id, parseInt(form.status_id), form.reason)
    emit('saved')
  } catch (err: any) {
    error.value = err.response?.data?.message || 'Failed to update task status'
  } finally {
    isLoading.value = false
  }
}

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

const getStatusChangeWarning = (statusId: string) => {
  const warnings = {
    '3': 'Marking as completed will finalize the task and may trigger point transfers.',
    '4': 'Cancelling will make the task unavailable and may affect user ratings.',
    '5': 'Disputed status requires admin review and may need additional investigation.',
    '6': 'Pending confirmation status starts a countdown for automatic completion.',
  }
  return (
    warnings[statusId as keyof typeof warnings] ||
    'This status change will be logged for audit purposes.'
  )
}

const formatDate = (dateString: string | null) => {
  if (!dateString) return 'Not set'
  return new Date(dateString).toLocaleDateString()
}
</script>
