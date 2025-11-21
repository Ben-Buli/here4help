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
                      d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
                  </svg>
                </router-link>
              </li>
              <li>
                <div class="flex items-center">
                  <svg class="flex-shrink-0 h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd"
                      d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                      clip-rule="evenodd" />
                  </svg>
                  <router-link to="/users" class="ml-4 text-sm font-medium text-gray-500 hover:text-gray-700">
                    Users
                  </router-link>
                </div>
              </li>
              <li>
                <div class="flex items-center">
                  <svg class="flex-shrink-0 h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd"
                      d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                      clip-rule="evenodd" />
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
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(user.status)">
                  {{ getStatusText(user.status) }}
                </span>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getPermissionBadgeClass(user.permission)">
                  {{ getPermissionText(user.permission) }}
                </span>
              </div>
            </div>
          </div>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
          <button v-if="user.student_verification && user.student_verification.verification_status === 'pending'"
            @click="openStudentReview" class="admin-button-primary flex items-center gap-2" :disabled="isLoading">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M3.75 7.5A2.25 2.25 0 016 5.25h12a2.25 2.25 0 012.25 2.25v9A2.25 2.25 0 0118 18.75H6A2.25 2.25 0 013.75 16.5v-9z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7.5 9.75h9M7.5 12.75h4.5" />
            </svg>
            Review
          </button>
          <button @click="loadTermsHistory" class="admin-button-secondary flex items-center gap-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6l4 2" />
              <circle cx="12" cy="12" r="9" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            Terms
          </button>
       
          <button
            v-if="canGenerateUserResetLink"
            class="admin-button-secondary flex items-center gap-2"
            @click="requestPasswordResetLink"
            :disabled="isGeneratingResetLink || !user.email"
            title="Reset Password"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M12 11c1.657 0 3-1.343 3-3S13.657 5 12 5 9 6.343 9 8s1.343 3 3 3z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M5 21v-2a4 4 0 014-4h6a4 4 0 014 4v2" />
            </svg>
            <span>{{ isGeneratingResetLink ? 'Preparing…' : 'Reset PWD' }}</span>
          </button>
          <button @click="refreshData" class="admin-button-secondary">
            <!-- <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg> -->
            Refresh
          </button>
        </div>
      </div>
      <p v-if="canGenerateUserResetLink && resetLinkActionError" class="mt-2 text-sm text-red-600">{{ resetLinkActionError }}</p>

      <!-- User Information Cards -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2 mt-8">
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
            <div>
              <dt class="text-sm font-medium text-gray-500">Invite Code</dt>
              <dd class="text-sm text-gray-900">{{ user.referral_code || 'Not provided' }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Referral Code Used</dt>
              <dd class="text-sm text-gray-900">{{ user.intro_referral_code || 'Not provided' }}</dd>
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
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(user.status)">
                  {{ getStatusText(user.status) }}
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Permission Level</dt>
              <dd>
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getPermissionBadgeClass(user.permission)">
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
                  :class="verificationStatusDisplay(user.student_verification).badgeClass">
                  {{ verificationStatusDisplay(user.student_verification).label }}
                </span>
              </dd>
            </div>
            <div v-if="user.student_verification.submission_count">
              <dt class="text-gray-500">Submission Attempt</dt>
              <dd class="text-gray-900">{{ submissionAttemptLabel(user.student_verification) }}</dd>
            </div>
            <div v-if="user.student_verification.previous_status">
              <dt class="text-gray-500">Previous Status</dt>
              <dd class="text-gray-900">{{ formatStatusText(user.student_verification.previous_status) }}</dd>
            </div>
            <div v-if="user.student_verification.verification_notes">
              <dt class="text-gray-500">Notes</dt>
              <dd class="text-gray-900">{{ user.student_verification.verification_notes }}</dd>
            </div>
          </dl>
          <div v-if="user.student_verification && user.student_verification.student_id_image_path">
            <dt class="text-gray-500">Student ID Image</dt>
            <dd>
              <div class="relative">
                <div v-if="studentImageLoadError"
                  class="flex h-32 w-24 items-center justify-center rounded border border-dashed border-gray-300 bg-gray-50 px-3 text-center text-xs text-gray-500"
                  aria-live="polite">
                  Image unavailable
                </div>
                <img v-else :src="getImageUrl(user.student_verification.student_id_image_path)" alt="Student ID"
                  class="h-32 w-24 rounded border object-cover cursor-pointer"
                  @click="openImage(user.student_verification.student_id_image_path)"
                  @error="handleStudentImageError" />
              </div>
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
      <div class="admin-card mt-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Activities</h3>
        <div v-if="recentActivities.length === 0" class="text-center py-4 text-gray-500">
          No recent activities
        </div>
        <div v-else class="space-y-3">
          <div v-for="activity in recentActivities" :key="activity.id"
            class="flex items-center justify-between py-2 border-b border-gray-200 last:border-b-0">
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

      <!-- Admin Operation Logs -->
      <div class="admin-card mt-8">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Operation History</h3>
          <button @click="() => loadOperationLogs(1)" class="text-sm text-primary-600 hover:text-primary-800"
            :disabled="isLoadingLogs">
            {{ isLoadingLogs ? 'Loading...' : 'Refresh' }}
          </button>
        </div>
        <div v-if="isLoadingLogs" class="flex justify-center py-4">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600"></div>
        </div>
        <div v-else-if="operationLogs.length === 0" class="text-center py-4 text-gray-500">
          No operation logs found
        </div>
        <div v-else class="space-y-3">
          <div v-for="log in operationLogs" :key="log.id"
            class="flex items-start justify-between py-3 border-b border-gray-200 last:border-b-0">
            <div class="flex-1">
              <div class="flex items-center space-x-2 mb-1">
                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getActionBadgeClass(log.action)">
                  {{ getActionText(log.action) }}
                </span>
                <span class="text-xs text-gray-500">
                  by {{ log.actor_type === 'admin' ? (log.admin_full_name || log.admin_username || 'Admin') : 'System'
                  }}
                </span>
              </div>
              <div v-if="log.field" class="text-sm text-gray-700 mt-1">
                <span class="font-medium">{{ log.field }}:</span>
                <span v-if="log.old_value" class="text-red-600 line-through mr-2">{{ log.old_value }}</span>
                <span v-if="log.new_value" class="text-green-600">{{ log.new_value }}</span>
              </div>
              <div v-if="log.reason" class="text-sm text-gray-500 mt-1">
                Reason: {{ log.reason }}
              </div>
            </div>
            <div class="text-sm text-gray-400 ml-4">
              {{ formatDateTime(log.created_at) }}
            </div>
          </div>
        </div>
        <div v-if="operationLogsPagination.total > operationLogsPagination.per_page" class="mt-4 flex justify-center">
          <button @click="loadMoreLogs" class="admin-button-secondary text-sm" :disabled="isLoadingLogs">
            Load More
          </button>
        </div>
      </div>

      <UserReviewModal v-if="showReviewModal && user" :user="user" @close="showReviewModal = false"
        @reviewed="handleStudentReviewed" />

      <div v-if="showImageModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75"
        @click="closeImageModal">
        <div class="relative max-h-screen max-w-3xl p-4" @click.stop>
          <button @click="closeImageModal" class="absolute top-4 right-4 text-white hover:text-gray-300"
            aria-label="Close image preview">
            <svg class="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
          <img v-if="!modalImageError" :src="selectedImagePath" alt="Student ID preview"
            class="max-h-screen max-w-full rounded object-contain" @error="handleModalImageError" />
          <div v-else class="rounded bg-white px-6 py-4 text-center text-gray-700 shadow-lg">
            Unable to load the student ID image.
          </div>
        </div>
      </div>

      <!-- Terms Acceptance History -->
      <transition name="fade">
        <div v-if="showTermsModal" class="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-sm px-4"
          @click="showTermsModal = false">
          <div
            class="relative bg-white rounded-2xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col border-1 border-gray-200"
            @click.stop>
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <div>
                <h3 class="text-lg font-semibold text-gray-900">Terms Acceptance History</h3>
                <p class="text-sm text-gray-500">Track which versions this user agreed to.</p>
              </div>
              <button class="text-gray-400 hover:text-gray-600" @click="showTermsModal = false">✕</button>
            </div>
            <div class="flex-1 overflow-y-auto">
              <div v-if="isLoadingTermsHistory" class="p-6 text-center text-gray-500">
                Loading terms history...
              </div>
              <div v-else class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Version
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Published</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Accepted</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <tr v-if="termsHistory.length === 0">
                      <td colspan="4" class="px-6 py-6 text-center text-gray-500">No applicable versions found.</td>
                    </tr>
                    <tr v-for="term in termsHistory" :key="term.id">
                      <td class="px-6 py-4 text-sm font-medium text-gray-900">v{{ term.version }}</td>
                      <td class="px-6 py-4 text-sm text-gray-700">{{ term.title }}</td>
                      <td class="px-6 py-4 text-sm text-gray-500">{{ formatDate(term.created_at) }}</td>
                      <td class="px-6 py-4 text-sm">
                        <span v-if="term.accepted_at" class="text-green-600 font-medium">
                          {{ formatDate(term.accepted_at) }}
                        </span>
                        <span v-else class="text-red-500 font-medium">Pending</span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div class="px-6 py-4 border-t border-gray-100 text-sm text-gray-500">
              User registered at {{ formatDate(termsHistoryMeta.user_registered_at) }}
            </div>
          </div>
        </div>
      </transition>

      <transition name="fade">
        <div v-if="showResetModal" class="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-sm px-2 md:px-4"
          @click="closeResetModal">
          <div class="relative bg-white rounded-2xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-hidden flex flex-col"
            @click.stop>
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <div>
                <h3 class="text-lg font-semibold text-gray-900">Manual Password Reset</h3>
                <p class="text-sm text-gray-500">Share this link securely with the user.</p>
              </div>
              <button class="text-gray-400 hover:text-gray-600" @click="closeResetModal" aria-label="Close reset modal">
                ✕
              </button>
            </div>
            <div class="flex-1 overflow-y-auto p-4 sm:p-6 space-y-4" v-if="resetLinkInfo">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                <div>
                  <p class="text-gray-500">User Email</p>
                  <a :href="`mailto:${resetLinkInfo.email}`" class="text-primary-600 break-all">
                    {{ resetLinkInfo.email }}
                  </a>
                </div>
                <div>
                  <p class="text-gray-500">Created By</p>
                  <p class="text-gray-900">
                    <template v-if="resetLinkInfo.created_by_name">
                      {{ resetLinkInfo.created_by_name }} (#{{ resetLinkInfo.created_by }})
                    </template>
                    <template v-else>
                      User-Initiated
                    </template>
                  </p>
                </div>
                <div>
                  <p class="text-gray-500">Expires In</p>
                  <p class="text-gray-900">{{ resetCountdownText || 'Expired' }}</p>
                  <p class="text-xs text-gray-500">
                    {{ formatDateTime(resetLinkInfo.expires_at) }}
                  </p>
                </div>
              </div>

          

              <div v-if="resetLinkInfo.was_existing_link"
                class="text-xs text-amber-700 bg-amber-50 border border-amber-100 rounded-lg p-3">
                An active reset link already existed for this user. Share the same link below.
              </div>

              
              <p class="text-sm font-semibold text-gray-900">Reset Notification Email Template:</p>
              <div class="relative bg-gray-50 border border-gray-200 rounded-2xl p-4 overflow-x-auto">
                <button class="absolute top-3 right-3 flex items-center gap-1 text-gray-500 hover:text-gray-900"
                  @click="copyResetEmailTemplate" :title="resetCopyTooltip">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M8 16h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v9a2 2 0 002 2z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M16 8h2a2 2 0 012 2v7a2 2 0 01-2 2h-8a2 2 0 01-2-2v-1" />
                  </svg>
                  <span class="text-xs">{{ resetCopyTooltip }}</span>
                </button>
                <pre class="text-sm font-mono whitespace-pre-wrap break-words text-gray-800 pr-10">{{ resetEmailTemplate }}</pre>
              </div>

              <div class="space-y-2">
                <p class="text-sm text-gray-600">Reset link</p>
                <a :href="resetLinkInfo.reset_link" target="_blank" rel="noopener"
                  class="block text-sm text-primary-600 break-all">
                  {{ resetLinkInfo.reset_link }}
                </a>
              </div>

              <p class="text-xs text-gray-500">
                Reminder: ask the user to open the link within 1 hour and keep it private.
              </p>

              <p v-if="resetModalError" class="text-sm text-red-600">{{ resetModalError }}</p>
            </div>
          </div>
        </div>
      </transition>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { userApi, userActivityApi, type PasswordResetLinkResponse } from '@/services/api'
import { getImageUrl } from '@/config/api'
import UserReviewModal from '@/components/UserReviewModal.vue'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

// State
const isLoading = ref(false)
const error = ref('')
type StudentVerification = {
  id?: number
  school_name?: string
  student_name?: string
  student_id?: string
  student_id_image_path?: string
  student_id_image_url?: string | null
  verification_status?: string
  verification_notes?: string | null
  created_at?: string
  updated_at?: string
  admin_id?: number | null
  submission_count?: number
  previous_status?: string | null
  requires_re_review?: boolean
}

type UserWithStudent = any & { student_verification?: StudentVerification | null }

const user = ref<UserWithStudent | null>(null)
const stats = ref<any>({})
const recentActivities = ref<any[]>([])
const showImageModal = ref(false)
const selectedImagePath = ref('')
const showReviewModal = ref(false)
const studentImageLoadError = ref(false)
const modalImageError = ref(false)
const operationLogs = ref<any[]>([])
const isLoadingLogs = ref(false)
const operationLogsPagination = ref({
  current_page: 1,
  per_page: 10,
  total: 0,
  last_page: 1,
})
const showTermsModal = ref(false)
const isLoadingTermsHistory = ref(false)
const termsHistory = ref<any[]>([])
const termsHistoryMeta = ref<{ user_registered_at: string | null }>({ user_registered_at: null })

type ResetLinkInfo = PasswordResetLinkResponse
const showResetModal = ref(false)
const isGeneratingResetLink = ref(false)
const resetLinkActionError = ref('')
const resetModalError = ref('')
const resetLinkInfo = ref<ResetLinkInfo | null>(null)
const resetCopyTooltip = ref('Copy')
const resetCountdownText = ref('')
let resetCountdownTimer: number | null = null
let resetCopyTooltipTimer: number | null = null
const canGenerateUserResetLink = computed(() => authStore.hasPermission('users.edit'))

const resetEmailTemplate = computed(() => {
  const name = resetLinkInfo.value?.user_name || user.value?.name || 'there'
  const link = resetLinkInfo.value?.reset_link || ''
  return (
    `Hello ${name},\n\n` +
    'We received a request to reset the password for your Here4Help account.\n\n' +
    "If you did not make this request, you can safely ignore this email and no changes will be made to your account.\n\n" +
    'Please use the link below to reset your password (valid for 1 hour):\n' +
    `${link}\n\n` +
    'Best regards,\n' +
    'The Here4Help Team'
  )
})

const getFriendlyResetError = (err: any): string => {
  const raw = err?.response?.data?.message || err?.message || ''
  const normalized = raw.toLowerCase()

  if (normalized.includes("unknown column 'created_by_admin_id'")) {
    return 'The backend database is missing the latest password-reset fields. Please run the new migrations before issuing links.'
  }

  if (normalized.includes('sqlstate')) {
    return 'The backend reported a database error while generating the link. Please check the server logs.'
  }

  if (err?.response?.status === 403) {
    return raw || 'You do not have permission to generate reset links for this user.'
  }

  return raw || 'Unable to generate reset link. Please try again later.'
}

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
      studentImageLoadError.value = false
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
  if (!path || studentImageLoadError.value) return
  modalImageError.value = false
  selectedImagePath.value = getImageUrl(path)
  showImageModal.value = true
}

const closeImageModal = () => {
  showImageModal.value = false
  selectedImagePath.value = ''
  modalImageError.value = false
}

const handleStudentImageError = () => {
  studentImageLoadError.value = true
}

const handleModalImageError = () => {
  modalImageError.value = true
}

const loadTermsHistory = async () => {
  if (!user.value?.id) return
  try {
    isLoadingTermsHistory.value = true
    const response = await userApi.termsHistory(user.value.id)
    const payload = response.data.data
    termsHistory.value = payload?.items ?? []
    termsHistoryMeta.value.user_registered_at = payload?.user_registered_at ?? null
    showTermsModal.value = true
  } catch (error) {
    console.error('Failed to load terms history', error)
    alert('Failed to load terms history')
  } finally {
    isLoadingTermsHistory.value = false
  }
}

const requestPasswordResetLink = async () => {
  if (!canGenerateUserResetLink.value || !user.value?.id) return
  try {
    isGeneratingResetLink.value = true
    resetLinkActionError.value = ''

    const response = await userApi.passwordResetLink(user.value.id)
    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || 'Unable to generate reset link')
    }

    resetLinkInfo.value = response.data.data
    resetModalError.value = ''
    resetCopyTooltip.value = 'Copy'
    showResetModal.value = true
    startResetCountdown()
  } catch (err: any) {
    console.error('Failed to create password reset link', err)
    const message = getFriendlyResetError(err)
    resetLinkActionError.value = message
    if (showResetModal.value) {
      resetModalError.value = message
    }
  } finally {
    isGeneratingResetLink.value = false
  }
}

