<template>
  <div class="space-y-6">
    <!-- Loading State -->
    <div v-if="isLoading" class="flex justify-center py-12">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-center py-12">
      <div class="text-red-600 mb-4">{{ error }}</div>
      <button @click="loadUser" class="admin-button-primary">Retry</button>
    </div>

    <!-- User Detail Content -->
    <div v-else-if="user">
      <!-- Header -->
      <div class="md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <nav class="flex mb-4" aria-label="Breadcrumb">
            <ol class="flex items-center space-x-4">
              <li>
                <router-link to="/users" class="text-gray-400 hover:text-gray-500">
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
                    to="/users"
                    class="ml-4 text-sm font-medium text-gray-500 hover:text-gray-700"
                  >
                    Users
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
                  <span class="ml-4 text-sm font-medium text-gray-900">{{ user.name }}</span>
                </div>
              </li>
            </ol>
          </nav>

          <div class="flex items-center space-x-4">
            <div class="flex-shrink-0 h-16 w-16">
              <div class="h-16 w-16 rounded-full bg-gray-300 flex items-center justify-center">
                <span class="text-xl font-medium text-gray-700">
                  {{ getUserInitials(user.name) }}
                </span>
              </div>
            </div>
            <div>
              <h1 class="text-2xl font-bold text-gray-900">{{ user.name }}</h1>
              <p class="text-sm text-gray-500">{{ user.email }}</p>
              <div class="flex items-center space-x-4 mt-2">
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(user.status)"
                >
                  {{ getStatusText(user.status) }}
                </span>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getPermissionBadgeClass(user.permission)"
                >
                  {{ getPermissionText(user.permission) }}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
          <button
            @click="openStudentReview"
            class="admin-button-secondary"
            :disabled="!user.student_verification"
          >
            Review Student ID
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

      <!-- User Information Cards -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- Basic Information -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Basic Information</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">User ID</dt>
              <dd class="text-sm text-gray-900">{{ user.id }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Name</dt>
              <dd class="text-sm text-gray-900">{{ user.name }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Email</dt>
              <dd class="text-sm text-gray-900">{{ user.email }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Phone</dt>
              <dd class="text-sm text-gray-900">{{ user.phone || 'Not provided' }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Address</dt>
              <dd class="text-sm text-gray-900">{{ user.address || 'Not provided' }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">University</dt>
              <dd class="text-sm text-gray-900">{{ user.university || 'Not provided' }}</dd>
            </div>
          </dl>
        </div>

        <!-- Account Status -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Account Status</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(user.status)"
                >
                  {{ getStatusText(user.status) }}
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Permission Level</dt>
              <dd>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getPermissionBadgeClass(user.permission)"
                >
                  {{ getPermissionText(user.permission) }}
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Points</dt>
              <dd class="text-sm text-gray-900">{{ user.points || 0 }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Email Verified</dt>
              <dd class="text-sm text-gray-900">
                {{ user.email_verified_at ? 'Yes' : 'No' }}
                <span v-if="user.email_verified_at" class="text-gray-500">
                  ({{ formatDate(user.email_verified_at) }})
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Last Login</dt>
              <dd class="text-sm text-gray-900">{{ formatDate(user.last_login) }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Registered</dt>
              <dd class="text-sm text-gray-900">{{ formatDate(user.created_at) }}</dd>
            </div>
          </dl>
        </div>

        <!-- Student Verification -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Student Verification</h3>
          <div v-if="!user.student_verification" class="text-sm text-gray-500">No verification data</div>
          <dl v-else class="space-y-3 text-sm">
            <div>
              <dt class="text-gray-500">School</dt>
              <dd class="text-gray-900">{{ user.student_verification.school_name }}</dd>
            </div>
            <div>
              <dt class="text-gray-500">Student Name</dt>
              <dd class="text-gray-900">{{ user.student_verification.student_name }}</dd>
            </div>
            <div>
              <dt class="text-gray-500">Student ID</dt>
              <dd class="text-gray-900">{{ user.student_verification.student_id }}</dd>
            </div>
            <div>
              <dt class="text-gray-500">Status</dt>
              <dd>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="studentStatusBadge(user.student_verification.verification_status)">
                  {{ (user.student_verification.verification_status || '').replace('_', ' ') }}
                </span>
              </dd>
            </div>
            <div v-if="user.student_verification.verification_notes">
              <dt class="text-gray-500">Notes</dt>
              <dd class="text-gray-900">{{ user.student_verification.verification_notes }}</dd>
            </div>
          </dl>
          <div v-if="user.student_verification && user.student_verification.student_id_image_path">
            <dt class="text-gray-500">Student ID Image</dt>
            <dd>
              <img
                :src="getImageUrl(user.student_verification.student_id_image_path)"
                alt="Student ID"
                class="h-32 rounded border cursor-pointer"
                @click="openImage(user.student_verification.student_id_image_path)"
              />
            </dd>
          </div>
        </div>

        <!-- Statistics -->
        <div class="admin-card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Statistics</h3>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Tasks Created</dt>
              <dd class="text-sm text-gray-900">{{ stats.total_tasks_created || 0 }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Tasks Applied</dt>
              <dd class="text-sm text-gray-900">{{ stats.total_tasks_applied || 0 }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Tasks as Participant</dt>
              <dd class="text-sm text-gray-900">{{ stats.tasks_as_participant || 0 }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Current Points</dt>
              <dd class="text-sm text-gray-900">{{ stats.current_points || 0 }}</dd>
            </div>
          </dl>
        </div>
      </div>

      <!-- Recent Activities -->
      <div class="admin-card">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Activities</h3>
        <div v-if="recentActivities.length === 0" class="text-center py-4 text-gray-500">
          No recent activities
        </div>
        <div v-else class="space-y-3">
          <div
            v-for="activity in recentActivities"
            :key="activity.id"
            class="flex items-center justify-between py-2 border-b border-gray-200 last:border-b-0"
          >
            <div class="flex items-center space-x-3">
              <div class="flex-shrink-0 w-2 h-2 bg-blue-400 rounded-full"></div>
              <div>
                <p class="text-sm font-medium text-gray-900">{{ activity.title }}</p>
                <p class="text-sm text-gray-500">{{ activity.status }}</p>
              </div>
            </div>
            <div class="text-sm text-gray-400">
              {{ formatDate(activity.created_at) }}
            </div>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { userApi } from '@/services/api'
import { getImageUrl } from '@/config/api'
import UserReviewModal from '@/components/UserReviewModal.vue'

const route = useRoute()
const router = useRouter()

// State
const isLoading = ref(false)
const error = ref('')
type StudentVerification = {
  school_name?: string
  student_name?: string
  student_id?: string
  student_id_image_path?: string
  verification_status?: string
  verification_notes?: string
}

type UserWithStudent = any & { student_verification?: StudentVerification | null }

const user = ref<UserWithStudent | null>(null)
const stats = ref<any>({})
const recentActivities = ref<any[]>([])
const showImageModal = ref(false)
const selectedImagePath = ref('')
const showReviewModal = ref(false)

// Methods
const loadUser = async () => {
  try {
    isLoading.value = true
    error.value = ''

    const userId = parseInt(route.params.id as string)
    if (isNaN(userId)) {
      throw new Error('Invalid user ID')
    }

    const response = await userApi.show(userId)

    if (response.data.success && response.data.data) {
      user.value = {
        ...response.data.data.user,
        student_verification: response.data.data.student_verification || null,
      }
      stats.value = response.data.data.stats || {}
      recentActivities.value = response.data.data.recent_activities || []
    } else {
      throw new Error('User not found')
    }
  } catch (err: any) {
    error.value = err.response?.data?.message || err.message || 'Failed to load user'
    if (err.response?.status === 404) {
      router.push('/users')
    }
  } finally {
    isLoading.value = false
  }
}

const refreshData = () => {
  loadUser()
}

const openStudentReview = () => {
  if (!user.value?.student_verification) return
  selectedImagePath.value = ''
  showReviewModal.value = true
}

const handleStudentReviewed = () => {
  showReviewModal.value = false
  refreshData()
}


const openImage = (path: string) => {
  selectedImagePath.value = getImageUrl(path)
  showImageModal.value = true
}

// Utility functions
const getUserInitials = (name: string | null) => {
  if (!name) return 'U'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
}

const getStatusBadgeClass = (status: string | null) => {
  if (!status) return 'bg-gray-100 text-gray-800'
  const classes = {
    active: 'bg-green-100 text-green-800',
    inactive: 'bg-gray-100 text-gray-800',
    banned: 'bg-red-100 text-red-800',
    pending: 'bg-yellow-100 text-yellow-800',
  }
  return classes[status as keyof typeof classes] || 'bg-gray-100 text-gray-800'
}

const getStatusText = (status: string | null) => {
  if (!status) return 'Unknown'
  const texts = {
    active: 'Active',
    inactive: 'Inactive',
    banned: 'Banned',
    pending: 'Pending',
  }
  return texts[status as keyof typeof texts] || status
}

const getPermissionBadgeClass = (permission: number | null) => {
  if (permission === null || permission === undefined) return 'bg-gray-100 text-gray-800'
  if (permission >= 99) return 'bg-purple-100 text-purple-800'
  if (permission >= 1) return 'bg-green-100 text-green-800'
  if (permission === 0) return 'bg-yellow-100 text-yellow-800'
  if (permission >= -1) return 'bg-yellow-100 text-yellow-800'
  if (permission >= -3) return 'bg-red-100 text-red-800'
  return 'bg-gray-100 text-gray-800'
}

const getPermissionText = (permission: number | null) => {
  if (permission === null || permission === undefined) return 'Unknown'
  if (permission >= 99) return 'Master User'
  if (permission >= 1) return 'Verified User'
  if (permission === 0) return 'Unverified User'
  if (permission === -1) return 'Restricted'
  if (permission === -2) return 'Suspended'
  if (permission === -3) return 'Banned'
  if (permission === -4) return 'Deleted'
  return `Level ${permission}`
}

const formatDate = (dateString: string | null) => {
  if (!dateString) return 'Never'
  return new Date(dateString).toLocaleDateString()
}

const studentStatusBadge = (s?: string) => {
  const map: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
  }
  return s ? (map[s] || 'bg-gray-100 text-gray-800') : 'bg-gray-100 text-gray-800'
}

// Lifecycle
onMounted(() => {
  loadUser()
})
</script>
