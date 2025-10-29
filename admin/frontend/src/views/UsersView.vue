<template>
  <div class="space-y-6">
    <!-- 頁面標題與操作 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
          User Management
        </h2>
        <p class="mt-1 text-sm text-gray-500">Manage user accounts, permissions, and status</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
    
      </div>
    </div>

    <!-- 篩選與搜尋 -->
    <div class="admin-card">
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-6">
        <!-- 搜尋 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
          <input
            v-model="filters.search"
            type="text"
            placeholder="Name or email..."
            class="admin-input"
            @input="debouncedSearch"
          />
        </div>
        <!-- User ID 搜尋 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">User ID</label>
          <input
            v-model="filters.user_id"
            type="number"
            placeholder="User ID"
            class="admin-input"
            @input="debouncedSearch"
          />
        </div>

        <!-- 狀態篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select v-model="filters.status" @change="() => loadUsers()" class="admin-input">
            <option value="">All Status</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="banned">Banned</option>
            <option value="pending_review">Pending Review</option>
          </select>
        </div>

        <!-- 權限篩選 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Permission Level</label>
          <select v-model="filters.permission" @change="() => loadUsers()" class="admin-input">
            <option value="">All Permissions</option>
            <option value="99">Super User (99)</option> //  管理員使用
            <option value="1">Verified User (1)</option> //  已認證用戶
            <option value="0">Unverified User (0)</option> //  新用戶未認證
            <option value="-1">Restricted (-1)</option> //  被管理員停權
            <option value="-2">Suspended (-2)</option> //  被管理員軟刪除
            <option value="-3">Banned (-3)</option> //  用戶自行停權
            <option value="-4">Deleted (-4)</option> //  用戶自行軟刪除
          </select>
        </div>

        <!-- 排序 -->
        <!-- <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Sort By</label>
          <select v-model="filters.sort_by" @change="() => loadUsers()" class="admin-input">
            <option value="id">ID</option>
            <option value="created_at">Registration Date</option>
            <option value="name">Name</option>
            <option value="email">Email</option>
            <option value="points">Points</option>
          </select>
        </div> -->
        <!-- 每頁數量 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Per Page</label>
          <select v-model="filters.per_page" @change="handlePerPageChange" class="admin-input w-full">
            <option value="10">10</option>
            <option value="15">15</option>
            <option value="25">25</option>
            <option value="50">50</option>
            <option value="100">100</option>
          </select>
        </div>
      </div>

      <!-- 排序方向與每頁數量 -->
      <!-- <div class="mt-4 flex items-center justify-start">
        <div class="flex items-center space-x-4">
          <label class="flex items-center">
            <input
              v-model="filters.sort_order"
              type="radio"
              value="desc"
              @change="() => loadUsers()"
              class="mr-2"
            />
            Newest First
          </label>
          <label class="flex items-center">
            <input
              v-model="filters.sort_order"
              type="radio"
              value="asc"
              @change="() => loadUsers()"
              class="mr-2"
            />
            Oldest First
          </label>
        </div>
      </div> -->
    </div>

    <!-- 批量操作面板 -->
    <div
      v-if="showBatchActions && selectedUsers.length > 0"
      class="admin-card bg-blue-50 border-blue-200"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <span class="text-sm font-medium text-blue-900">
            {{ selectedUsers.length }} users selected
          </span>
          <div class="flex space-x-2">
            <button @click="batchAction('activate')" class="admin-button-primary text-xs">
              Activate
            </button>
            <button @click="batchAction('deactivate')" class="admin-button-secondary text-xs">
              Deactivate
            </button>
            <button @click="batchAction('ban')" class="admin-button-secondary text-xs text-red-600">
              Ban
            </button>
          </div>
        </div>
        <button @click="clearSelection" class="text-blue-600 hover:text-blue-800 text-sm">
          Clear Selection
        </button>
      </div>
    </div>

    <!-- 統計卡片 -->
    <!-- <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.total_users || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.active_users || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Pending Review</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.pending_users || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <div class="admin-card">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636M5.636 18.364l12.728-12.728"
                />
              </svg>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Banned Users</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ stats.banned_users || 0 }}
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div> -->

    <!-- 用戶列表 -->
    <div class="admin-card">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Users</h3>
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
      <div v-else-if="users.length === 0" class="text-center py-8">
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
            d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
          />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No users found</h3>
        <p class="mt-1 text-sm text-gray-500">Try adjusting your search or filter criteria.</p>
      </div>

      <!-- Users Table -->
      <div v-else class="overflow-x-auto">
        <table class="admin-table">
          <thead>
  <tr>
    <!-- 全選保留 -->
    <!-- <th class="w-4">
      <input
        type="checkbox"
        :checked="allSelected"
        @change="toggleAllSelection"
        class="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
      />
    </th> -->

    <th>
      <button type="button" class="flex items-center gap-1 select-none" @click="setSort('name')">
        User
        <svg v-if="isSorted('name')" xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
          <path v-if="filters.sort_order==='asc'" d="M3 12l7-8 7 8H3z"/>
          <path v-else d="M3 8l7 8 7-8H3z"/>
        </svg>
      </button>
    </th>

    <th>
      <button type="button" class="flex items-center gap-1 select-none" @click="setSort('status')">
        Status
        <svg v-if="isSorted('status')" xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
          <path v-if="filters.sort_order==='asc'" d="M3 12l7-8 7 8H3z"/>
          <path v-else d="M3 8l7 8 7-8H3z"/>
        </svg>
      </button>
    </th>

    <th>
      <button type="button" class="flex items-center gap-1 select-none" @click="setSort('permission')">
        Permission
        <svg v-if="isSorted('permission')" xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
          <path v-if="filters.sort_order==='asc'" d="M3 12l7-8 7 8H3z"/>
          <path v-else d="M3 8l7 8 7-8H3z"/>
        </svg>
      </button>
    </th>

    <th>
      <button type="button" class="flex items-center gap-1 select-none" @click="setSort('points')">
        Points
        <svg v-if="isSorted('points')" xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
          <path v-if="filters.sort_order==='asc'" d="M3 12l7-8 7 8H3z"/>
          <path v-else d="M3 8l7 8 7-8H3z"/>
        </svg>
      </button>
    </th>

    <th>
      <button type="button" class="flex items-center gap-1 select-none" @click="setSort('updated_at')">
        Last Login
        <svg v-if="isSorted('updated_at')" xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
          <path v-if="filters.sort_order==='asc'" d="M3 12l7-8 7 8H3z"/>
          <path v-else d="M3 8l7 8 7-8H3z"/>
        </svg>
      </button>
    </th>

    <th>
      <button type="button" class="flex items-center gap-1 select-none" @click="setSort('created_at')">
        Registered
        <svg v-if="isSorted('created_at')" xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
          <path v-if="filters.sort_order==='asc'" d="M3 12l7-8 7 8H3z"/>
          <path v-else d="M3 8l7 8 7-8H3z"/>
        </svg>
      </button>
    </th>

    <th>Actions</th>
  </tr>
