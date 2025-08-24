<template>
  <div class="all-user-transactions-page">
    <div class="page-header">
      <h1>用戶點數記錄</h1>
      <div class="header-actions">
        <button @click="exportTransactions" class="btn btn-success" :disabled="loading">
          <i class="icon-download"></i> 匯出記錄
        </button>
        <button @click="refreshData" class="btn btn-secondary" :disabled="loading">
          <i class="icon-refresh"></i> 刷新
        </button>
      </div>
    </div>

    <!-- 篩選器 -->
    <div class="filters-section">
      <div class="filter-row">
        <div class="filter-group">
          <label>用戶搜尋:</label>
          <input 
            type="text" 
            v-model="filters.userSearch"
            @input="debounceSearch"
            placeholder="輸入用戶ID、姓名或郵箱"
            class="user-search-input"
          />
        </div>
        
        <div class="filter-group">
          <label>交易類型:</label>
          <select v-model="filters.transactionType" @change="loadTransactions">
            <option value="">全部類型</option>
            <option value="earn">任務收入</option>
            <option value="spend">任務支出</option>
            <option value="deposit">儲值</option>
            <option value="fee">手續費</option>
            <option value="refund">退款</option>
            <option value="adjustment">調整</option>
          </select>
        </div>

        <div class="filter-group">
          <label>日期範圍:</label>
          <input 
            type="date" 
            v-model="filters.fromDate" 
            @change="loadTransactions"
          />
          <span>至</span>
          <input 
            type="date" 
            v-model="filters.toDate" 
            @change="loadTransactions"
          />
        </div>
      </div>

      <div class="filter-row">
        <div class="quick-filters">
          <button @click="setQuickFilter('today')" class="btn btn-outline btn-sm">今日</button>
          <button @click="setQuickFilter('week')" class="btn btn-outline btn-sm">本週</button>
          <button @click="setQuickFilter('month')" class="btn btn-outline btn-sm">本月</button>
          <button @click="clearFilters" class="btn btn-outline btn-sm">清除篩選</button>
        </div>
      </div>
    </div>

    <!-- 統計摘要 -->
    <div class="summary-section" v-if="transactionData && transactionData.summary">
      <div class="summary-cards">
        <div class="summary-card">
          <h3>總交易筆數</h3>
          <div class="summary-value">{{ transactionData.summary.total_transactions.toLocaleString() }}</div>
        </div>
        
        <div class="summary-card income">
          <h3>總收入</h3>
          <div class="summary-value">{{ formatPoints(transactionData.summary.total_income) }}</div>
        </div>
        
        <div class="summary-card expense">
          <h3>總支出</h3>
          <div class="summary-value">{{ formatPoints(transactionData.summary.total_expense) }}</div>
        </div>
        
        <div class="summary-card net">
          <h3>淨變動</h3>
          <div class="summary-value" :class="getNetChangeClass(transactionData.summary.net_change)">
            {{ formatPoints(transactionData.summary.net_change, true) }}
          </div>
        </div>
      </div>
    </div>

    <!-- 交易記錄表格 -->
    <div class="transactions-table-container">
      <table class="transactions-table" v-if="!loading && transactions.length > 0">
        <thead>
          <tr>
            <th>交易ID</th>
            <th>用戶資訊</th>
            <th>交易類型</th>
            <th>金額</th>
            <th>交易後餘額</th>
            <th>描述</th>
            <th>相關任務</th>
            <th>狀態</th>
            <th>交易時間</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="transaction in transactions" :key="transaction.id" :class="getRowClass(transaction)">
            <td class="transaction-id">{{ transaction.id }}</td>
            
            <td class="user-info">
              <div class="user-details">
                <div class="user-name">{{ transaction.user_info.display_name }}</div>
                <div class="user-id">ID: {{ transaction.user_id }}</div>
                <div class="user-email">{{ transaction.user_info.email }}</div>
              </div>
            </td>
            
            <td>
              <span :class="getTypeClass(transaction.transaction_type)">
                {{ transaction.display_type }}
              </span>
            </td>
            
            <td class="amount-cell">
              <span :class="getAmountClass(transaction.is_income)">
                {{ transaction.formatted_amount }}
              </span>
              <span class="currency">點數</span>
            </td>
            
        
            <td class="description-cell">
              <div class="description-text" :title="transaction.description">
                {{ transaction.description }}
              </div>
            </td>
            
            <td class="task-cell">
              <div v-if="transaction.related_task_id" class="task-link">
                <a href="#" @click="viewTask(transaction.related_task_id)">
                  {{ transaction.related_task_id }}
                </a>
              </div>
              <span v-else class="no-task">-</span>
            </td>
            
            <td>
              <span :class="getStatusClass(transaction.status)">
                {{ getStatusText(transaction.status) }}
              </span>
            </td>
            
            <td class="time-cell">
              {{ formatDate(transaction.created_at) }}
            </td>
          </tr>
        </tbody>
      </table>

      <!-- 載入狀態 -->
      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>載入交易記錄中...</p>
      </div>

      <!-- 空狀態 -->
      <div v-if="!loading && transactions.length === 0" class="empty-state">
        <i class="icon-empty"></i>
        <h3>暫無交易記錄</h3>
        <p>沒有符合篩選條件的交易記錄</p>
      </div>
    </div>

    <!-- 分頁 -->
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <button 
        @click="changePage(1)"
        :disabled="pagination.current_page === 1 || loading"
        class="btn btn-secondary btn-sm"
      >
        首頁
      </button>
      
      <button 
        @click="changePage(pagination.current_page - 1)"
        :disabled="!pagination.has_prev_page || loading"
        class="btn btn-secondary btn-sm"
      >
        上一頁
      </button>
      
      <div class="page-info">
        <span>第 {{ pagination.current_page }} 頁，共 {{ pagination.total_pages }} 頁</span>
        <span class="total-info">(總計 {{ pagination.total }} 筆記錄)</span>
      </div>
      
      <button 
        @click="changePage(pagination.current_page + 1)"
        :disabled="!pagination.has_next_page || loading"
        class="btn btn-secondary btn-sm"
      >
        下一頁
      </button>
      
      <button 
        @click="changePage(pagination.total_pages)"
        :disabled="pagination.current_page === pagination.total_pages || loading"
        class="btn btn-secondary btn-sm"
      >
        末頁
      </button>
    </div>

    <!-- 交易類型統計 -->
    <div class="type-statistics" v-if="transactionData && transactionData.summary.by_type">
      <h2>交易類型統計</h2>
      <div class="type-stats-grid">
        <div 
          v-for="(stats, type) in transactionData.summary.by_type" 
          :key="type"
          class="type-stat-card"
        >
          <div class="type-header">
            <span :class="getTypeClass(type)">{{ stats.display_name }}</span>
          </div>
          <div class="type-stats">
            <div class="stat-item">
              <label>交易筆數:</label>
              <span>{{ stats.count.toLocaleString() }}</span>
            </div>
            <div class="stat-item">
              <label>總收入:</label>
              <span class="income">{{ formatPoints(stats.total_income) }}</span>
            </div>
            <div class="stat-item">
              <label>總支出:</label>
              <span class="expense">{{ formatPoints(stats.total_expense) }}</span>
            </div>
            <div class="stat-item">
              <label>平均金額:</label>
              <span>{{ stats.avg_amount }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, onMounted } from 'vue'
