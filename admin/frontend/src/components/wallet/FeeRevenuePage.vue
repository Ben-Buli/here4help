<template>
  <div class="fee-revenue-page">
    <div class="page-header">
      <h1>手續費收入統計</h1>
      <div class="header-actions">
        <button @click="exportData" class="btn btn-success" :disabled="loading">
          <i class="icon-download"></i> 匯出報表
        </button>
        <button @click="refreshData" class="btn btn-secondary" :disabled="loading">
          <i class="icon-refresh"></i> 刷新
        </button>
      </div>
    </div>

    <!-- 篩選器 -->
    <div class="filters-section">
      <div class="filter-group">
        <label>統計週期:</label>
        <select v-model="filters.groupBy" @change="loadRevenueData">
          <option value="day">按日統計</option>
          <option value="month">按月統計</option>
          <option value="year">按年統計</option>
        </select>
      </div>
      
      <div class="filter-group">
        <label>日期範圍:</label>
        <input 
          type="date" 
          v-model="filters.fromDate" 
          @change="loadRevenueData"
          placeholder="開始日期"
        />
        <span>至</span>
        <input 
          type="date" 
          v-model="filters.toDate" 
          @change="loadRevenueData"
          placeholder="結束日期"
        />
      </div>

      <div class="filter-group">
        <button @click="setQuickDateRange('today')" class="btn btn-outline">今日</button>
        <button @click="setQuickDateRange('week')" class="btn btn-outline">本週</button>
        <button @click="setQuickDateRange('month')" class="btn btn-outline">本月</button>
        <button @click="setQuickDateRange('quarter')" class="btn btn-outline">本季</button>
      </div>
    </div>

    <!-- 收入統計卡片 -->
    <div class="revenue-stats" v-if="revenueData && revenueData.summary">
      <div class="stat-card total-revenue">
        <div class="stat-icon">
          <i class="icon-money"></i>
        </div>
        <div class="stat-content">
          <h3>總收入</h3>
          <div class="stat-value">{{ formatPoints(revenueData.summary.total_revenue) }}</div>
          <div class="stat-label">點數</div>
        </div>
      </div>

      <div class="stat-card total-transactions">
        <div class="stat-icon">
          <i class="icon-list"></i>
        </div>
        <div class="stat-content">
          <h3>交易筆數</h3>
          <div class="stat-value">{{ revenueData.summary.total_transactions.toLocaleString() }}</div>
          <div class="stat-label">筆</div>
        </div>
      </div>

      <div class="stat-card avg-fee">
        <div class="stat-icon">
          <i class="icon-calculator"></i>
        </div>
        <div class="stat-content">
          <h3>平均手續費</h3>
          <div class="stat-value">{{ revenueData.summary.avg_fee_per_transaction }}</div>
          <div class="stat-label">點數/筆</div>
        </div>
      </div>

      <div class="stat-card date-range">
        <div class="stat-icon">
          <i class="icon-calendar"></i>
        </div>
        <div class="stat-content">
          <h3>統計期間</h3>
          <div class="stat-value">{{ formatDateRange() }}</div>
          <div class="stat-label">{{ getGroupByLabel() }}</div>
        </div>
      </div>
    </div>

    <!-- 期間統計圖表區域 -->
    <div class="chart-section">
      <h2>收入趨勢</h2>
      <div class="chart-container">
        <div v-if="revenueData && revenueData.period_stats.length > 0" class="chart-placeholder">
          <!-- 這裡可以整合圖表庫如 Chart.js 或 ECharts -->
          <div class="simple-bar-chart">
            <div 
              v-for="(period, index) in revenueData.period_stats.slice(0, 10)" 
              :key="index"
              class="bar-item"
            >
              <div class="bar-label">{{ period.period }}</div>
              <div class="bar-container">
                <div 
                  class="bar-fill" 
                  :style="{ height: getBarHeight(period.period_revenue) + '%' }"
                ></div>
              </div>
              <div class="bar-value">{{ formatPoints(period.period_revenue) }}</div>
            </div>
          </div>
        </div>
        <div v-else-if="!loading" class="no-chart-data">
          <i class="icon-chart"></i>
          <p>暫無圖表數據</p>
        </div>
      </div>
    </div>

    <!-- 手續費最高任務排行 -->
    <div class="top-tasks-section">
      <h2>手續費最高任務</h2>
      <div class="top-tasks-container">
        <table class="top-tasks-table" v-if="revenueData && revenueData.top_tasks.length > 0">
          <thead>
            <tr>
              <th>排名</th>
              <th>任務ID</th>
              <th>任務標題</th>
              <th>總手續費</th>
              <th>手續費筆數</th>
              <th>平均費率</th>
              <th>最後收費時間</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(task, index) in revenueData.top_tasks" :key="task.task_id">
              <td class="rank-cell">
                <div class="rank-badge" :class="getRankClass(index)">
                  {{ index + 1 }}
                </div>
              </td>
              <td>{{ task.task_id }}</td>
              <td class="task-title">
                <div class="title-text">{{ task.task_title }}</div>
              </td>
              <td class="fee-amount">
                <span class="amount">{{ formatPoints(task.total_fees) }}</span>
                <span class="currency">點數</span>
              </td>
              <td>{{ task.fee_count }} 筆</td>
              <td>
                <span class="rate-badge">{{ task.avg_rate_percentage }}</span>
              </td>
              <td>{{ formatDate(task.last_fee_date) }}</td>
            </tr>
          </tbody>
        </table>

        <div v-else-if="!loading" class="empty-top-tasks">
          <i class="icon-empty"></i>
          <h3>暫無任務數據</h3>
          <p>目前沒有產生手續費的任務記錄</p>
        </div>
      </div>
    </div>

    <!-- 費率分佈統計 -->
    <div class="rate-distribution-section">
      <h2>費率分佈</h2>
      <div class="rate-distribution-container">
        <div v-if="revenueData && revenueData.rate_distribution.length > 0" class="rate-cards">
          <div 
            v-for="rate in revenueData.rate_distribution" 
            :key="rate.rate"
            class="rate-card"
          >
            <div class="rate-header">
              <span class="rate-percentage">{{ rate.rate_percentage }}</span>
              <span class="rate-decimal">({{ rate.rate }})</span>
            </div>
            <div class="rate-stats">
              <div class="rate-stat">
                <label>交易筆數:</label>
                <span>{{ rate.transaction_count.toLocaleString() }}</span>
              </div>
              <div class="rate-stat">
                <label>總收入:</label>
                <span>{{ formatPoints(rate.total_revenue) }} 點數</span>
              </div>
            </div>
          </div>
        </div>

        <div v-else-if="!loading" class="empty-rate-distribution">
          <p>暫無費率分佈數據</p>
        </div>
      </div>
    </div>

    <!-- 載入狀態 -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>載入收入統計中...</p>
    </div>
  </div>
