<template>
  <div class="fixed inset-0 z-50 overflow-y-auto">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
      <!-- 背景遮罩 -->
      <div class="fixed inset-0 transition-opacity" @click="$emit('close')">
        <div class="absolute inset-0 bg-gray-500 opacity-75"></div>
      </div>

      <!-- 模態框內容 -->
      <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full relative z-10">
        <!-- 標題 -->
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              User Verification Review
            </h3>
            <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- 內容 -->
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6">
          <div v-if="loading" class="flex justify-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>

          <div v-else class="space-y-6">
            <!-- 用戶基本信息 -->
            <div class="bg-gray-50 rounded-lg p-4">
              <h4 class="text-lg font-medium text-gray-900 mb-4">User Basic Information</h4>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Name</label>
                  <p class="mt-1 text-sm text-gray-900">{{ user?.name || 'N/A' }}</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Email</label>
                  <p class="mt-1 text-sm text-gray-900">{{ user?.email || 'N/A' }}</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">User ID</label>
                  <p class="mt-1 text-sm text-gray-900">{{ user?.id || 'N/A' }}</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Registration Date</label>
                  <p class="mt-1 text-sm text-gray-900">{{ formatDate(user?.created_at) }}</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Current Status</label>
                  <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">
                    Unverified (Permission: 0)
                  </span>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Intro Referral Code</label>
                  <p class="mt-1 text-sm text-gray-900">{{ user?.intro_referral_code ? `${user?.intro_referral_code} ✅` : 'None' }}</p>
                </div>
                
              </div>
              
              <!-- 推薦碼資訊 -->
              <!-- <div v-if="referralInfo" class="mt-4 pt-4 border-t border-gray-200">
                <h5 class="text-md font-medium text-gray-900 mb-3">Referral Information</h5>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-3">
                  <div class="flex items-center mb-2">
                    <svg class="w-4 h-4 text-blue-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7"></path>
                    </svg>
                    <span class="text-sm font-medium text-blue-900">
                      This user was referred by: {{ referralInfo.referrer?.name || 'Unknown' }}
                    </span>
                  </div>
                  <div class="text-xs text-blue-700">
                    <p>被推薦碼: <span class="font-mono font-semibold">{{ referralInfo.intro_referral_code }}</span></p>
                    <p v-if="referralInfo.referrer">推薦人: {{ referralInfo.referrer.name }} (ID: {{ referralInfo.referrer.id }})</p>
                    <p v-if="referralInfo.referral_event">狀態: 
                      <span :class="referralInfo.referral_event.status === 'completed' ? 'text-green-600' : 'text-yellow-600'">
                        {{ referralInfo.referral_event.status === 'completed' ? 'Completed' : 'Pending' }}
                      </span>
                    </p>
                    <p v-if="referralInfo.referral_event">
                      獎勵點數: {{ referralInfo.referral_event.reward_points }} 點數 
                      <span v-if="referralInfo.referral_event.status === 'completed'">(已發放給推薦人)</span>
                      <span v-else>(審核通過後發放給推薦人)</span>
                    </p>
                    <p v-if="referralInfo.error" class="text-red-600">
                      錯誤: {{ referralInfo.error }}
                    </p>
                  </div>
                </div>
              </div> -->
            </div>

            <!-- 驗證文件 -->
            <div class="bg-white border border-gray-200 rounded-lg p-4">
              <h4 class="text-lg font-medium text-gray-900 mb-4">Verification Documents</h4>
              
              <div v-if="verificationData">
                <!-- 學生證圖片 -->
                <div v-if="verificationData.student_id_image" class="mb-6">Verification Documents
                  <label class="block text-sm font-medium text-gray-700 mb-2">Student ID Card Image</label>
                  <div class="border border-gray-300 rounded-lg p-4 bg-gray-50">
                    <img 
                      :src="verificationData.student_id_image" 
                      alt="Student ID Card"
                      class="max-w-full h-auto max-h-96 mx-auto rounded-lg shadow-sm cursor-pointer hover:shadow-md transition-shadow"
                      @click="openImageModal(verificationData.student_id_image)"
                      @error="handleImageError"
                    />
                    <p class="text-xs text-gray-500 text-center mt-2">Click to view full size</p>
                  </div>
                </div>

                <!-- 學生證資料 -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Student Name</label>
                    <p class="mt-1 text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded-md">
                      {{ verificationData.student_name || 'N/A' }}
                    </p>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Student ID Number</label>
                    <p class="mt-1 text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded-md">
                      {{ verificationData.student_id || 'N/A' }}
                    </p>
                  </div>
                  <div class="md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700">School Name</label>
                    <p class="mt-1 text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded-md">
                      {{ verificationData.school_name || 'N/A' }}
                    </p>
                  </div>
                </div>

                <!-- 驗證狀態和備註 -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Current Verification Status</label>
                    <span
                      class="inline-flex px-2 py-1 text-xs font-semibold rounded-full mt-1"
                      :class="verificationStatusDisplay(verificationData).badgeClass"
                    >
                      {{ verificationStatusDisplay(verificationData).label }}
                    </span>
                  </div>
                  <div v-if="verificationData.admin_id">
                    <label class="block text-sm font-medium text-gray-700">Reviewed by Admin</label>
                    <p class="mt-1 text-sm text-gray-900">Admin ID: {{ verificationData.admin_id }}</p>
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div v-if="verificationData.submission_count">
                    <label class="block text-sm font-medium text-gray-700">Submission Attempt</label>
                    <p class="mt-1 text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded-md">
                      {{ submissionAttemptLabel(verificationData) }}
                    </p>
                  </div>
                  <div v-if="verificationData.previous_status">
                    <label class="block text-sm font-medium text-gray-700">Previous Status</label>
                    <p class="mt-1 text-sm text-gray-900 bg-gray-50 px-3 py-2 rounded-md">
                      {{ formatStatusText(verificationData.previous_status) }}
                    </p>
                  </div>
                </div>

                <!-- 審核備註 (如果有) -->
                <div v-if="verificationData.verification_notes" class="mb-4">
                  <label class="block text-sm font-medium text-gray-700">Previous Review Notes</label>
                  <div class="mt-1 text-sm text-gray-900 bg-yellow-50 border border-yellow-200 px-3 py-2 rounded-md">
                    {{ verificationData.verification_notes }}
                  </div>
                </div>

                <!-- 時間資訊 -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4 border-t border-gray-200">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Submitted At</label>
                    <p class="mt-1 text-sm text-gray-500">{{ formatDate(verificationData.created_at) }}</p>
                  </div>
                  <div v-if="verificationData.updated_at !== verificationData.created_at">
                    <label class="block text-sm font-medium text-gray-700">Last Updated</label>
                    <p class="mt-1 text-sm text-gray-500">{{ formatDate(verificationData.updated_at) }}</p>
                  </div>
                </div>
              </div>

              <div v-else class="text-center py-8 text-gray-500">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                <p class="mt-2">No verification documents found</p>
              </div>
            </div>

            <!-- 審核決定 -->
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h4 class="text-lg font-medium text-gray-900 mb-4">Review Decision</h4>
              
              <div class="space-y-4">
                <!-- 審核結果選擇 -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Decision <span class="text-red-500">*</span>
                  </label>
                  <div class="space-y-2" :class="{ 'border border-red-500 rounded p-2': !reviewDecision && showValidationErrors }">
                    <label class="flex items-center">
                      <input 
                        v-model="reviewDecision" 
                        type="radio" 
                        value="approve" 
                        required
                        class="mr-2 text-green-600 focus:ring-green-500"
                      />
                      <span class="text-green-700 font-medium">Approve - Grant verified status (Permission: 1)</span>
                    </label>
                    <label class="flex items-center">
                      <input 
                        v-model="reviewDecision" 
                        type="radio" 
                        value="reject" 
                        required
                        class="mr-2 text-red-600 focus:ring-red-500"
                      />
                      <span class="text-red-700 font-medium">Reject - Keep unverified status (Permission: 0)</span>
                    </label>
                  </div>
                  <p v-if="!reviewDecision && showValidationErrors" class="mt-1 text-sm text-red-600">
                    請選擇審核結果
                  </p>
                </div>

                <!-- 審核備註 -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Review Notes <span class="text-red-500">*</span>
                  </label>
                  <textarea
                    v-model="reviewNotes"
                    rows="3"
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    :class="{ 'border-red-500': !reviewNotes.trim() && showValidationErrors }"
                    placeholder="Please enter review notes (required)..."
                  ></textarea>
                  <p v-if="!reviewNotes.trim() && showValidationErrors" class="mt-1 text-sm text-red-600">
                    Review notes are required
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 操作按鈕 -->
        <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
          <button
            @click="submitReview"
            :disabled="!canSubmit || submitting"
            class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 text-base font-medium text-white focus:outline-none focus:ring-2 focus:ring-offset-2 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            :class="reviewDecision === 'approve' ? 'bg-green-600 hover:bg-green-700 focus:ring-green-500' : 'bg-red-600 hover:bg-red-700 focus:ring-red-500'"
          >
            <svg v-if="submitting" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ submitting ? 'Processing...' : (reviewDecision === 'approve' ? 'Approve User' : 'Reject Application') }}
          </button>
          <button
            @click="$emit('close')"
            :disabled="submitting"
            class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>

    <!-- 圖片放大模態框 -->
    <div v-if="showImageModal" class="fixed inset-0 z-[60] overflow-y-auto bg-black bg-opacity-90" @click="closeImageModal">
      <div class="flex items-center justify-center min-h-screen p-4">
        <img 
          :src="selectedImage" 
          alt="Student ID Card - Full Size"
          class="max-w-full max-h-full object-contain"
          @click.stop
        />
        <button 
          @click="closeImageModal"
          class="absolute top-4 right-4 text-white hover:text-gray-300"
        >
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { userApi } from '@/services/api'

