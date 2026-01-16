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
          <button
            @click="handleOperationClick"
            class="admin-button-primary"
            :class="operationBlocked ? 'opacity-60 cursor-not-allowed' : ''"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 6V4m0 16v-2m8-6h2M2 12H4m12.364-5.364l1.414-1.414m-11.314 0l1.414 1.414m0 11.314l-1.414 1.414m11.314 0l-1.414-1.414"
              />
            </svg>
            Operations
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
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2 mt-8">
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
            <div v-if="task.status_id === 3">
              <dt class="text-sm font-medium text-gray-500">Countdown</dt>
              <dd class="text-sm text-gray-900">
                <span v-if="task.countdown_seconds && task.countdown_seconds > 0">{{ formatCountdown(task.countdown_seconds) }}</span>
                <span v-else class="text-gray-400">-</span>
              </dd>
            </div>
          </dl>
        </div>

        <!-- People Involved -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">People Involved</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Poster</dt>
              <dd class="text-sm text-gray-900">
                {{ task.creator_name || 'Unknown' }}
                <span class="text-gray-500">(ID: {{ task.creator_id }})</span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Tasker</dt>
              <dd class="text-sm text-gray-900">
                <span v-if="task.participant_id">
                  {{ task.participant_name || 'Unknown' }}
                  <span class="text-gray-500">(ID: {{ task.participant_id }})</span>
                </span>
                <span v-else class="text-gray-500">No tasker assigned yet</span>
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
        <div class="admin-card lg:col-span-2">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-gray-900">Task Reports</h3>
            <span
              v-if="hasPendingReportsState"
              class="inline-flex items-center px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-700"
            >
              Pending
            </span>
          </div>
          <div v-if="reportsLoading" class="text-sm text-gray-500">Loading reports...</div>
          <div v-else-if="reportsError" class="text-sm text-red-600">{{ reportsError }}</div>
          <div v-else-if="reports.length === 0" class="text-sm text-gray-500">No reports for this task.</div>
          <div v-else class="space-y-3">
            <div
              v-for="report in reports"
              :key="report.id"
              class="flex items-center justify-between border border-gray-200 rounded-lg px-4 py-3"
            >
              <div>
                <p class="text-sm font-semibold text-gray-900">
                  {{ formatReportReason(report.reason) }}
                </p>
                <p class="text-xs text-gray-500">
                  {{ formatDateTime(report.updated_at || report.created_at) }}
                  · Status:
                  <span class="font-medium text-gray-900">{{ formatReportStatus(report.status) }}</span>
                </p>
              </div>
              <button
                class="text-sm font-medium text-primary-600 hover:text-primary-500"
                @click="openReportModal(report)"
              >
                View
              </button>
            </div>
          </div>
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

    </div>
    <div
      v-if="showReportModal && selectedReport"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4 py-8"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6">
        <div class="flex items-start justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">Report Detail</h3>
            <p class="text-sm text-gray-500">
              {{ formatReportReason(selectedReport.reason) }}
            </p>
          </div>
          <button class="text-gray-400 hover:text-gray-600" @click="closeReportModal">
            <span class="sr-only">Close</span>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-4 space-y-3 text-sm text-gray-700">
          <div>
            <span class="font-medium">Reporter:</span>
            {{ selectedReport.reporter_name || 'Unknown' }}
            <span class="text-gray-500">(ID: {{ selectedReport.reporter_id || '-' }})</span>
          </div>
          <div>
            <span class="font-medium">Task Owner:</span>
            {{ task?.creator_name || 'Unknown' }}
            <span class="text-gray-500">(ID: {{ task?.creator_id || '-' }})</span>
          </div>
          <div>
            <span class="font-medium">Status:</span>
            {{ formatReportStatus(selectedReport.status) }}
          </div>
          <div>
            <span class="font-medium">Created:</span> {{ formatDateTime(selectedReport.created_at) }}
          </div>
          <div>
            <span class="font-medium">Updated:</span> {{ formatDateTime(selectedReport.updated_at) }}
          </div>
          <div>
            <span class="font-medium">Description:</span>
            <p class="mt-1 whitespace-pre-wrap bg-gray-50 rounded-md p-3 text-gray-700">
              {{ selectedReport.description || 'No description provided.' }}
            </p>
          </div>
        </div>

        <div v-if="isSelectedReportPending" class="mt-6 space-y-4">
          <div>
            <label class="text-sm font-medium text-gray-700">Decision</label>
            <div class="mt-2 space-y-2">
              <label class="flex items-center space-x-2 text-sm text-gray-700">
                <input
                  type="radio"
                  value="approve_remove"
                  v-model="reportAction"
                  class="text-primary-600 focus:ring-primary-500"
                />
                <span>Approve and remove this task</span>
              </label>
            </div>
          </div>
          <div>
            <label class="text-sm font-medium text-gray-700">Admin Notes *</label>
            <textarea
              v-model="reportNotes"
              rows="4"
              class="admin-input mt-2 w-full px-2"
              placeholder="Explain your decision..."
            ></textarea>
          </div>
          <p class="text-xs text-red-600">
            This action is irreversible. Double check before submitting.
          </p>
        </div>
        <div v-else class="mt-6 text-sm text-gray-500">This report has already been processed.</div>

        <div class="mt-6 flex justify-end space-x-3">
          <button class="admin-button-secondary" @click="closeReportModal">Close</button>
          <button
            v-if="isSelectedReportPending"
            class="admin-button-primary"
            :disabled="reportSubmitting"
            @click="submitReportResolution"
          >
            <span v-if="reportSubmitting">Processing...</span>
            <span v-else>Resolve</span>
          </button>
        </div>
      </div>
    </div>

    <div
      v-if="showOperationModal"
      class="fixed inset-0 z-30 flex items-center justify-center bg-black/30 px-4 py-8"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-3xl max-h-[90vh] overflow-y-auto p-6">
        <div class="flex items-start justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">Task Operation</h3>
            <p class="text-sm text-gray-500">Task ID: {{ task?.id }}</p>
          </div>
          <button class="text-gray-400 hover:text-gray-600" @click="closeOperationModal">
            <span class="sr-only">Close</span>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-4 space-y-4 text-sm text-gray-700">
          <div>
            <p class="font-medium text-gray-900">{{ task?.title }}</p>
            <p class="text-gray-500">
              Current status: {{ task?.status_display_name || task?.status_name }}
            </p>
            <p class="text-gray-500">
              Participant:
              <span v-if="task?.participant_id">
                {{ task?.participant_name || 'Unknown' }} (ID: {{ task?.participant_id }})
              </span>
              <span v-else>None</span>
            </p>
          </div>

          <div v-if="task?.application_questions?.length" class="space-y-2">
            <p class="font-medium text-gray-900">Application Questions</p>
            <ul class="list-disc list-inside text-gray-600 space-y-1">
              <li v-for="question in task.application_questions" :key="question.id">
                {{ question.application_question }}
              </li>
            </ul>
          </div>

          <div>
            <label class="text-sm font-medium text-gray-700">Action</label>
            <div class="mt-2 space-y-2">
              <label class="flex items-center space-x-2 text-sm text-gray-700">
                <input
                  type="radio"
                  value="cancel"
                  v-model="operationAction"
                  class="text-primary-600 focus:ring-primary-500"
                />
                <div>
                  <p class="font-medium text-gray-900">Cancel this task</p>
                  <p class="text-xs text-gray-500">
                    The assignment will be cancelled immediately and the participant (if any) will be removed.
                  </p>
                </div>
              </label>
            </div>
          </div>

          <div>
            <label class="text-sm font-medium text-gray-700">Reason *</label>
            <textarea
              v-model="operationReason"
              rows="4"
              class="admin-input mt-2 w-full px-2"
              placeholder="Explain why this task should be updated..."
            ></textarea>
          </div>

          <p class="text-xs text-red-600">
            This operation is irreversible. Double check before submitting.
          </p>
        </div>

        <div class="mt-6 flex justify-end space-x-3">
          <button class="admin-button-secondary" @click="closeOperationModal">Cancel</button>
          <button class="admin-button-primary" :disabled="operationSubmitting" @click="submitOperation">
            <span v-if="operationSubmitting">Processing...</span>
            <span v-else>Confirm</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { taskApi } from '@/services/api'

