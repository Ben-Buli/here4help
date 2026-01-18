<template>
  <div class="space-y-6">
    <!-- 頁面標題 -->
    <div class="md:flex md:items-center md:justify-between">
      <div class="flex-1 min-w-0">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl">User Logs</h2>
        <p class="mt-1 text-sm text-gray-500">Monitor user activities and point transactions</p>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4 space-x-3">
        <button @click="refreshData" class="admin-button-secondary" :disabled="activityLoading || transactionLoading">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="border-b border-gray-200">
      <nav class="-mb-px flex space-x-4">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          @click="activeTab = tab.id as 'activities' | 'transactions'"
          class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"
          :class="activeTab === tab.id
            ? 'border-cyan-500 text-cyan-600'
            : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'"
        >
          {{ tab.name }}
          <span
            v-if="tab.count !== undefined"
            class="ml-2 py-0.5 px-2 rounded-full text-xs"
            :class="activeTab === tab.id ? 'bg-cyan-100 text-cyan-600' : 'bg-gray-100 text-gray-600'"
          >
            {{ tab.count }}
          </span>
        </button>
      </nav>
    </div>

    <!-- Activities Tab -->
    <div v-show="activeTab === 'activities'">
      <!-- 篩選器 -->
      <div class="admin-card mb-6">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              v-model="activityFilters.search"
              type="text"
              placeholder="User ID, name, email..."
              class="admin-input"
              @input="debouncedActivitySearch"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Activity Type</label>
            <input
              v-model="activityFilters.action"
              type="text"
              placeholder="Activity type"
              class="admin-input"
              @input="debouncedActivitySearch"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Actor Type</label>
            <select v-model="activityFilters.actor_type" @change="loadActivities" class="admin-input">
              <option value="">All</option>
              <option value="user">User</option>
              <option value="admin">Admin</option>
              <option value="system">System</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
            <input v-model="activityFilters.date_from" type="date" class="admin-input" @change="loadActivities" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
            <input v-model="activityFilters.date_to" type="date" class="admin-input" @change="loadActivities" />
          </div>
        </div>
      </div>

      <!-- 統計卡片 -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-6">
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Activities</dt>
                <dd class="text-lg font-medium text-gray-900">{{ activityStats?.total_activities || 0 }}</dd>
              </dl>
            </div>
          </div>
        </div>
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
                <dd class="text-lg font-medium text-gray-900">{{ activityStats?.unique_users || 0 }}</dd>
              </dl>
            </div>
          </div>
        </div>
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Activity Types</dt>
                <dd class="text-lg font-medium text-gray-900">{{ activityStats?.unique_actions || 0 }}</dd>
              </dl>
            </div>
          </div>
        </div>
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Today's Activities</dt>
                <dd class="text-lg font-medium text-gray-900">{{ activityStats?.today_count || 0 }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- 活動列表 -->
      <div class="admin-card">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Activity Logs</h3>
          <div class="flex items-center space-x-4">
            <div class="text-sm text-gray-500">
              Showing {{ activityPaginationInfo.from }} to {{ activityPaginationInfo.to }} of {{ activityPaginationInfo.total }} results
            </div>
            <select v-model="activityPagination.per_page" @change="handleActivityPerPageChange" class="admin-input text-sm py-1">
              <option value="15">15</option>
              <option value="25">25</option>
              <option value="50">50</option>
              <option value="100">100</option>
            </select>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">User</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Activity Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actor</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Changed Field</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reason</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">IP Address</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-if="activityLoading">
                <td colspan="8" class="px-6 py-8 text-center text-gray-500">
                  <div class="flex justify-center items-center">
                    <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-cyan-600 mr-2"></div>
                    Loading...
                  </div>
                </td>
              </tr>
              <tr v-else-if="activities.length === 0">
                <td colspan="8" class="px-6 py-8 text-center text-gray-500">No activities found.</td>
              </tr>
              <tr v-for="activity in activities" :key="activity.id" class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{{ activity.id }}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div class="h-8 w-8 rounded-full bg-cyan-100 flex items-center justify-center">
                      <span class="text-sm font-medium text-cyan-600">{{ getUserInitials(activity.user_name) }}</span>
                    </div>
                    <div class="ml-3">
                      <div class="text-sm font-medium text-gray-900">{{ activity.user_name || 'Unknown' }}</div>
                      <div class="text-xs text-gray-500">{{ activity.user_email }}</div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="getActionBadgeClass(activity.action)">
                    {{ getActionText(activity.action) }}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">
                    {{ activity.actor_type === 'admin' ? (activity.admin_full_name || 'Admin') : (activity.actor_type === 'user' ? (activity.user_name || 'User') : 'System') }}
                  </div>
                  <div class="text-xs text-gray-500">{{ activity.actor_type }}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <div v-if="activity.field">
                    <div class="font-medium">{{ activity.field }}</div>
                    <div v-if="activity.old_value || activity.new_value" class="text-xs text-gray-500">
                      <span v-if="activity.old_value">Old: {{ activity.old_value }}</span>
                      <span v-if="activity.old_value && activity.new_value"> → </span>
                      <span v-if="activity.new_value">New: {{ activity.new_value }}</span>
                    </div>
                  </div>
                  <span v-else class="text-gray-400">-</span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{{ activity.reason || '-' }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ activity.ip || '-' }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ formatDate(activity.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <!-- 分頁 -->
        <div v-if="activityPagination.total > activityPagination.per_page" class="mt-6 flex items-center justify-between">
          <div class="text-sm text-gray-700">
            Page {{ activityPagination.current_page }} of {{ activityPagination.last_page }}
          </div>
          <div class="flex space-x-2">
            <button @click="goToActivityPage(activityPagination.current_page - 1)" :disabled="activityPagination.current_page <= 1" class="admin-button-secondary text-sm" :class="{ 'opacity-50 cursor-not-allowed': activityPagination.current_page <= 1 }">Previous</button>
            <button @click="goToActivityPage(activityPagination.current_page + 1)" :disabled="activityPagination.current_page >= activityPagination.last_page" class="admin-button-secondary text-sm" :class="{ 'opacity-50 cursor-not-allowed': activityPagination.current_page >= activityPagination.last_page }">Next</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Transactions Tab -->
    <div v-show="activeTab === 'transactions'">
      <!-- 篩選器 -->
      <div class="admin-card mb-6">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              v-model="transactionFilters.search"
              type="text"
              placeholder="User ID, name, email..."
              class="admin-input"
              @input="debouncedTransactionSearch"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Transaction Type</label>
            <select v-model="transactionFilters.transaction_type" @change="loadTransactions" class="admin-input">
              <option value="">All</option>
              <option value="earn">Income</option>
              <option value="spend">Expense</option>
              <option value="deposit">Deposit</option>
              <option value="fee">Fee</option>
              <option value="refund">Refund</option>
              <option value="adjustment">Adjustment</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select v-model="transactionFilters.status" @change="loadTransactions" class="admin-input">
              <option value="">All</option>
              <option value="completed">Completed</option>
              <option value="pending">Pending</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
            <input v-model="transactionFilters.date_from" type="date" class="admin-input" @change="loadTransactions" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
            <input v-model="transactionFilters.date_to" type="date" class="admin-input" @change="loadTransactions" />
          </div>
        </div>
      </div>

      <!-- 統計卡片 -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-6">
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Transactions</dt>
                <dd class="text-lg font-medium text-gray-900">{{ transactionStats?.total_transactions || 0 }}</dd>
              </dl>
            </div>
          </div>
        </div>
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
                <dd class="text-lg font-medium text-gray-900">{{ transactionStats?.unique_users || 0 }}</dd>
              </dl>
            </div>
          </div>
        </div>
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-emerald-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Income</dt>
                <dd class="text-lg font-medium text-green-600">{{ formatPoints(transactionStats?.total_income || 0) }}</dd>
              </dl>
            </div>
          </div>
        </div>
        <div class="admin-card">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Expense</dt>
                <dd class="text-lg font-medium text-red-600">{{ formatPoints(transactionStats?.total_expense || 0) }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- 交易列表 -->
      <div class="admin-card">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Transaction Records</h3>
          <div class="flex items-center space-x-4">
            <div class="text-sm text-gray-500">
              Showing {{ transactionPaginationInfo.from }} to {{ transactionPaginationInfo.to }} of {{ transactionPaginationInfo.total }} results
            </div>
            <select v-model="transactionPagination.per_page" @change="handleTransactionPerPageChange" class="admin-input text-sm py-1">
              <option value="15">15</option>
              <option value="25">25</option>
              <option value="50">50</option>
              <option value="100">100</option>
            </select>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">User</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Amount</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Related Task</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-if="transactionLoading">
                <td colspan="8" class="px-6 py-8 text-center text-gray-500">
                  <div class="flex justify-center items-center">
                    <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-cyan-600 mr-2"></div>
                    Loading...
                  </div>
                </td>
              </tr>
              <tr v-else-if="transactions.length === 0">
                <td colspan="8" class="px-6 py-8 text-center text-gray-500">No transactions found.</td>
              </tr>
              <tr v-for="tx in transactions" :key="tx.id" class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{{ tx.id }}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div class="h-8 w-8 rounded-full bg-cyan-100 flex items-center justify-center">
                      <span class="text-sm font-medium text-cyan-600">{{ getUserInitials(tx.user_name) }}</span>
                    </div>
                    <div class="ml-3">
                      <div class="text-sm font-medium text-gray-900">{{ tx.user_name || 'Unknown' }}</div>
                      <div class="text-xs text-gray-500">{{ tx.user_email }}</div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="getTransactionTypeBadgeClass(tx.transaction_type)">
                    {{ getTransactionTypeText(tx.transaction_type) }}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="text-sm font-medium" :class="tx.amount > 0 ? 'text-green-600' : 'text-red-600'">
                    {{ tx.amount > 0 ? '+' : '' }}{{ formatPoints(tx.amount) }}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-900">
                  <div class="max-w-xs truncate" :title="tx.description">{{ tx.description }}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <span v-if="tx.related_task_id" class="text-cyan-600">{{ tx.related_task_id }}</span>
                  <span v-else class="text-gray-400">-</span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full" :class="getStatusBadgeClass(tx.status)">
                    {{ getStatusText(tx.status) }}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ formatDate(tx.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <!-- 分頁 -->
        <div v-if="transactionPagination.total > transactionPagination.per_page" class="mt-6 flex items-center justify-between">
          <div class="text-sm text-gray-700">
            Page {{ transactionPagination.current_page }} of {{ transactionPagination.last_page }}
          </div>
          <div class="flex space-x-2">
            <button @click="goToTransactionPage(transactionPagination.current_page - 1)" :disabled="transactionPagination.current_page <= 1" class="admin-button-secondary text-sm" :class="{ 'opacity-50 cursor-not-allowed': transactionPagination.current_page <= 1 }">Previous</button>
            <button @click="goToTransactionPage(transactionPagination.current_page + 1)" :disabled="transactionPagination.current_page >= transactionPagination.last_page" class="admin-button-secondary text-sm" :class="{ 'opacity-50 cursor-not-allowed': transactionPagination.current_page >= transactionPagination.last_page }">Next</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed, watch } from 'vue'
import { userActivityApi, userTransactionApi } from '@/services/api'

// Tabs
const activeTab = ref<'activities' | 'transactions'>('activities')
const tabs = computed(() => [
  { id: 'activities', name: 'Activities', count: activityStats.value?.total_activities },
  { id: 'transactions', name: 'Transactions', count: transactionStats.value?.total_transactions },
])

// ========== Activities ==========
const activityLoading = ref(false)
const activities = ref<any[]>([])
const activityStats = ref<any>(null)

const activityPagination = reactive({
  current_page: 1,
  per_page: 15,
  total: 0,
  last_page: 1
})

const activityFilters = reactive({
  action: '',
  actor_type: '' as '' | 'user' | 'admin' | 'system',
  date_from: '',
  date_to: '',
  search: ''
})

// Debounced search for activities
let activitySearchTimeout: number
const debouncedActivitySearch = () => {
  clearTimeout(activitySearchTimeout)
  activitySearchTimeout = setTimeout(() => {
    activityPagination.current_page = 1
    loadActivities()
  }, 500)
}

const activityPaginationInfo = computed(() => {
  const from = (activityPagination.current_page - 1) * activityPagination.per_page + 1
  const to = Math.min(activityPagination.current_page * activityPagination.per_page, activityPagination.total)
  return { from: activityPagination.total ? from : 0, to, total: activityPagination.total }
})

const loadActivities = async () => {
  activityLoading.value = true
  try {
    const params = {
      page: activityPagination.current_page,
      per_page: activityPagination.per_page,
      ...(activityFilters.action && { action: activityFilters.action }),
      ...(activityFilters.actor_type && { actor_type: activityFilters.actor_type }),
      ...(activityFilters.date_from && { date_from: activityFilters.date_from }),
      ...(activityFilters.date_to && { date_to: activityFilters.date_to }),
      ...(activityFilters.search && { search: activityFilters.search }),
    }
    const response = await userActivityApi.list(params)
    if (response.data?.success && response.data.data) {
      activities.value = response.data.data.items || []
      if (response.data.data.pagination) {
        activityPagination.total = response.data.data.pagination.total
        activityPagination.last_page = response.data.data.pagination.last_page
      }
      activityStats.value = response.data.data.stats || null
    }
  } catch (error) {
    console.error('Failed to load activities:', error)
  } finally {
    activityLoading.value = false
  }
}

const goToActivityPage = (page: number) => {
  activityPagination.current_page = page
  loadActivities()
}

const handleActivityPerPageChange = () => {
  activityPagination.current_page = 1
  loadActivities()
}

// ========== Transactions ==========
const transactionLoading = ref(false)
const transactions = ref<any[]>([])
const transactionStats = ref<any>(null)

const transactionPagination = reactive({
  current_page: 1,
  per_page: 15,
  total: 0,
  last_page: 1
})

const transactionFilters = reactive({
  transaction_type: '',
  status: '',
  date_from: '',
  date_to: '',
  search: ''
})

// Debounced search for transactions
let transactionSearchTimeout: number
const debouncedTransactionSearch = () => {
  clearTimeout(transactionSearchTimeout)
  transactionSearchTimeout = setTimeout(() => {
    transactionPagination.current_page = 1
    loadTransactions()
  }, 500)
}

const transactionPaginationInfo = computed(() => {
  const from = (transactionPagination.current_page - 1) * transactionPagination.per_page + 1
  const to = Math.min(transactionPagination.current_page * transactionPagination.per_page, transactionPagination.total)
  return { from: transactionPagination.total ? from : 0, to, total: transactionPagination.total }
})

const loadTransactions = async () => {
  transactionLoading.value = true
  try {
    const params = {
      page: transactionPagination.current_page,
      per_page: transactionPagination.per_page,
      transaction_type: (transactionFilters.transaction_type || undefined) as 'earn' | 'spend' | 'deposit' | 'fee' | 'refund' | 'adjustment' | undefined,
      status: transactionFilters.status || undefined,
      date_from: transactionFilters.date_from || undefined,
      date_to: transactionFilters.date_to || undefined,
      search: transactionFilters.search || undefined,
    }
    const response = await userTransactionApi.list(params)
    if (response.data?.success && response.data.data) {
      transactions.value = response.data.data.items || []
      if (response.data.data.pagination) {
        transactionPagination.total = response.data.data.pagination.total
        transactionPagination.last_page = response.data.data.pagination.last_page
      }
      if (response.data.data.stats) {
        transactionStats.value = {
          total_transactions: response.data.data.pagination?.total || 0,
          unique_users: response.data.data.stats.unique_users || 0,
          total_income: response.data.data.stats.total_income || 0,
          total_expense: response.data.data.stats.total_expense || 0
        }
      }
    }
  } catch (error) {
    console.error('Failed to load transactions:', error)
  } finally {
    transactionLoading.value = false
  }
}

const goToTransactionPage = (page: number) => {
  transactionPagination.current_page = page
  loadTransactions()
}

const handleTransactionPerPageChange = () => {
  transactionPagination.current_page = 1
  loadTransactions()
}

// ========== Utilities ==========
const getUserInitials = (name: string) => {
  if (!name) return '?'
  return name.split(' ').map(n => n.charAt(0)).join('').toUpperCase().substring(0, 2)
}

const formatDate = (dateString: string) => new Date(dateString).toLocaleString('zh-TW')

const formatPoints = (points: number) => points.toLocaleString() + ' pts'

const getActionBadgeClass = (action: string) => {
  const map: Record<string, string> = {
    'register': 'bg-green-100 text-green-800',
    'login': 'bg-blue-100 text-blue-800',
    'logout': 'bg-gray-100 text-gray-800',
    'permission_change': 'bg-yellow-100 text-yellow-800',
    'status_change': 'bg-orange-100 text-orange-800',
  }
  return map[action] || 'bg-gray-100 text-gray-800'
}

const getActionText = (action: string) => {
  const map: Record<string, string> = {
    'register': 'Register',
    'login': 'Login',
    'logout': 'Logout',
    'permission_change': 'Permission Change',
    'status_change': 'Status Change',
  }
  return map[action] || action
}

const getTransactionTypeBadgeClass = (type: string) => {
  const map: Record<string, string> = {
    'earn': 'bg-green-100 text-green-800',
    'spend': 'bg-red-100 text-red-800',
    'deposit': 'bg-blue-100 text-blue-800',
    'fee': 'bg-orange-100 text-orange-800',
    'refund': 'bg-purple-100 text-purple-800',
  }
  return map[type] || 'bg-gray-100 text-gray-800'
}

const getTransactionTypeText = (type: string) => {
  const map: Record<string, string> = {
    'earn': 'Income',
    'spend': 'Expense',
    'deposit': 'Deposit',
    'fee': 'Fee',
    'refund': 'Refund',
    'adjustment': 'Adjustment',
  }
  return map[type] || type
}

const getStatusBadgeClass = (status: string) => {
  const map: Record<string, string> = {
    'completed': 'bg-green-100 text-green-800',
    'pending': 'bg-yellow-100 text-yellow-800',
    'cancelled': 'bg-red-100 text-red-800',
  }
  return map[status] || 'bg-gray-100 text-gray-800'
}

const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    'completed': 'Completed',
    'pending': 'Pending',
    'cancelled': 'Cancelled',
  }
  return map[status] || status
}

const refreshData = () => {
  if (activeTab.value === 'activities') {
    loadActivities()
  } else {
    loadTransactions()
  }
}

// 當切換 tab 時載入資料
watch(activeTab, (newTab) => {
  if (newTab === 'activities' && activities.value.length === 0) {
    loadActivities()
  } else if (newTab === 'transactions' && transactions.value.length === 0) {
    loadTransactions()
  }
})

onMounted(() => {
  loadActivities()
})
</script>