import { useApi } from '@/services/api'

export default {
  name: 'AllUserTransactionsPage',
  setup() {
    const api = useApi()
    
    // 響應式數據
    const loading = ref(false)
    const transactions = ref([])
    const transactionData = ref(null)
    const pagination = ref(null)
    let searchTimeout = null
    
    // 篩選器
    const filters = reactive({
      userSearch: '',
      transactionType: '',
      fromDate: '',
      toDate: '',
      page: 1,
      perPage: 20
    })
    
    // 載入交易記錄
    const loadTransactions = async () => {
      try {
        loading.value = true
        
        const params = {
          page: filters.page,
          per_page: filters.perPage
        }
        
        if (filters.userSearch) params.user_id = filters.userSearch
        if (filters.transactionType) params.transaction_type = filters.transactionType
        if (filters.fromDate) params.from = filters.fromDate
        if (filters.toDate) params.to = filters.toDate
        
        // TODO: 實際API調用
        // const response = await api.get('/admin/users/point-transactions', { params })
        
        // 模擬數據
        const mockResponse = {
          success: true,
          data: {
            transactions: [
              {
                id: 1001,
                user_id: 123,
                user_info: {
                  name: '張三',
                  nickname: '小張',
                  email: 'zhang@example.com',
                  display_name: '小張'
                },
                transaction_type: 'earn',
                amount: 500,
                description: 'Task completed: 網站開發專案',
                related_task_id: 'T001',
                related_order_id: null,
                status: 'completed',
                created_at: '2024-01-15 14:30:00',
                formatted_amount: '+500',
                is_income: true,
                display_type: 'Task Earnings'
              },
              {
                id: 1002,
                user_id: 456,
                user_info: {
                  name: '李四',
                  nickname: null,
                  email: 'li@example.com',
                  display_name: '李四'
                },
                transaction_type: 'spend',
                amount: -300,
                description: 'Task payment: UI設計任務',
                related_task_id: 'T002',
                related_order_id: null,
                status: 'completed',
                created_at: '2024-01-15 13:20:00',
                formatted_amount: '-300',
                is_income: false,
                display_type: 'Task Spending'
              }
            ],
            pagination: {
              current_page: 1,
              total_pages: 5,
              total: 98,
              has_prev_page: false,
              has_next_page: true
            },
            summary: {
              total_transactions: 98,
              total_income: 25000,
              total_expense: 18000,
              net_change: 7000,
              by_type: {
                earn: {
                  count: 45,
                  total_income: 15000,
                  total_expense: 0,
                  avg_amount: 333.33,
                  display_name: 'Task Earnings'
                },
                spend: {
                  count: 30,
                  total_income: 0,
                  total_expense: 12000,
                  avg_amount: 400,
                  display_name: 'Task Spending'
                }
              }
            }
          }
        }
        
        transactions.value = mockResponse.data.transactions
        pagination.value = mockResponse.data.pagination
        transactionData.value = mockResponse.data
        
      } catch (error) {
        console.error('載入交易記錄失敗:', error)
        // TODO: 顯示錯誤提示
      } finally {
        loading.value = false
      }
    }
    
    // 防抖搜尋
    const debounceSearch = () => {
      clearTimeout(searchTimeout)
      searchTimeout = setTimeout(() => {
        filters.page = 1
        loadTransactions()
      }, 500)
    }
    
    // 設定快速篩選
    const setQuickFilter = (range) => {
      const today = new Date()
      const formatDate = (date) => date.toISOString().split('T')[0]
      
      switch (range) {
        case 'today':
          filters.fromDate = formatDate(today)
          filters.toDate = formatDate(today)
          break
        case 'week':
          const weekStart = new Date(today)
          weekStart.setDate(today.getDate() - today.getDay())
          filters.fromDate = formatDate(weekStart)
          filters.toDate = formatDate(today)
          break
        case 'month':
          const monthStart = new Date(today.getFullYear(), today.getMonth(), 1)
          filters.fromDate = formatDate(monthStart)
          filters.toDate = formatDate(today)
          break
      }
      filters.page = 1
      loadTransactions()
    }
    
    // 清除篩選
    const clearFilters = () => {
      filters.userSearch = ''
      filters.transactionType = ''
      filters.fromDate = ''
      filters.toDate = ''
      filters.page = 1
      loadTransactions()
    }
    
    // 換頁
    const changePage = (page) => {
      filters.page = page
      loadTransactions()
    }
    
    // 刷新數據
    const refreshData = () => {
      filters.page = 1
      loadTransactions()
    }
    
    // 匯出交易記錄
    const exportTransactions = () => {
      // TODO: 實現匯出功能
      console.log('匯出交易記錄')
    }
    
    // 查看任務詳情
    const viewTask = (taskId) => {
      // TODO: 跳轉到任務詳情頁面
      console.log('查看任務:', taskId)
    }
    
    // 工具函數
    const formatPoints = (points, showSign = false) => {
      const formatted = Math.abs(points).toLocaleString()
      if (showSign) {
        return points >= 0 ? `+${formatted}` : `-${formatted}`
      }
      return formatted
    }
    
    const formatDate = (dateString) => {
      return new Date(dateString).toLocaleString('zh-TW')
    }
    
    const getRowClass = (transaction) => {
      return {
        'income-row': transaction.is_income,
        'expense-row': !transaction.is_income,
        'pending-row': transaction.status === 'pending'
      }
    }
    
    const getTypeClass = (type) => {
      return `type-${type}`
    }
    
    const getAmountClass = (isIncome) => {
      return isIncome ? 'amount-positive' : 'amount-negative'
    }
    
    const getStatusClass = (status) => {
      return `status-${status}`
    }
    
    const getStatusText = (status) => {
      const statusMap = {
        completed: '已完成',
        pending: '處理中',
        cancelled: '已取消'
      }
      return statusMap[status] || status
    }
    
    const getNetChangeClass = (netChange) => {
      return netChange >= 0 ? 'net-positive' : 'net-negative'
    }
    
    // 初始化
    onMounted(() => {
      loadTransactions()
    })
    
    return {
      loading,
      transactions,
      transactionData,
      pagination,
      filters,
      loadTransactions,
      debounceSearch,
      setQuickFilter,
      clearFilters,
      changePage,
      refreshData,
      exportTransactions,
      viewTask,
      formatPoints,
      formatDate,
      getRowClass,
      getTypeClass,
      getAmountClass,
      getStatusClass,
      getStatusText,
      getNetChangeClass
    }
  }
}
</script>