</template>

<script>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '@/services/api'

export default {
  name: 'FeeRevenuePage',
  setup() {
    const api = useApi()
    
    // 響應式數據
    const loading = ref(false)
    const revenueData = ref(null)
    
    // 篩選器
    const filters = reactive({
      groupBy: 'day',
      fromDate: '',
      toDate: ''
    })
    
    // 載入收入數據
    const loadRevenueData = async () => {
      try {
        loading.value = true
        
        const params = {
          group_by: filters.groupBy
        }
        
        if (filters.fromDate) params.from = filters.fromDate
        if (filters.toDate) params.to = filters.toDate
        
        // TODO: 實際API調用
        // const response = await api.get('/admin/fees/revenue', { params })
        
        // 模擬數據
        const mockResponse = {
          success: true,
          data: {
            total_revenue: 25000,
            summary: {
              total_transactions: 1250,
              total_revenue: 25000,
              avg_fee_per_transaction: 20,
              first_transaction_date: '2024-01-01 00:00:00',
              last_transaction_date: '2024-01-15 23:59:59'
            },
            period_stats: [
              { period: '2024-01-15', transaction_count: 45, period_revenue: 900 },
              { period: '2024-01-14', transaction_count: 38, period_revenue: 760 },
              { period: '2024-01-13', transaction_count: 52, period_revenue: 1040 },
              { period: '2024-01-12', transaction_count: 41, period_revenue: 820 },
              { period: '2024-01-11', transaction_count: 35, period_revenue: 700 }
            ],
            top_tasks: [
              {
                task_id: 'T001',
                task_title: '網站開發專案',
                total_fees: 2500,
                fee_count: 5,
                avg_rate: 0.025,
                avg_rate_percentage: '2.50%',
                last_fee_date: '2024-01-15 14:30:00'
              },
              {
                task_id: 'T002', 
                task_title: 'UI設計任務',
                total_fees: 1800,
                fee_count: 3,
                avg_rate: 0.03,
                avg_rate_percentage: '3.00%',
                last_fee_date: '2024-01-14 16:20:00'
              }
            ],
            rate_distribution: [
              {
                rate: 0.025,
                rate_percentage: '2.50%',
                transaction_count: 800,
                total_revenue: 20000
              },
              {
                rate: 0.03,
                rate_percentage: '3.00%',
                transaction_count: 450,
                total_revenue: 5000
              }
            ]
          }
        }
        
        revenueData.value = mockResponse.data
        
      } catch (error) {
        console.error('載入收入統計失敗:', error)
        // TODO: 顯示錯誤提示
      } finally {
        loading.value = false
      }
    }
    
    // 設定快速日期範圍
    const setQuickDateRange = (range) => {
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
        case 'quarter':
          const quarterStart = new Date(today.getFullYear(), Math.floor(today.getMonth() / 3) * 3, 1)
          filters.fromDate = formatDate(quarterStart)
          filters.toDate = formatDate(today)
          break
      }
      loadRevenueData()
    }
    
    // 刷新數據
    const refreshData = () => {
      loadRevenueData()
    }
    
    // 匯出數據
    const exportData = () => {
      // TODO: 實現數據匯出功能
      console.log('匯出收入統計數據')
    }
    
    // 工具函數
    const formatPoints = (points) => {
      return points?.toLocaleString() || '0'
    }
    
    const formatDate = (dateString) => {
      return new Date(dateString).toLocaleString('zh-TW')
    }
    
    const formatDateRange = () => {
      if (filters.fromDate && filters.toDate) {
        return `${filters.fromDate} ~ ${filters.toDate}`
      }
      return '全部期間'
    }
    
    const getGroupByLabel = () => {
      const labels = {
        day: '按日統計',
        month: '按月統計', 
        year: '按年統計'
      }
      return labels[filters.groupBy] || '統計'
    }
    
    const getRankClass = (index) => {
      if (index === 0) return 'rank-gold'
      if (index === 1) return 'rank-silver'
      if (index === 2) return 'rank-bronze'
      return 'rank-normal'
    }
    
    const getBarHeight = (value) => {
      if (!revenueData.value?.period_stats?.length) return 0
      const maxValue = Math.max(...revenueData.value.period_stats.map(p => p.period_revenue))
      return maxValue > 0 ? (value / maxValue) * 100 : 0
    }
    
    // 初始化
    onMounted(() => {
      // 設定預設日期範圍為本月
      setQuickDateRange('month')
    })
    
    return {
      loading,
      revenueData,
      filters,
      loadRevenueData,
      setQuickDateRange,
      refreshData,
      exportData,
      formatPoints,
      formatDate,
      formatDateRange,
      getGroupByLabel,
      getRankClass,
      getBarHeight
    }
  }
}
</script>

