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
              <h3 class="text-lg font-medium text-gray-900">Edit User: {{ user.name }}</h3>
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

            <!-- User Info -->
            <div class="mb-6 p-4 bg-gray-50 rounded-lg">
              <div class="flex items-center space-x-4">
                <div class="flex-shrink-0 h-12 w-12">
                  <div class="h-12 w-12 rounded-full bg-gray-300 flex items-center justify-center">
                    <span class="text-lg font-medium text-gray-700">
                      {{ getUserInitials(user.name) }}
                    </span>
                  </div>
                </div>
                <div>
                  <div class="text-sm font-medium text-gray-900">{{ user.name }}</div>
                  <div class="text-sm text-gray-500">{{ user.email }}</div>
                  <div class="text-xs text-gray-400">ID: {{ user.id }}</div>
                </div>
              </div>
            </div>

            <!-- Form -->
            <form @submit.prevent="handleSubmit" class="space-y-4">
              <!-- Status -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <select v-model="form.status" class="admin-input" required>
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="banned">Banned</option>
                  <option value="pending">Pending</option>
                </select>
              </div>

              <!-- Permission Level -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Permission Level</label>
                <select v-model="form.permission" class="admin-input" required>
                  <option :value="99">Super Admin (99)</option>
                  <option :value="1">Admin (1)</option>
                  <option :value="0">Regular User (0)</option>
                  <option :value="-1">Restricted (-1)</option>
                  <option :value="-2">Suspended (-2)</option>
                  <option :value="-3">Banned (-3)</option>
                  <option :value="-4">Deleted (-4)</option>
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
                  placeholder="Please provide a reason for this change..."
                  required
                ></textarea>
              </div>

              <!-- Current Stats (Read-only) -->
              <div class="border-t pt-4">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Current Statistics</h4>
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-gray-500">Points:</span>
                    <span class="ml-2 font-medium">{{ user.points || 0 }}</span>
                  </div>
                  <div>
                    <span class="text-gray-500">Last Login:</span>
                    <span class="ml-2 font-medium">{{ formatDate(user.last_login) }}</span>
                  </div>
                  <div>
                    <span class="text-gray-500">Registered:</span>
                    <span class="ml-2 font-medium">{{ formatDate(user.created_at) }}</span>
                  </div>
                  <div>
                    <span class="text-gray-500">Updated:</span>
                    <span class="ml-2 font-medium">{{ formatDate(user.updated_at) }}</span>
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
                  :disabled="isLoading || !form.reason.trim()"
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
                    Saving...
                  </span>
                  <span v-else>Save Changes</span>
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
import { ref, reactive, onMounted } from 'vue'
import { userApi } from '@/services/api'

interface Props {
  user: any
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
  status: '',
  permission: 0,
  reason: '',
})

// Methods
const handleSubmit = async () => {
  try {
    isLoading.value = true
    error.value = ''

    // Update status if changed
    if (form.status !== props.user.status) {
      await userApi.updateStatus(props.user.id, form.status, form.reason)
    }

    // Update permission if changed
    if (form.permission !== props.user.permission) {
      await userApi.updatePermission(props.user.id, form.permission, form.reason)
    }

    emit('saved')
  } catch (err: any) {
    error.value = err.response?.data?.message || 'Failed to update user'
  } finally {
    isLoading.value = false
  }
}

const getUserInitials = (name: string) => {
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
}

const formatDate = (dateString: string | null) => {
  if (!dateString) return 'Never'
  return new Date(dateString).toLocaleDateString()
}

// Initialize form
onMounted(() => {
  form.status = props.user.status || 'active'
  form.permission = props.user.permission || 0
})
</script>