</thead>
          <tbody class="divide-y divide-gray-200">
            <tr
              v-for="user in users"
              :key="user.id"
              class="hover:bg-gray-50 cursor-pointer"
              :class="{ 'bg-blue-50': selectedUsers.includes(user.id) }"
              @click="viewUser(user.id)"
            >
              <!-- <td>
                <input
                  type="checkbox"
                  :value="user.id"
                  v-model="selectedUsers"
                  class="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
                  @click.stop
                />
              </td> -->
              <td>
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-10 w-10">
                    <div
                      class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center"
                    >
                      <span class="text-sm font-medium text-gray-700">
                        {{ getUserInitials(user.name) }}
                      </span>
                    </div>
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-gray-900">
                      {{ user.name }}
                    </div>
                    <div class="text-sm text-gray-500">
                      {{ user.email }}
                    </div>
                    <div class="text-xs text-gray-400">ID: {{ user.id }}</div>
                  </div>
                </div>
              </td>
              <td>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getStatusBadgeClass(user.status)"
                >
                  {{ getStatusText(user.status) }}
                </span>
              </td>
              <td>
                <span
                  class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
                  :class="getPermissionBadgeClass(user.permission)"
                >
                  {{ getPermissionText(user.permission) }}
                </span>
              </td>
              <td class="text-sm text-gray-900">
                {{ user.points || 0 }}
              </td>
              <td class="text-sm text-gray-500">
                {{ formatDate(user.last_login) }}
              </td>
              <td class="text-sm text-gray-500">
                {{ formatDate(user.created_at) }}
              </td>
              <td>
                <div class="flex items-center space-x-2">
                  <!-- 審核按鈕 - 僅當 permission = 0 (未驗證) 時顯示 -->
                  <button
                    v-if="user.permission === 0"
                    @click.stop="reviewUser(user)"
                    class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    Review
                  </button>
                  
                  <!-- 詳情按鈕 -->
                  <button
                    @click.stop="viewUser(user.id)"
                    class="admin-button-secondary text-sm"
                  >
                    Detail
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div
        v-if="pagination.total > 0"
        class="mt-6 flex items-center justify-between"
      >
        <div class="text-sm text-gray-700">
          Showing {{ (pagination.current_page - 1) * pagination.per_page + 1 }} to
          {{ Math.min(pagination.current_page * pagination.per_page, pagination.total) }} of
          {{ pagination.total }} results
          <span class="text-gray-500">({{ pagination.per_page }} per page)</span>
        </div>
        <div class="flex items-center space-x-4">
          <div class="flex items-center space-x-2">
            <button
              @click="changePage(1)"
              :disabled="pagination.current_page <= 1"
              class="admin-button-secondary text-sm px-2 py-1"
              :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }"
            >
              First
            </button>
            <button
              @click="changePage(pagination.current_page - 1)"
              :disabled="pagination.current_page <= 1"
              class="admin-button-secondary text-sm px-2 py-1"
              :class="{ 'opacity-50 cursor-not-allowed': pagination.current_page <= 1 }"
            >
              Previous
            </button>
            <span class="text-sm text-gray-700 px-2">
              Page {{ pagination.current_page }} of {{ pagination.last_page }}
            </span>
            <button
              @click="changePage(pagination.current_page + 1)"
              :disabled="pagination.current_page >= pagination.last_page"
              class="admin-button-secondary text-sm px-2 py-1"
              :class="{
                'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page,
              }"
            >
              Next
            </button>
            <button
              @click="changePage(pagination.last_page)"
              :disabled="pagination.current_page >= pagination.last_page"
              class="admin-button-secondary text-sm px-2 py-1"
              :class="{
                'opacity-50 cursor-not-allowed': pagination.current_page >= pagination.last_page,
              }"
            >
              Last
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Edit User Modal -->
    <UserEditModal
      v-if="showEditModal"
      :user="selectedUser"
      @close="showEditModal = false"
      @saved="handleUserSaved"
    />

    <!-- User Review Modal -->
    <UserReviewModal
      v-if="showReviewModal"
      :user="selectedUser"
      @close="showReviewModal = false"
      @reviewed="handleUserReviewed"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { userApi } from '@/services/api'