const closeResetModal = () => {
  showResetModal.value = false
  resetModalError.value = ''
}

const updateResetCountdown = () => {
  if (!resetLinkInfo.value) {
    resetCountdownText.value = ''
    return
  }
  const expiresAt = new Date(resetLinkInfo.value.expires_at)
  const diff = expiresAt.getTime() - Date.now()
  if (diff <= 0) {
    resetCountdownText.value = 'Expired'
    stopResetCountdown()
    return
  }
  const totalSeconds = Math.floor(diff / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  resetCountdownText.value = `${minutes}m ${seconds.toString().padStart(2, '0')}s`
}

const startResetCountdown = () => {
  stopResetCountdown()
  updateResetCountdown()
  resetCountdownTimer = window.setInterval(updateResetCountdown, 1000)
}

const stopResetCountdown = () => {
  if (resetCountdownTimer) {
    clearInterval(resetCountdownTimer)
    resetCountdownTimer = null
  }
}

const copyResetEmailTemplate = async () => {
  if (!resetLinkInfo.value) return
  try {
    await navigator.clipboard.writeText(resetEmailTemplate.value)
    resetCopyTooltip.value = 'Copied!'
    if (resetCopyTooltipTimer) {
      clearTimeout(resetCopyTooltipTimer)
    }
    resetCopyTooltipTimer = window.setTimeout(() => {
      resetCopyTooltip.value = 'Copy'
      resetCopyTooltipTimer = null
    }, 2000)
    resetModalError.value = ''
  } catch (err: any) {
    resetModalError.value = 'Unable to copy text automatically. Please copy it manually.'
  }
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
  if (permission === -1) return 'bg-yellow-100 text-yellow-800'
  if (permission === -2) return 'bg-orange-100 text-orange-800'
  if (permission === -3) return 'bg-red-100 text-red-800'
  if (permission === -4) return 'bg-gray-100 text-gray-500'
  return 'bg-gray-100 text-gray-800'
}

const getPermissionText = (permission: number | null) => {
  if (permission === null || permission === undefined) return 'Unknown'
  if (permission >= 99) return 'Master User'
  if (permission >= 1) return 'Verified User'
  if (permission === 0) return 'New User in Verification'
  if (permission === -1) return 'Admin Suspended'
  if (permission === -2) return 'Admin Soft Deleted'
  if (permission === -3) return 'Self Suspended'
  if (permission === -4) return 'Self Soft Deleted'
  return `Level ${permission}`
}

const formatDate = (dateString: string | null) => {
  if (!dateString) return 'Never'
  return new Date(dateString).toLocaleDateString()
}

const formatDateTime = (dateString: string | null) => {
  if (!dateString) return 'Never'
  const date = new Date(dateString)
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

const getActionBadgeClass = (action: string) => {
  const actionMap: Record<string, string> = {
    permission_change: 'bg-purple-100 text-purple-800',
    status_change: 'bg-blue-100 text-blue-800',
    user_verification_review: 'bg-green-100 text-green-800',
    batch_action: 'bg-orange-100 text-orange-800',
  }
  return actionMap[action] || 'bg-gray-100 text-gray-800'
}

const getActionText = (action: string) => {
  const actionMap: Record<string, string> = {
    permission_change: 'Permission Changed',
    status_change: 'Status Changed',
    user_verification_review: 'Verification Reviewed',
    batch_action: 'Batch Action',
  }
  return actionMap[action] || action.replace(/_/g, ' ').replace(/\b\w/g, (l) => l.toUpperCase())
}

const loadOperationLogs = async (page = 1) => {
  if (!user.value?.id) return

  try {
    isLoadingLogs.value = true
    // 後端使用 like 查詢，所以我們只傳遞一個主要的 action 類型，或者不傳遞讓後端返回所有
    const response = await userActivityApi.list({
      page,
      per_page: operationLogsPagination.value.per_page,
      user_id: user.value.id,
      actor_type: 'admin', // 只顯示管理員操作
    })

    if (response.data.success && response.data.data) {
      // 過濾出權限和狀態相關的操作
      const filteredItems = (response.data.data.items || []).filter((item: any) =>
        item.action === 'permission_change' ||
        item.action === 'status_change' ||
        item.action === 'user_verification_review'
      )

      if (page === 1) {
        operationLogs.value = filteredItems
      } else {
        operationLogs.value.push(...filteredItems)
      }

      const pg = response.data.data.pagination
      if (pg) {
        operationLogsPagination.value = {
          current_page: Number(pg.current_page) || page,
          per_page: Number(pg.per_page) || operationLogsPagination.value.per_page,
          total: Number(pg.total) || 0,
          last_page: Number(pg.last_page) || 1,
        }
      }
    }
  } catch (err: any) {
    console.error('Failed to load operation logs:', err)
  } finally {
    isLoadingLogs.value = false
  }
}

const loadMoreLogs = () => {
  if (operationLogsPagination.value.current_page < operationLogsPagination.value.last_page) {
    loadOperationLogs(operationLogsPagination.value.current_page + 1)
  }
}

type StatusDisplay = { label: string; badgeClass: string }

const verificationStatusDisplay = (verification?: StudentVerification | null): StatusDisplay => {
  if (!verification) {
    return { label: 'No data', badgeClass: 'bg-gray-100 text-gray-800' }
  }

  const status = verification.verification_status || 'pending'
  const requiresReReview = verification.requires_re_review === true

  if (status === 'pending' && requiresReReview) {
    return { label: 'Re-review', badgeClass: 'bg-cyan-100 text-cyan-800' }
  }

  const labelMap: Record<string, string> = {
    pending: 'Pending',
    approved: 'Approved',
    rejected: 'Rejected',
  }

  const badgeMap: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
  }

  return {
    label: labelMap[status] || status.replace('_', ' '),
    badgeClass: badgeMap[status] || 'bg-gray-100 text-gray-800',
  }
}

const submissionAttemptLabel = (verification?: StudentVerification | null) => {
  if (!verification?.submission_count) return 'Unknown'
  if (verification.submission_count === 1) return 'First submission'
  return `Submission #${verification.submission_count}`
}

const formatStatusText = (status?: string | null) => {
  if (!status) return 'Unknown'
  return status
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

// Lifecycle
onMounted(() => {
  loadUser()
})

watch(
  () => user.value?.id,
  (userId) => {
    if (userId) {
      loadOperationLogs(1)
    }
  }
)

watch(
  () => user.value?.student_verification?.student_id_image_path,
  () => {
    studentImageLoadError.value = false
  }
)

watch(showResetModal, (isOpen) => {
  if (isOpen && resetLinkInfo.value) {
    startResetCountdown()
  } else {
    stopResetCountdown()
    resetCopyTooltip.value = 'Copy'
    resetModalError.value = ''
  }
})

watch(
  () => resetLinkInfo.value?.expires_at,
  () => {
    if (showResetModal.value && resetLinkInfo.value) {
      startResetCountdown()
    }
  }
)

onBeforeUnmount(() => {
  stopResetCountdown()
  if (resetCopyTooltipTimer) {
    clearTimeout(resetCopyTooltipTimer)
    resetCopyTooltipTimer = null
  }
})
</script>