interface Props {
  user: any
}

const props = defineProps<Props>()
const emit = defineEmits(['close', 'reviewed'])

// 狀態
const loading = ref(false)
const submitting = ref(false)
const verificationData = ref<any>(null)
const referralInfo = ref<any>(null)
const reviewDecision = ref<'approve' | 'reject' | ''>('')
const reviewNotes = ref('')
const showValidationErrors = ref(false)

// 圖片模態框
const showImageModal = ref(false)
const selectedImage = ref('')

// 計算屬性
const canSubmit = computed(() => {
  return !!verificationData.value && reviewDecision.value && reviewNotes.value.trim()
})

// 載入驗證資料
const loadVerificationData = async () => {
  if (!props.user?.id) return
  
  loading.value = true
  try {
    // 使用統一的 API 服務
    const response = await userApi.verification(props.user.id)
    if (response.data.success && response.data.data) {
      verificationData.value = response.data.data.verification
      console.log('Loaded verification data:', verificationData.value)
    }
  } catch (error) {
    console.error('Failed to load verification data:', error)
  }
  
  // 載入推薦碼資訊
  try {
    const referralResponse = await userApi.introReferralInfo(props.user.id)
    if (referralResponse.data.success && referralResponse.data.data) {
      referralInfo.value = referralResponse.data.data
      console.log('Loaded referral info:', referralInfo.value)
    }
  } catch (error) {
    console.error('Failed to load referral info:', error)
  } finally {
    loading.value = false
  }
}

