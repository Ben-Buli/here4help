<template>
  <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
      <!-- Background overlay -->
      <div 
        class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" 
        aria-hidden="true"
        @click="$emit('close')"
      ></div>

      <!-- Modal panel -->
      <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full sm:p-6">
        <div class="sm:flex sm:items-start">
          <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 sm:mx-0 sm:h-10 sm:w-10">
            <Icon name="document-text" class="h-6 w-6 text-blue-600" />
          </div>
          <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left flex-1">
            <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
              Dispute Details #{{ dispute?.id }}
            </h3>
            <div class="mt-2">
              <p class="text-sm text-gray-500">
                Complete information about this task dispute
              </p>
            </div>
          </div>
          <button
            @click="$emit('close')"
            class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
          >
            <span class="sr-only">Close</span>
            <Icon name="x-mark" class="h-6 w-6" />
          </button>
        </div>

        <div class="mt-6">
          <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <!-- Left Column: Dispute Information -->
            <div class="space-y-6">
              <!-- Basic Information -->
              <div class="bg-white border border-gray-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-gray-900 mb-4">Dispute Information</h4>
                <dl class="space-y-3">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Dispute ID</dt>
                    <dd class="mt-1 text-sm text-gray-900">#{{ dispute?.id }}</dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Title</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.dispute_title }}</dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Status</dt>
                    <dd class="mt-1">
                      <span :class="getStatusBadgeClass(dispute?.status)" class="inline-flex px-2 py-1 text-xs font-semibold rounded-full">
                        {{ getStatusDisplayName(dispute?.status) }}
                      </span>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Submitted</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ formatDateTime(dispute?.created_at) }}</dd>
                  </div>
                  <div v-if="dispute?.updated_at !== dispute?.created_at">
                    <dt class="text-sm font-medium text-gray-500">Last Updated</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ formatDateTime(dispute?.updated_at) }}</dd>
                  </div>
                </dl>
              </div>

              <!-- Task Information -->
              <div class="bg-white border border-gray-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-gray-900 mb-4">Task Information</h4>
                <dl class="space-y-3">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Task Title</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.task?.title }}</dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Reward</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.task?.reward_point }} points</dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Creator</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.task?.creator_name }}</dd>
                  </div>
                  <div v-if="dispute?.task?.participant_name">
                    <dt class="text-sm font-medium text-gray-500">Participant</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.task?.participant_name }}</dd>
                  </div>
                </dl>
              </div>

              <!-- Submitter Information -->
              <div class="bg-white border border-gray-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-gray-900 mb-4">Submitted By</h4>
                <dl class="space-y-3">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Name</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.submitter?.name }}</dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Email</dt>
                    <dd class="mt-1 text-sm text-gray-900">{{ dispute?.submitter?.email }}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <!-- Right Column: Description and Resolution -->
            <div class="space-y-6">
              <!-- Description -->
              <div class="bg-white border border-gray-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-gray-900 mb-4">Dispute Description</h4>
                <div class="prose prose-sm max-w-none">
                  <p class="text-sm text-gray-700 whitespace-pre-wrap">{{ dispute?.description }}</p>
                </div>
              </div>

              <!-- Resolution (if resolved) -->
              <div v-if="dispute?.status === 'resolved'" class="bg-green-50 border border-green-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-green-900 mb-4 flex items-center">
                  <Icon name="check-circle" class="mr-2 h-5 w-5 text-green-500" />
                  Resolution
                </h4>
                <dl class="space-y-3">
                  <div v-if="dispute?.decision_result">
                    <dt class="text-sm font-medium text-green-700">Decision</dt>
                    <dd class="mt-1">
                      <span :class="getDecisionBadgeClass(dispute.decision_result)" class="inline-flex px-2 py-1 text-xs font-semibold rounded-full">
                        {{ getDecisionDisplayName(dispute.decision_result) }}
                      </span>
                    </dd>
                  </div>
                  <div v-if="dispute?.decision_note">
                    <dt class="text-sm font-medium text-green-700">Admin Notes</dt>
                    <dd class="mt-1 text-sm text-green-800 whitespace-pre-wrap">{{ dispute.decision_note }}</dd>
                  </div>
                  <div v-if="dispute?.admin_username">
                    <dt class="text-sm font-medium text-green-700">Resolved By</dt>
                    <dd class="mt-1 text-sm text-green-800">{{ dispute.admin_username }}</dd>
                  </div>
                </dl>
              </div>

              <!-- In Progress (if in progress) -->
              <div v-else-if="dispute?.status === 'in_progress'" class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-blue-900 mb-4 flex items-center">
                  <Icon name="clock" class="mr-2 h-5 w-5 text-blue-500" />
                  In Progress
                </h4>
                <p class="text-sm text-blue-800">
                  This dispute is currently being reviewed by an administrator.
                </p>
                <div v-if="dispute?.admin_username" class="mt-3">
                  <dt class="text-sm font-medium text-blue-700">Assigned To</dt>
                  <dd class="mt-1 text-sm text-blue-800">{{ dispute.admin_username }}</dd>
                </div>
              </div>

              <!-- Submitted (if submitted) -->
              <div v-else-if="dispute?.status === 'submitted'" class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <h4 class="text-lg font-medium text-yellow-900 mb-4 flex items-center">
                  <Icon name="exclamation-triangle" class="mr-2 h-5 w-5 text-yellow-500" />
                  Awaiting Review
                </h4>
                <p class="text-sm text-yellow-800">
                  This dispute has been submitted and is waiting for administrator review.
                </p>
              </div>

              <!-- Action Buttons -->
              <div class="flex space-x-3">
                <button
                  @click="viewChatRoom"
                  class="flex-1 inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  <Icon name="chat" class="mr-2 h-4 w-4" />
                  View Chat Room
                </button>
                
                <button
                  v-if="dispute?.status !== 'resolved'"
                  @click="openOperationDialog"
                  class="flex-1 inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                >
                  <Icon name="gavel" class="mr-2 h-4 w-4" />
                  Resolve Dispute
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import Icon from '@/components/Icon.vue'