<style scoped>
.all-user-transactions-page {
  padding: 20px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

.page-header h1 {
  margin: 0;
  color: #333;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.filters-section {
  background: #f8f9fa;
  padding: 20px;
  border-radius: 8px;
  margin-bottom: 30px;
}

.filter-row {
  display: flex;
  gap: 20px;
  align-items: center;
  margin-bottom: 15px;
  flex-wrap: wrap;
}

.filter-row:last-child {
  margin-bottom: 0;
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 8px;
}

.filter-group label {
  font-weight: 500;
  color: #555;
  white-space: nowrap;
}

.user-search-input {
  width: 250px;
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.quick-filters {
  display: flex;
  gap: 8px;
}

.summary-section {
  margin-bottom: 30px;
}

.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.summary-card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  text-align: center;
}

.summary-card h3 {
  margin: 0 0 10px 0;
  color: #666;
  font-size: 14px;
}

.summary-value {
  font-size: 24px;
  font-weight: bold;
  color: #2c3e50;
}

.summary-card.income .summary-value {
  color: #27ae60;
}

.summary-card.expense .summary-value {
  color: #e74c3c;
}

.net-positive {
  color: #27ae60;
}

.net-negative {
  color: #e74c3c;
}

.transactions-table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  overflow: hidden;
  margin-bottom: 30px;
}