// 提交審核
const submitReview = async () => {
  // 驗證表單
  if (!reviewDecision.value || !reviewNotes.value.trim()) {
    showValidationErrors.value = true
    return
  }

  if (!verificationData.value) {
    alert('Review data is unavailable. Please reload and try again.')
    return
  }
  
  if (!props.user?.id) {
    alert('User ID is missing')
    return
  }
  
  submitting.value = true
  try {
    const response = await userApi.review(props.user.id, {
      decision: reviewDecision.value,
      notes: reviewNotes.value.trim(),
      new_permission: reviewDecision.value === 'approve' ? 1 : 0, // 駁回維持未驗證
    })
    
    if (response.data.success) {
      const result = response.data
      let message = `審核${reviewDecision.value === 'approve' ? 'Approve' : 'Reject'}成功！`
      
      if (result.data?.referral_reward) {
        message += `\nReferral reward of ${result.data.referral_reward.reward_points} points awarded to ${result.data.referral_reward.referrer_name}`
      }
      if (result.data?.referral_code_generated) {
        message += `\nReferral code generated for user: ${result.data.referral_code_generated}`
      }
      
      alert(message)
      emit('reviewed')
    } else {
      alert('Review failed: ' + (response.data.message || 'Unknown error'))
    }
  } catch (error: any) {
    console.error('Failed to submit review:', error)
    const errorMessage =
      error.response?.data?.message ||
      error.response?.data?.error ||
      error.message ||
      'Network error'
    alert('Review failed: ' + errorMessage)
  } finally {
    submitting.value = false
  }
}

// 圖片相關
const openImageModal = (imageUrl: string) => {
  selectedImage.value = imageUrl
  showImageModal.value = true
}

const closeImageModal = () => {
  showImageModal.value = false
  selectedImage.value = ''
}

// 工具函數
const formatDate = (dateString: string | null) => {
  if (!dateString) return 'N/A'
  return new Date(dateString).toLocaleString()
}

type StatusDisplay = { label: string; badgeClass: string }

const verificationStatusDisplay = (verification: any): StatusDisplay => {
  if (!verification) {
    return { label: 'No data', badgeClass: 'bg-gray-100 text-gray-800' }
  }

  const status = verification.verification_status || 'pending'
  const requiresReReview = verification.requires_re_review === true

  if (status === 'pending' && requiresReReview) {
    return { label: 'Re-review', badgeClass: 'bg-cyan-100 text-cyan-800' }
  }

  const statusMap: Record<string, StatusDisplay> = {
    pending: { label: 'Pending Review', badgeClass: 'bg-yellow-100 text-yellow-800' },
    approved: { label: 'Approved', badgeClass: 'bg-green-100 text-green-800' },
    rejected: { label: 'Rejected', badgeClass: 'bg-red-100 text-red-800' },
  }

  return statusMap[status] || {
    label: (status as string).replace('_', ' '),
    badgeClass: 'bg-gray-100 text-gray-800',
  }
}

const submissionAttemptLabel = (verification: any) => {
  const count = Number(verification?.submission_count || 0)
  if (!count) return 'Unknown'
  if (count === 1) return 'First submission'
  return `Submission #${count}`
}

const formatStatusText = (status?: string | null) => {
  if (!status) return 'Unknown'
  return status
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

const handleImageError = (event: Event) => {
  const img = event.target as HTMLImageElement
  img.style.display = 'none'
  console.error('Failed to load student ID image:', img.src)
}

// 生命週期
onMounted(() => {
  loadVerificationData()
})
</script>
