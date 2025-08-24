<template>
  <div class="deposit-approval-page">
    <div class="page-header">
      <h1>儲值審核管理</h1>
      <div class="header-actions">
        <button @click="refreshData" class="btn btn-secondary" :disabled="loading">
          <i class="icon-refresh"></i> 刷新
        </button>
      </div>
    </div>

    <!-- 篩選器 -->
    <div class="filters-section">
      <div class="filter-group">
        <label>狀態篩選:</label>
        <select v-model="filters.status" @change="loadDeposits">
          <option value="">全部狀態</option>
          <option value="pending">待審核</option>
          <option value="approved">已通過</option>
          <option value="rejected">已拒絕</option>
        </select>
      </div>
      
      <div class="filter-group">
        <label>日期範圍:</label>
        <input 
          type="date" 
          v-model="filters.fromDate" 
          @change="loadDeposits"
          placeholder="開始日期"
        />
        <span>至</span>
        <input 
          type="date" 
          v-model="filters.toDate" 
          @change="loadDeposits"
          placeholder="結束日期"
        />
      </div>
    </div>

    <!-- 統計卡片 -->
    <div class="stats-cards" v-if="statistics">
      <div class="stat-card">
        <h3>待審核</h3>
        <div class="stat-value">{{ statistics.pending || 0 }}</div>
        <div class="stat-label">筆申請</div>
      </div>
      <div class="stat-card">
        <h3>今日通過</h3>
        <div class="stat-value">{{ statistics.approved_today || 0 }}</div>
        <div class="stat-label">筆申請</div>
      </div>
      <div class="stat-card">
        <h3>總金額</h3>
        <div class="stat-value">{{ formatPoints(statistics.total_amount || 0) }}</div>
        <div class="stat-label">點數</div>
      </div>
    </div>

    <!-- 申請列表 -->
    <div class="deposits-table-container">
      <table class="deposits-table" v-if="!loading && deposits.length > 0">
        <thead>
          <tr>
            <th>申請ID</th>
            <th>用戶資訊</th>
            <th>申請金額</th>
            <th>銀行資訊</th>
            <th>申請時間</th>
            <th>狀態</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="deposit in deposits" :key="deposit.id" :class="getRowClass(deposit.status)">
            <td>{{ deposit.id }}</td>
            <td>
              <div class="user-info">
                <div class="user-name">{{ deposit.user_name }}</div>
                <div class="user-email">{{ deposit.user_email }}</div>
              </div>
            </td>
            <td class="amount-cell">
              <span class="amount">{{ formatPoints(deposit.added_value) }}</span>
              <span class="currency">點數</span>
            </td>
            <td>
              <div class="bank-info">
                <div>末五碼: {{ deposit.bank_account_last5 }}</div>
                <div class="note" v-if="deposit.note">{{ deposit.note }}</div>
              </div>
            </td>
            <td>{{ formatDate(deposit.created_at) }}</td>
            <td>
              <span :class="getStatusClass(deposit.status)">
                {{ getStatusText(deposit.status) }}
              </span>
            </td>
            <td class="actions-cell">
              <div class="action-buttons" v-if="deposit.status === 'pending'">
                <button 
                  @click="approveDeposit(deposit)" 
                  class="btn btn-success btn-sm"
                  :disabled="processing"
                >
                  通過
                </button>
                <button 
                  @click="rejectDeposit(deposit)" 
                  class="btn btn-danger btn-sm"
                  :disabled="processing"
                >
                  拒絕
                </button>
              </div>
              <div v-else class="processed-info">
                <div>{{ deposit.admin_name || '系統' }}</div>
                <div class="process-time">{{ formatDate(deposit.updated_at) }}</div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- 載入狀態 -->
      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>載入中...</p>
      </div>

      <!-- 空狀態 -->
      <div v-if="!loading && deposits.length === 0" class="empty-state">
        <i class="icon-empty"></i>
        <h3>暫無儲值申請</h3>
        <p>目前沒有符合條件的儲值申請記錄</p>
      </div>
    </div>

    <!-- 分頁 -->
    <div class="pagination" v-if="pagination && pagination.total_pages > 1">
      <button 
        @click="changePage(pagination.current_page - 1)"
        :disabled="!pagination.has_prev_page || loading"
        class="btn btn-secondary"
      >
        上一頁
      </button>
      
      <span class="page-info">
        第 {{ pagination.current_page }} 頁，共 {{ pagination.total_pages }} 頁
        (總計 {{ pagination.total }} 筆)
      </span>
      
      <button 
        @click="changePage(pagination.current_page + 1)"
        :disabled="!pagination.has_next_page || loading"
        class="btn btn-secondary"
      >
        下一頁
      </button>
    </div>

    <!-- 審核對話框 -->
    <div v-if="showApprovalDialog" class="modal-overlay" @click="closeApprovalDialog">
      <div class="modal-content" @click.stop>
        <h3>{{ approvalAction === 'approve' ? '通過' : '拒絕' }}儲值申請</h3>
        
        <div class="deposit-details">
          <p><strong>用戶:</strong> {{ selectedDeposit?.user_name }}</p>
          <p><strong>金額:</strong> {{ formatPoints(selectedDeposit?.added_value || 0) }} 點數</p>
          <p><strong>銀行末五碼:</strong> {{ selectedDeposit?.bank_account_last5 }}</p>
        </div>

        <div class="form-group">
          <label>審核備註:</label>
          <textarea 
            v-model="approvalNote" 
            placeholder="請輸入審核備註..."
            rows="3"
          ></textarea>
        </div>

        <div class="modal-actions">
          <button @click="closeApprovalDialog" class="btn btn-secondary">取消</button>
          <button 
            @click="confirmApproval" 
            :class="approvalAction === 'approve' ? 'btn btn-success' : 'btn btn-danger'"
            :disabled="processing"
          >
            {{ processing ? '處理中...' : (approvalAction === 'approve' ? '確認通過' : '確認拒絕') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, onMounted } from 'vue'
import { useApi } from '@/services/api'

export default {
  name: 'DepositApprovalPage',
  setup() {
    const api = useApi()
    
    // 響應式數據
    const loading = ref(false)
    const processing = ref(false)
    const deposits = ref([])
    const statistics = ref(null)
    const pagination = ref(null)
    
    // 篩選器
    const filters = reactive({
      status: '',
      fromDate: '',
      toDate: '',
      page: 1,
      perPage: 20
    })
    
    // 審核對話框
    const showApprovalDialog = ref(false)
    const selectedDeposit = ref(null)
    const approvalAction = ref('')
    const approvalNote = ref('')
    
    // 載入儲值申請列表
    const loadDeposits = async () => {
      try {
        loading.value = true
        
        const params = {
          page: filters.page,
          per_page: filters.perPage
        }
        
        if (filters.status) params.status = filters.status
        if (filters.fromDate) params.from_date = filters.fromDate
        if (filters.toDate) params.to_date = filters.toDate
        
        // TODO: 實際API調用
        // const response = await api.get('/admin/deposits', { params })
        
        // 模擬數據
        const mockResponse = {
          success: true,
          data: {
            deposits: [
              {
                id: 1,
                user_id: 123,
                user_name: '張三',
                user_email: 'zhang@example.com',
                added_value: 1000,
                bank_account_last5: '12345',
                note: '急需點數完成任務',
                status: 'pending',
                created_at: '2024-01-15 10:30:00',
                updated_at: '2024-01-15 10:30:00',
                admin_name: null
              }
            ],
            pagination: {
              current_page: 1,
              total_pages: 1,
              total: 1,
              has_prev_page: false,
              has_next_page: false
            },
            statistics: {
              pending: 5,
              approved_today: 3,
              total_amount: 15000
            }
          }
        }
        
        deposits.value = mockResponse.data.deposits
        pagination.value = mockResponse.data.pagination
        statistics.value = mockResponse.data.statistics
        
      } catch (error) {
        console.error('載入儲值申請失敗:', error)
        // TODO: 顯示錯誤提示
      } finally {
        loading.value = false
      }
    }
    
    // 刷新數據
    const refreshData = () => {
      filters.page = 1
      loadDeposits()
    }
    
    // 換頁
    const changePage = (page) => {
      filters.page = page
      loadDeposits()
    }
    
    // 通過申請
    const approveDeposit = (deposit) => {
      selectedDeposit.value = deposit
      approvalAction.value = 'approve'
      approvalNote.value = ''
      showApprovalDialog.value = true
    }
    
    // 拒絕申請
    const rejectDeposit = (deposit) => {
      selectedDeposit.value = deposit
      approvalAction.value = 'reject'
      approvalNote.value = ''
      showApprovalDialog.value = true
    }
    
    // 確認審核
    const confirmApproval = async () => {
      try {
        processing.value = true
        
        const data = {
          deposit_id: selectedDeposit.value.id,
          action: approvalAction.value,
          note: approvalNote.value
        }
        
        // TODO: 實際API調用
        // await api.post('/admin/deposits/review', data)
        
        console.log('審核操作:', data)
        
        // 關閉對話框並刷新列表
        closeApprovalDialog()
        await loadDeposits()
        
      } catch (error) {
        console.error('審核操作失敗:', error)
        // TODO: 顯示錯誤提示
      } finally {
        processing.value = false
      }
    }
    
    // 關閉審核對話框
    const closeApprovalDialog = () => {
      showApprovalDialog.value = false
      selectedDeposit.value = null
      approvalAction.value = ''
      approvalNote.value = ''
    }
    
    // 工具函數
    const formatPoints = (points) => {
      return points.toLocaleString()
    }
    
    const formatDate = (dateString) => {
      return new Date(dateString).toLocaleString('zh-TW')
    }
    
    const getStatusText = (status) => {
      const statusMap = {
        pending: '待審核',
        approved: '已通過',
        rejected: '已拒絕'
      }
      return statusMap[status] || status
    }
    
    const getStatusClass = (status) => {
      return `status-${status}`
    }
    
    const getRowClass = (status) => {
      return `row-${status}`
    }
    
    // 初始化
    onMounted(() => {
      loadDeposits()
    })
    
    return {
      loading,
      processing,
      deposits,
      statistics,
      pagination,
      filters,
      showApprovalDialog,
      selectedDeposit,
      approvalAction,
      approvalNote,
      loadDeposits,
      refreshData,
      changePage,
      approveDeposit,
      rejectDeposit,
      confirmApproval,
      closeApprovalDialog,
      formatPoints,
      formatDate,
      getStatusText,
      getStatusClass,
      getRowClass
    }
  }
}
</script>

<style scoped>
.deposit-approval-page {
  padding: 20px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.page-header h1 {
  margin: 0;
  color: #333;
}

.filters-section {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
  padding: 15px;
  background: #f8f9fa;
  border-radius: 8px;
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 8px;
}

.filter-group label {
  font-weight: 500;
  color: #555;
}

.stats-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.stat-card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  text-align: center;
}

.stat-card h3 {
  margin: 0 0 10px 0;
  color: #666;
  font-size: 14px;
}

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #2c3e50;
  margin-bottom: 5px;
}