const route = useRoute()
const router = useRouter()

// State
const isLoading = ref(false)
const error = ref('')
const task = ref<any>(null)
const applications = ref<any[]>([])

const reports = ref<any[]>([])
const reportsLoading = ref(false)
const reportsError = ref('')
const hasPendingReportsState = ref(false)
const showReportModal = ref(false)
const selectedReport = ref<any | null>(null)
const reportAction = ref<'approve_remove'>('approve_remove')
const reportNotes = ref('')
const reportSubmitting = ref(false)

const showOperationModal = ref(false)
const operationAction = ref<'cancel'>('cancel')
const operationReason = ref('')
const operationSubmitting = ref(false)

const taskHasDispute = computed(() => {
  if (!task.value) return false
  return task.value.status_code === 'dispute' || task.value.status_id === 4
})

const operationBlocked = computed(() => hasPendingReportsState.value || taskHasDispute.value)
const isSelectedReportPending = computed(() => selectedReport.value?.status === 'pending')

const reportReasonLabels: Record<string, string> = {
  spam_advertising: 'Spam / Advertising',
  fraud_scam: 'Fraud / Scam',
  misleading_false_info: 'Misleading or False Information',
  illegal_activity: 'Illegal Activity',
  abusive_offensive_content: 'Abusive / Offensive Content',
  duplicate_repeated_posting: 'Duplicate Posting',
  unreasonable_reward_conditions: 'Unreasonable Reward / Conditions',
  other: 'Other'
}