<style scoped>
.fee-revenue-page {
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
  display: flex;
  gap: 20px;
  align-items: center;
  margin-bottom: 30px;
  padding: 20px;
  background: #f8f9fa;
  border-radius: 8px;
  flex-wrap: wrap;
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

.revenue-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 40px;
}

.stat-card {
  background: white;
  padding: 25px;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  display: flex;
  align-items: center;
  gap: 20px;
}

.stat-icon {
  width: 60px;
  height: 60px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  color: white;
}

.total-revenue .stat-icon {
  background: linear-gradient(135deg, #27ae60, #2ecc71);
}

.total-transactions .stat-icon {
  background: linear-gradient(135deg, #3498db, #5dade2);
}

.avg-fee .stat-icon {
  background: linear-gradient(135deg, #f39c12, #f4d03f);
}

.date-range .stat-icon {
  background: linear-gradient(135deg, #9b59b6, #bb8fce);
}

.stat-content h3 {
  margin: 0 0 8px 0;
  color: #666;
  font-size: 14px;
  font-weight: 500;
}

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #2c3e50;
  margin-bottom: 4px;
}

.stat-label {
  color: #888;
  font-size: 12px;
}

.chart-section,
.top-tasks-section,
.rate-distribution-section {
  margin-bottom: 40px;
}

.chart-section h2,
.top-tasks-section h2,
.rate-distribution-section h2 {
  margin-bottom: 20px;
  color: #333;
  font-size: 20px;
}

.chart-container {
  background: white;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.simple-bar-chart {
  display: flex;
  align-items: end;
  gap: 15px;
  height: 200px;
  padding: 20px 0;
}

.bar-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.bar-label {
  font-size: 12px;
  color: #666;
  transform: rotate(-45deg);
  white-space: nowrap;
}

.bar-container {
  width: 30px;
  height: 150px;
  background: #f0f0f0;
  border-radius: 4px;
  position: relative;
  overflow: hidden;
}

.bar-fill {
  position: absolute;
  bottom: 0;
  width: 100%;
  background: linear-gradient(to top, #3498db, #5dade2);
  border-radius: 4px;
  transition: height 0.3s ease;
}

.bar-value {
  font-size: 11px;
  color: #333;
  font-weight: 500;
}

.no-chart-data {
  text-align: center;
  padding: 60px;
  color: #666;
}

.top-tasks-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  overflow: hidden;
}

.top-tasks-table {
  width: 100%;
  border-collapse: collapse;
}

.top-tasks-table th,
.top-tasks-table td {
  padding: 15px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.top-tasks-table th {
  background: #f8f9fa;
  font-weight: 600;
  color: #555;
}

.rank-cell {
  text-align: center;
}

.rank-badge {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  color: white;
  font-size: 14px;
}

.rank-gold {
  background: linear-gradient(135deg, #f1c40f, #f39c12);
}

.rank-silver {
  background: linear-gradient(135deg, #bdc3c7, #95a5a6);
}

.rank-bronze {
  background: linear-gradient(135deg, #d35400, #e67e22);
}

.rank-normal {
  background: linear-gradient(135deg, #7f8c8d, #95a5a6);
}

.task-title {
  max-width: 200px;
}

.title-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.fee-amount {
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

.rate-badge {
  background: #e74c3c;
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: bold;
}

.rate-distribution-container {
  background: white;
  padding: 25px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.rate-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
}

.rate-card {
  border: 2px solid #f0f0f0;
  border-radius: 8px;
  padding: 20px;
  transition: all 0.2s;
}

.rate-card:hover {
  border-color: #3498db;
  box-shadow: 0 4px 12px rgba(52, 152, 219, 0.1);
}

.rate-header {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 15px;
}

.rate-percentage {
  font-size: 24px;
  font-weight: bold;
  color: #e74c3c;
}

.rate-decimal {
  color: #666;
  font-size: 14px;
}

.rate-stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.rate-stat {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.rate-stat label {
  color: #666;
  font-size: 14px;
}

.rate-stat span {
  font-weight: 500;
  color: #333;
}

.empty-top-tasks,
.empty-rate-distribution {
  text-align: center;
  padding: 40px;
  color: #666;
}

.loading-state {
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

.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.2s;
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