.stat-label {
  color: #888;
  font-size: 12px;
}

.deposits-table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
}

.deposits-table {
  width: 100%;
  border-collapse: collapse;
}

.deposits-table th,
.deposits-table td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.deposits-table th {
  background: #f8f9fa;
  font-weight: 600;
  color: #555;
}

.user-info .user-name {
  font-weight: 500;
  color: #333;
}

.user-info .user-email {
  font-size: 12px;
  color: #666;
}

.amount-cell {
  text-align: right;
}

.amount {
  font-weight: bold;
  color: #27ae60;
}

.currency {
  font-size: 12px;
  color: #666;
  margin-left: 4px;
}

.bank-info .note {
  font-size: 12px;
  color: #666;
  margin-top: 4px;
}

.status-pending {
  background: #fff3cd;
  color: #856404;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.status-approved {
  background: #d4edda;
  color: #155724;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.status-rejected {
  background: #f8d7da;
  color: #721c24;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.action-buttons {
  display: flex;
  gap: 8px;
}

.processed-info {
  font-size: 12px;
  color: #666;
}

.process-time {
  margin-top: 2px;
}

.btn {
  padding: 6px 12px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.2s;
}

.btn-sm {
  padding: 4px 8px;
  font-size: 11px;
}

.btn-success {
  background: #28a745;
  color: white;
}

.btn-success:hover {
  background: #218838;
}

.btn-danger {
  background: #dc3545;
  color: white;
}

.btn-danger:hover {
  background: #c82333;
}

.btn-secondary {
  background: #6c757d;
  color: white;
}

.btn-secondary:hover {
  background: #5a6268;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
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
  gap: 20px;
  margin-top: 20px;
}

.page-info {
  color: #666;
  font-size: 14px;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  padding: 30px;
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.3);
}

.modal-content h3 {
  margin: 0 0 20px 0;
  color: #333;
}

.deposit-details {
  background: #f8f9fa;
  padding: 15px;
  border-radius: 6px;
  margin-bottom: 20px;
}

.deposit-details p {
  margin: 5px 0;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: #555;
}

.form-group textarea {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: inherit;
  resize: vertical;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