import UserEditModal from '@/components/UserEditModal.vue'
import UserReviewModal from '@/components/UserReviewModal.vue'

const router = useRouter()
const authStore = useAuthStore()

// State
const isLoading = ref(false)
const users = ref<any[]>([])
const selectedUsers = ref<number[]>([])
const showBatchActions = ref(false)
const showEditModal = ref(false)
const showReviewModal = ref(false)
const selectedUser = ref<any>(null)

const stats = ref({
  total_users: 0,
  active_users: 0,
  pending_users: 0,
  banned_users: 0,
})

const pagination = ref({
  current_page: 1,
  per_page: 15,
  total: 0,
  last_page: 1,
})

const filters = reactive({
  search: '',
  user_id: '',
  status: '',
  permission: '',
  sort_by: 'created_at',
  sort_order: 'desc' as 'asc' | 'desc',
  per_page: 15,
})

// Computed
const allSelected = computed(() => {
  return users.value.length > 0 && selectedUsers.value.length === users.value.length
})

// Methods
const loadUsers = async (page = 1) => {
  try {
    isLoading.value = true
    const targetPage = Number(page) || 1
    const perPage = Number(filters.per_page) || 15

    const params = {
      page: targetPage,
      per_page: perPage,
      search: filters.search || ''  ,
      user_id: filters.user_id ? parseInt(filters.user_id) : undefined,
      status: filters.status || '',
      permission: filters.permission ? parseInt(filters.permission) : undefined,
      sort_by: filters.sort_by,
      sort_order: filters.sort_order,
    }

    const response = await userApi.list(params)

    if (response.data.success && response.data.data) {
      users.value = response.data.data.items || []
      const pg = response.data.data.pagination
      if (pg) {
        pagination.value = {
          current_page: Number(pg.current_page) || targetPage,
          per_page: Number(pg.per_page) || perPage,
          total: Number(pg.total) || 0,
          last_page: Number(pg.last_page) || 1,
        }
      }
      stats.value = response.data.data.stats || stats.value
    }
  } catch (error) {
    console.error('Failed to load users:', error)
  } finally {
    isLoading.value = false
  }
}