.transactions-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}

.transactions-table th,
.transactions-table td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.transactions-table th {
  background: #f8f9fa;
  font-weight: 600;
  color: #555;
  position: sticky;
  top: 0;
}

.income-row {
  background: rgba(39, 174, 96, 0.05);
}

.expense-row {
  background: rgba(231, 76, 60, 0.05);
}

.pending-row {
  background: rgba(241, 196, 15, 0.05);
}

.transaction-id {
  font-family: monospace;
  color: #666;
}

.user-details .user-name {
  font-weight: 500;
  color: #333;
}

.user-details .user-id,
.user-details .user-email {
  font-size: 12px;
  color: #666;
}

.type-earn {
  background: #d4edda;
  color: #155724;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.type-spend {
  background: #f8d7da;
  color: #721c24;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.type-deposit {
  background: #cce5ff;
  color: #004085;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.type-fee {
  background: #fff3cd;
  color: #856404;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.type-refund {
  background: #e2e3e5;
  color: #383d41;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.type-adjustment {
  background: #d1ecf1;
  color: #0c5460;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.amount-positive {
  color: #27ae60;
  font-weight: bold;
}

.amount-negative {
  color: #e74c3c;
  font-weight: bold;
}

.currency {
  font-size: 12px;
  color: #666;
  margin-left: 4px;
}

.balance-cell {
  font-family: monospace;
  color: #333;
}

.description-cell {
  max-width: 200px;
}

.description-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.task-link a {
  color: #3498db;
  text-decoration: none;
}

.task-link a:hover {
  text-decoration: underline;
}

.no-task {
  color: #999;
}

.status-completed {
  background: #d4edda;
  color: #155724;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.status-pending {
  background: #fff3cd;
  color: #856404;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.status-cancelled {
  background: #f8d7da;
  color: #721c24;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.time-cell {
  font-size: 12px;
  color: #666;
  white-space: nowrap;
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #666;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 20px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 15px;
  margin-bottom: 30px;
}

.page-info {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: #666;
  font-size: 14px;
}

.total-info {
  font-size: 12px;
  color: #999;
}

.type-statistics {
  background: white;
  padding: 25px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.type-statistics h2 {
  margin: 0 0 20px 0;
  color: #333;
}

.type-stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
}

.type-stat-card {
  border: 1px solid #eee;
  border-radius: 8px;
  padding: 20px;
}

.type-header {
  margin-bottom: 15px;
}

.type-stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.stat-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.stat-item label {
  color: #666;
  font-size: 14px;
}

.stat-item .income {
  color: #27ae60;
  font-weight: 500;
}

.stat-item .expense {
  color: #e74c3c;
  font-weight: 500;
}

.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-sm {
  padding: 6px 12px;
  font-size: 12px;
}

.btn-success {
  background: #28a745;
  color: white;
}

.btn-success:hover {
  background: #218838;
}

.btn-secondary {
  background: #6c757d;
  color: white;
}

.btn-secondary:hover {
  background: #5a6268;
}

.btn-outline {
  background: transparent;
  border: 1px solid #ddd;
  color: #666;
}

.btn-outline:hover {
  background: #f8f9fa;
  border-color: #3498db;
  color: #3498db;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