interface Dispute {
  id: number
  task_id: string
  dispute_title: string
  description: string
  status: string
  decision_result?: string
  decision_note?: string
  admin_username?: string
  created_at: string
  updated_at: string
  task: {
    title: string
    reward_point: number
    creator_name: string
    participant_name?: string
  }
  submitter: {
    name: string
    email: string
  }
}

interface Props {
  dispute: Dispute | null
}

interface Emits {
  (e: 'close'): void
  (e: 'openOperation'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const router = useRouter()

// Methods
const getStatusBadgeClass = (status?: string) => {
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

const getStatusDisplayName = (status?: string) => {
  switch (status) {
    case 'submitted':
      return 'Submitted'
    case 'in_progress':
      return 'In Progress'
    case 'resolved':
      return 'Resolved'
    default:
      return status || 'Unknown'
  }
}

const getDecisionBadgeClass = (decision?: string) => {
  switch (decision) {
    case 'completed':
      return 'bg-green-100 text-green-800'
    case 'back_to_progress':
      return 'bg-blue-100 text-blue-800'
    case 'reset':
      return 'bg-orange-100 text-orange-800'
    default:
      return 'bg-gray-100 text-gray-800'
  }
}

const getDecisionDisplayName = (decision?: string) => {
  switch (decision) {
    case 'completed':
      return 'Task Completed'
    case 'back_to_progress':
      return 'Back to Progress'
    case 'reset':
      return 'Task Reset'
    default:
      return decision || 'Unknown'
  }
}

const formatDateTime = (dateTimeStr?: string) => {
  if (!dateTimeStr) return ''
  return new Date(dateTimeStr).toLocaleString()
}

const viewChatRoom = () => {
  if (props.dispute) {
    router.push(`/task-disputes/${props.dispute.id}/chat-room`)
    emit('close')
  }
}

const openOperationDialog = () => {
  emit('openOperation')
  emit('close')
}
</script>