const refreshData = () => {
  loadUsers(pagination.value.current_page)
}

const changePage = (page: number) => {
  const nextPage = Number(page)
  const last = Number(pagination.value.last_page || 1)
  if (nextPage < 1 || nextPage > last) return
  // 先更新目前頁，讓 UI 立刻反映
  pagination.value.current_page = nextPage
  loadUsers(nextPage)
}

const handlePerPageChange = () => {
  pagination.value.current_page = 1
  loadUsers(1)
}

const toggleAllSelection = () => {
  if (allSelected.value) {
    selectedUsers.value = []
  } else {
    selectedUsers.value = users.value.map((user) => user.id)
  }
}

const clearSelection = () => {
  selectedUsers.value = []
  showBatchActions.value = false
}

const batchAction = async (action: string) => {
  if (selectedUsers.value.length === 0) return

  const reason = prompt(`Please provide a reason for ${action}:`)
  if (!reason) return

  try {
    await userApi.batchAction(action, selectedUsers.value, reason)
    clearSelection()
    refreshData()
  } catch (error) {
    console.error(`Failed to ${action} users:`, error)
  }
}

const viewUser = (userId: number) => {
  router.push(`/users/${userId}`)
}

const editUser = (user: any) => {
  selectedUser.value = user
  showEditModal.value = true
}

const handleUserSaved = () => {
  showEditModal.value = false
  refreshData()
}

const reviewUser = (user: any) => {
  selectedUser.value = user
  showReviewModal.value = true
}

const handleUserReviewed = () => {
  showReviewModal.value = false
  refreshData()
}

// Debounced search
let searchTimeout: number
const debouncedSearch = () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    loadUsers(1)
  }, 500)
}

// Sorting helpers for clickable headers
const isSorted = (field: string) => filters.sort_by === field
const setSort = (field: string) => {
  if (filters.sort_by === field) {
    filters.sort_order = filters.sort_order === 'asc' ? 'desc' : 'asc'
  } else {
    filters.sort_by = field
    // 切換欄位時預設改為 desc（你也可以用 asc）
    filters.sort_order = 'desc'
  }
  loadUsers(1)
}

// Utility functions
const getUserInitials = (name: string | null | undefined) => {
  if (!name) return 'U'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
}

const getStatusBadgeClass = (status: string) => {
  const classes = {
    active: 'bg-green-100 text-green-800',
    inactive: 'bg-gray-100 text-gray-800',
    banned: 'bg-red-100 text-red-800',
    pending: 'bg-yellow-100 text-yellow-800',
  }
  return classes[status as keyof typeof classes] || 'bg-gray-100 text-gray-800'
}

const getStatusText = (status: string) => {
  const texts = {
    active: 'Active',
    inactive: 'Inactive',
    banned: 'Banned',
    pending: 'Pending',
  }
  return texts[status as keyof typeof texts] || status
}

const getPermissionBadgeClass = (permission: number) => {
  if (permission >= 99) return 'bg-purple-100 text-purple-800'
  if (permission >= 1) return 'bg-green-100 text-green-800'
  if (permission === 0) return 'bg-yellow-100 text-yellow-800'
  if (permission >= -1) return 'bg-yellow-100 text-yellow-800'
  if (permission >= -3) return 'bg-red-100 text-red-800'
  return 'bg-gray-100 text-gray-800'
}

const getPermissionText = (permission: number) => {
  if (permission >= 99) return 'Master User'
  if (permission >= 1) return 'Verified User'
  if (permission === 0) return 'Unverified User'
  if (permission == 0) return 'Unverified User'
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

// Lifecycle
onMounted(() => {
  loadUsers()
})
</script>
