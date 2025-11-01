<template>
  <div class="fixed inset-0 z-[60] overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
      <!-- Background overlay -->
      <div 
        class="fixed inset-0 bg-gray-500/60 transition-opacity" 
        aria-hidden="true"
        @click="$emit('close')"
      ></div>

      <!-- Modal panel -->
      <div class="relative z-[61] inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full sm:p-6">
        <!-- Debug Info (temporary) -->
        <div v-if="!dispute" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <h4 class="text-red-800 font-medium">⚠️ Debug: Dispute data is null</h4>
          <p class="text-red-600 text-sm mt-1">
            The dispute prop is null or undefined. Please check the data structure.
          </p>
          <pre class="text-xs mt-2 bg-red-100 p-2 rounded">{{ JSON.stringify(dispute, null, 2) }}</pre>
        </div>
        
        
        <div class="sm:flex sm:items-start bg-red-50 p-2">
          <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
            <Icon name="gavel" class="h-6 w-6 text-red-600" />
          </div>
          <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left flex-1">
            <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
              Admin Dispute Operation #{{ dispute?.id || 'Unknown' }}
            </h3>
            <div class="mt-2">
              <p class="text-sm text-gray-500">
                Make a decision to resolve this task dispute. This action cannot be undone.
              </p>
            </div>
          </div>
        </div>

        <!-- Dispute Information -->
        <div class="mt-6 bg-gray-50 rounded-lg p-4">
          <h4 class="text-sm font-medium text-gray-900 mb-3">Dispute Information</h4>
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">Task</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ dispute?.task?.title || 'Unknown Task' }}</dd>
            </div>
            <div>
              <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">Reward</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ dispute?.task?.reward_point || 0 }} points</dd>
            </div>
            <div>
              <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">Submitter</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ dispute?.submitter?.name || 'Unknown User' }}</dd>
            </div>
            <div>
              <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">Created</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ formatDateTime(dispute?.created_at) || 'Unknown' }}</dd>
            </div>
          </div>
          <div class="mt-3">
            <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">Dispute Title</dt>
            <dd class="mt-1 text-sm text-gray-900">{{ dispute?.dispute_title || 'No title' }}</dd>
          </div>
          <div class="mt-3">
            <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">Description</dt>
            <dd class="mt-1 text-sm text-gray-900 whitespace-pre-wrap">{{ dispute?.description || 'No description' }}</dd>
          </div>
        </div>

        <!-- Decision Form -->
        <form @submit.prevent="submitDecision" class="mt-6">
          <!-- Decision Options -->
          <div class="space-y-4">
            <div>
              <label class="text-base font-medium text-gray-900">Decision</label>
              <p class="text-sm leading-5 text-gray-500">Choose the resolution for this dispute</p>
              <fieldset class="mt-4">
                <legend class="sr-only">Decision options</legend>
                <div class="space-y-1">
                  <label class="flex items-start cursor-pointer hover:bg-gray-50 p-2 rounded-lg transition-colors">
                    <input
                      id="completed"
                      v-model="form.decisionResult"
                      name="decision"
                      type="radio"
                      value="completed"
                      class="focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 mt-0.5"
                    />
                    <div class="ml-3 text-sm">
                      <div class="font-medium text-gray-700">Mark Task as Completed</div>
                      <p class="text-gray-500">
                        Award points to  tasker, deduct fees from creator, and mark task as completed.
                      </p>
                    </div>
                  </label>

                  <label class="flex items-start cursor-pointer hover:bg-gray-50 p-3 rounded-lg transition-colors">
                    <input
                      id="back_to_progress"
                      v-model="form.decisionResult"
                      name="decision"
                      type="radio"
                      value="back_to_progress"
                      class="focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 mt-0.5"
                    />
                    <div class="ml-3 text-sm">
                      <div class="font-medium text-gray-700">Back to Progress</div>
                      <p class="text-gray-500">
                        Reject the dispute and return the task to in-progress status for continued work.
                      </p>
                    </div>
                  </label>

                  <label class="flex items-start cursor-pointer hover:bg-gray-50 p-3 rounded-lg transition-colors">
                    <input
                      id="reset"
                      v-model="form.decisionResult"
                      name="decision"
                      type="radio"
                      value="reset"
                      class="focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 mt-0.5"
                    />
                    <div class="ml-3 text-sm">
                      <div class="font-medium text-gray-700">Reset Task</div>
                      <p class="text-gray-500">
                        Reset task to open status, remove current tasker, and allow new applications.
                      </p>
                    </div>
                  </label>
                </div>
              </fieldset>
            </div>

            <!-- Decision Note -->
            <div>
              <label for="decision-note" class="block text-sm font-medium text-gray-700">
                Decision Explanation <span class="text-red-500">*</span>
              </label>
              <div class="mt-1">
                <textarea
                  id="decision-note"
                  v-model="form.decisionNote"
                  name="decision-note"
                  rows="4"
                  required
                  class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  placeholder="Provide a detailed explanation for your decision...(At least 10 characters)"
                ></textarea>
              </div>
              <p class="mt-2 text-sm text-gray-500">
                This explanation will be sent to both parties and recorded in the dispute log.
              </p>
            </div>
          </div>

          <!-- Form Validation Errors -->
          <div v-if="formErrors.length > 0" class="mt-4 bg-red-50 border border-red-200 rounded-md p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <Icon name="exclamation-circle" class="h-5 w-5 text-red-400" />
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-800">Please fix the following errors:</h3>
                <div class="mt-2 text-sm text-red-700">
                  <ul role="list" class="list-disc pl-5 space-y-1">
                    <li v-for="error in formErrors" :key="error">{{ error }}</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>

          <!-- Actions -->
          <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-3">
            <button
              type="button"
              @click="$emit('close')"
              :disabled="submitting"
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="submitting || !isFormValid"
              class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Icon v-if="submitting" name="loading" class="animate-spin -ml-1 mr-2 h-4 w-4" />
              {{ submitting ? 'Resolving...' : 'Resolve Dispute' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { disputeApi } from '@/services/api'
import Icon from '@/components/Icon.vue'

interface Dispute {
  id: number
  task_id: string
  dispute_title: string
  description: string
  status: string
  created_at: string
  task: {
    title: string
    reward_point: number
  }
  submitter: {
    name: string
  }
}

interface Props {
  dispute: Dispute | null
}

interface Emits {
  (e: 'close'): void
  (e: 'resolved'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

// Form data
const form = reactive({
  decisionResult: '',
  decisionNote: ''
})

const submitting = ref(false)
const formErrors = ref<string[]>([])

// Computed
const isFormValid = computed(() => {
  return form.decisionResult && form.decisionNote.trim().length >= 10
})

// Methods
const validateForm = () => {
  const errors: string[] = []
  
  if (!form.decisionResult) {
    errors.push('Please select a decision option')
  }
  
  if (!form.decisionNote.trim()) {
    errors.push('Decision explanation is required')
  } else if (form.decisionNote.trim().length < 10) {
    errors.push('Decision explanation must be at least 10 characters')
  }
  
  formErrors.value = errors
  return errors.length === 0
}

const submitDecision = async () => {
  if (!validateForm() || !props.dispute) {
    return
  }
  
  submitting.value = true
  formErrors.value = []
  
  try {
    await disputeApi.resolve(props.dispute.id.toString(), form.decisionResult, form.decisionNote.trim())
    
    // Show success message (you might want to use a toast/notification system)
    console.log('Dispute resolved successfully')
    
    emit('resolved')
  } catch (error: any) {
    console.error('Failed to resolve dispute:', error)
    formErrors.value = [error.message || 'Failed to resolve dispute']
  } finally {
    submitting.value = false
  }
}

const formatDateTime = (dateTimeStr?: string) => {
  if (!dateTimeStr) return ''
  return new Date(dateTimeStr).toLocaleString()
}
</script>