const reportStatusLabels: Record<string, string> = {
  pending: 'Pending',
  reviewed: 'Reviewed',
  resolved: 'Resolved',
  dismissed: 'Dismissed'
}

const operationGuardMessage =
  'This task currently has unresolved reports or disputes. Please resolve them first before performing additional operations.'

const formatReportReason = (reason: string) => reportReasonLabels[reason] ?? reason
const formatReportStatus = (status: string) => reportStatusLabels[status] ?? status

const loadTaskReports = async (taskId: string) => {
  if (!taskId) return
  reportsLoading.value = true
  reportsError.value = ''
  try {
    const response = await taskApi.reports(taskId)
    if (response.data.success && response.data.data) {
      reports.value = response.data.data.reports ?? []
      hasPendingReportsState.value = Boolean(response.data.data.has_pending)
    } else {
      reportsError.value = response.data.message || 'Failed to load reports'
    }
  } catch (err: any) {
    reportsError.value = err.response?.data?.message || err.message || 'Failed to load reports'
  } finally {
    reportsLoading.value = false
  }
}

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
      hasPendingReportsState.value = Boolean(data.task?.has_pending_reports)
      await loadTaskReports(taskId)
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


const refreshData = () => {
  loadTask()
}

const openReportModal = (report: any) => {
  selectedReport.value = report
  reportNotes.value = ''
  reportAction.value = 'approve_remove'
  showReportModal.value = true
}

const closeReportModal = () => {
  showReportModal.value = false
  selectedReport.value = null
  reportNotes.value = ''
  reportAction.value = 'approve_remove'
}

const submitReportResolution = async () => {
  if (!selectedReport.value) {
    return
  }

  if (!reportNotes.value.trim()) {
    alert('Please provide an admin note before continuing.')
    return
  }

  if (!window.confirm('This action cannot be undone. Are you sure you want to continue?')) {
    return
  }

  reportSubmitting.value = true
  try {
    await taskApi.resolveReport(selectedReport.value.id, {
      decision: reportAction.value,
      notes: reportNotes.value.trim()
    })
    alert('Report handled successfully.')
    closeReportModal()
    await loadTask()
  } catch (err: any) {
    alert(err.response?.data?.message || err.message || 'Failed to resolve report')
  } finally {
    reportSubmitting.value = false
  }
}

const handleOperationClick = () => {
  if (operationBlocked.value) {
    alert(operationGuardMessage)
    return
  }
  operationAction.value = 'cancel'
  operationReason.value = ''
  showOperationModal.value = true
}

const closeOperationModal = () => {
  showOperationModal.value = false
}

const submitOperation = async () => {
  if (!task.value) return

  if (!operationReason.value.trim()) {
    alert('Please provide a reason for this action.')
    return
  }

  if (operationReason.value.trim().length < 10) {
    alert('Reason must be at least 10 characters to proceed.')
    return
  }

  if (!window.confirm('This action cannot be undone. Are you sure you want to proceed?')) {
    return
  }

  operationSubmitting.value = true
  try {
    await taskApi.moderate(String(task.value.id), {
      action: operationAction.value,
      reason: operationReason.value.trim()
    })
    alert('Task status updated.')
    closeOperationModal()
    await loadTask()
  } catch (err: any) {
    alert(err.response?.data?.message || err.message || 'Failed to update task')
  } finally {
    operationSubmitting.value = false
  }
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

const formatCountdown = (seconds: number) => {
  const s = Math.max(0, Math.floor(seconds))
  const d = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  const ss = s % 60
  if (d > 0) return `${d}d ${h}h ${m}m`
  if (h > 0) return `${h}h ${m}m ${ss}s`
  if (m > 0) return `${m}m ${ss}s`
  return `${ss}s`
}

// Lifecycle
onMounted(() => {
  loadTask()
})
</script>
