<template>
  <div class="fee-management-page">
    <div class="page-header">
      <h1>手續費管理</h1>
      <div class="header-actions">
        <button @click="showUpdateFeeDialog = true" class="btn btn-primary">
          <i class="icon-edit"></i> 更新費率
        </button>
        <button @click="refreshData" class="btn btn-secondary" :disabled="loading">
          <i class="icon-refresh"></i> 刷新
        </button>
      </div>
    </div>

    <!-- 當前費率設定 -->
    <div class="current-settings-section">
      <h2>當前費率設定</h2>
      <div class="settings-card" v-if="currentSettings">
        <div class="setting-item">
          <label>當前費率:</label>
          <div class="rate-display">
            <span class="rate-value">{{ currentSettings.rate_percentage }}</span>
            <span class="rate-decimal">({{ currentSettings.rate }})</span>
          </div>
        </div>
        
        <div class="setting-item">
          <label>設定說明:</label>
          <div class="description">{{ currentSettings.description }}</div>
        </div>
        
        <div class="setting-item">
          <label>最後更新:</label>
          <div class="update-info">
            <span>{{ formatDate(currentSettings.updated_at) }}</span>
            <span class="updater">by {{ currentSettings.updated_by }}</span>
          </div>
        </div>
        
        <div class="setting-item">
          <label>計算範例:</label>
          <div class="calculation-example">
            <div class="example-row">
              <span>任務獎勵: 1000 點數</span>
              <span>手續費: {{ calculateFee(1000) }} 點數</span>
            </div>
            <div class="example-row">
              <span>發布者支付: {{ 1000 + calculateFee(1000) }} 點數</span>
              <span>接單者獲得: 1000 點數</span>
            </div>
          </div>
        </div>
      </div>
      
      <div v-else-if="!loading" class="no-settings">
        <i class="icon-warning"></i>
        <h3>尚未設定手續費</h3>
        <p>系統目前沒有啟用的手續費設定</p>
        <button @click="showUpdateFeeDialog = true" class="btn btn-primary">
          立即設定
        </button>
      </div>
    </div>

    <!-- 歷史設定記錄 -->
    <div class="history-section">
      <h2>歷史設定記錄</h2>
      <div class="history-table-container">
        <table class="history-table" v-if="history && history.length > 0">
          <thead>
            <tr>
              <th>設定ID</th>
              <th>費率</th>
              <th>說明</th>
              <th>狀態</th>
              <th>設定者</th>
              <th>設定時間</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="setting in history" :key="setting.id" :class="{ 'active-row': setting.is_active }">
              <td>{{ setting.id }}</td>
              <td>
                <span class="rate-badge">{{ setting.rate_percentage }}</span>
              </td>
              <td>{{ setting.description }}</td>
              <td>
                <span :class="setting.is_active ? 'status-active' : 'status-inactive'">
                  {{ setting.is_active ? '啟用中' : '已停用' }}
                </span>
              </td>
              <td>{{ setting.updated_by }}</td>
              <td>{{ formatDate(setting.created_at) }}</td>
            </tr>
          </tbody>
        </table>
        
        <div v-else-if="!loading" class="empty-history">
          <p>暫無歷史設定記錄</p>
        </div>
      </div>
    </div>

    <!-- 載入狀態 -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>載入中...</p>
    </div>

    <!-- 更新費率對話框 -->
    <div v-if="showUpdateFeeDialog" class="modal-overlay" @click="closeUpdateDialog">
      <div class="modal-content" @click.stop>
        <h3>更新手續費設定</h3>
        
        <form @submit.prevent="updateFeeSettings">
          <div class="form-group">
            <label>新費率 (%):</label>
            <div class="rate-input-group">
              <input 
                type="number" 
                v-model.number="newFeeSettings.ratePercentage"
                step="0.01"
                min="0"
                max="100"
                placeholder="例如: 2.5"
                required
              />
              <span class="input-suffix">%</span>
            </div>
            <div class="rate-preview">
              實際費率: {{ (newFeeSettings.ratePercentage / 100).toFixed(4) }}
            </div>
          </div>

          <div class="form-group">
            <label>設定說明:</label>
            <textarea 
              v-model="newFeeSettings.description"
              placeholder="請描述此次費率調整的原因..."
              rows="3"
              required
            ></textarea>
          </div>

          <div class="form-group">
            <label>生效時間:</label>
            <div class="radio-group">
              <label class="radio-option">
                <input type="radio" v-model="newFeeSettings.effectiveType" value="immediate" />
                立即生效
              </label>
              <label class="radio-option">
                <input type="radio" v-model="newFeeSettings.effectiveType" value="scheduled" />
                指定日期
              </label>
            </div>
            <input 
              v-if="newFeeSettings.effectiveType === 'scheduled'"
              type="date" 
              v-model="newFeeSettings.effectiveDate"
              :min="today"
              required
            />
          </div>

          <div class="calculation-preview">
            <h4>計算預覽</h4>
            <div class="preview-examples">
              <div class="example">
                <span>100 點數任務</span>
                <span>手續費: {{ calculateNewFee(100) }} 點數</span>
              </div>
              <div class="example">
                <span>500 點數任務</span>
                <span>手續費: {{ calculateNewFee(500) }} 點數</span>
              </div>
              <div class="example">
                <span>1000 點數任務</span>
                <span>手續費: {{ calculateNewFee(1000) }} 點數</span>
              </div>
            </div>
          </div>

          <div class="modal-actions">
            <button type="button" @click="closeUpdateDialog" class="btn btn-secondary">
              取消
            </button>
            <button type="submit" class="btn btn-primary" :disabled="updating">
              {{ updating ? '更新中...' : '確認更新' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '@/services/api'

export default {
  name: 'FeeManagementPage',
  setup() {
    const api = useApi()
    
    // 響應式數據
    const loading = ref(false)
    const updating = ref(false)
    const currentSettings = ref(null)
    const history = ref([])
    const showUpdateFeeDialog = ref(false)
    
    // 新費率設定表單
    const newFeeSettings = reactive({
      ratePercentage: 0,
      description: '',
      effectiveType: 'immediate',
      effectiveDate: ''
    })
    
    // 計算屬性
    const today = computed(() => {
      return new Date().toISOString().split('T')[0]
    })
    
    // 載入費率設定
    const loadFeeSettings = async () => {
      try {
        loading.value = true
        
        // TODO: 實際API調用
        // const response = await api.get('/admin/fees/settings', {
        //   params: { include_history: true }
        // })
        
        // 模擬數據
        const mockResponse = {
          success: true,
          data: {
            current_settings: {
              id: 1,
              rate: 0.025,
              rate_percentage: '2.50%',
              description: '標準手續費率',
              is_active: true,
              updated_by: 'admin',
              created_at: '2024-01-01 00:00:00',
              updated_at: '2024-01-01 00:00:00'
            },
            history: [
              {
                id: 1,
                rate: 0.025,
                rate_percentage: '2.50%',
                description: '標準手續費率',
                is_active: true,
                updated_by: 'admin',
                created_at: '2024-01-01 00:00:00'
              }
            ]
          }
        }
        
        currentSettings.value = mockResponse.data.current_settings
        history.value = mockResponse.data.history || []
        
      } catch (error) {
        console.error('載入費率設定失敗:', error)
        // TODO: 顯示錯誤提示
      } finally {
        loading.value = false
      }
    }
    
    // 更新費率設定
    const updateFeeSettings = async () => {
      try {
        updating.value = true
        
        const data = {
          rate: newFeeSettings.ratePercentage / 100,
          description: newFeeSettings.description,
          effective_date: newFeeSettings.effectiveType === 'scheduled' 
            ? newFeeSettings.effectiveDate 
            : null
        }
        
        // TODO: 實際API調用
        // await api.put('/admin/fees/settings', data)
        
        console.log('更新費率設定:', data)
        
        // 關閉對話框並刷新數據
        closeUpdateDialog()
        await loadFeeSettings()
        
        // TODO: 顯示成功提示
        
      } catch (error) {
        console.error('更新費率設定失敗:', error)
        // TODO: 顯示錯誤提示
      } finally {
        updating.value = false
      }
    }
    
    // 關閉更新對話框
    const closeUpdateDialog = () => {
      showUpdateFeeDialog.value = false
      // 重置表單
      newFeeSettings.ratePercentage = 0
      newFeeSettings.description = ''
      newFeeSettings.effectiveType = 'immediate'
      newFeeSettings.effectiveDate = ''
    }
    
    // 刷新數據
    const refreshData = () => {
      loadFeeSettings()
    }
    
    // 計算手續費
    const calculateFee = (amount) => {
      if (!currentSettings.value) return 0
      return Math.round(amount * currentSettings.value.rate)
    }
    
    // 計算新費率的手續費
    const calculateNewFee = (amount) => {
      const rate = newFeeSettings.ratePercentage / 100
      return Math.round(amount * rate)
    }
    
    // 格式化日期
    const formatDate = (dateString) => {
      return new Date(dateString).toLocaleString('zh-TW')
    }
    
    // 初始化
    onMounted(() => {
      loadFeeSettings()
    })
    
    return {
      loading,
      updating,
      currentSettings,
      history,
      showUpdateFeeDialog,
      newFeeSettings,
      today,
      loadFeeSettings,
      updateFeeSettings,
      closeUpdateDialog,
      refreshData,
      calculateFee,
      calculateNewFee,
      formatDate
    }
  }
}
</script>

<style scoped>
.fee-management-page {
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

.current-settings-section {
  margin-bottom: 40px;
}

.current-settings-section h2 {
  margin-bottom: 20px;
  color: #333;
  font-size: 20px;
}

.settings-card {
  background: white;
  padding: 25px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.setting-item {
  display: flex;
  align-items: flex-start;
  margin-bottom: 20px;
  padding-bottom: 15px;
  border-bottom: 1px solid #f0f0f0;
}

.setting-item:last-child {
  margin-bottom: 0;
  border-bottom: none;
}

.setting-item label {
  width: 120px;
  font-weight: 600;
  color: #555;
  margin-right: 20px;
}

.rate-display {
  display: flex;
  align-items: baseline;
  gap: 10px;
}

.rate-value {
  font-size: 24px;
  font-weight: bold;
  color: #e74c3c;
}

.rate-decimal {
  color: #666;
  font-size: 14px;
}

.description {
  color: #333;
  line-height: 1.5;
}

.update-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.updater {
  font-size: 12px;
  color: #666;
}

.calculation-example {
  background: #f8f9fa;
  padding: 15px;
  border-radius: 6px;
  border-left: 4px solid #3498db;
}

.example-row {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
  font-size: 14px;
}

.example-row:last-child {
  margin-bottom: 0;
}

.no-settings {
  text-align: center;
  padding: 60px 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.no-settings i {
  font-size: 48px;
  color: #f39c12;
  margin-bottom: 20px;
}

.no-settings h3 {
  margin-bottom: 10px;
  color: #333;
}

.history-section h2 {
  margin-bottom: 20px;
  color: #333;
  font-size: 20px;
}

.history-table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  overflow: hidden;
}

.history-table {
  width: 100%;
  border-collapse: collapse;
}

.history-table th,
.history-table td {
  padding: 15px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.history-table th {
  background: #f8f9fa;
  font-weight: 600;
  color: #555;
}

.active-row {
  background: #e8f5e8;
}

.rate-badge {
  background: #e74c3c;
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: bold;
}

.status-active {
  background: #d4edda;
  color: #155724;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.status-inactive {
  background: #f8d7da;
  color: #721c24;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.empty-history {
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
  max-width: 600px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.3);
  max-height: 90vh;
  overflow-y: auto;
}

.modal-content h3 {
  margin: 0 0 25px 0;
  color: #333;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-weight: 600;
  color: #555;
}

.rate-input-group {
  display: flex;
  align-items: center;
}

.rate-input-group input {
  flex: 1;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px 0 0 4px;
  font-size: 16px;
}

.input-suffix {
  background: #f8f9fa;
  border: 1px solid #ddd;
  border-left: none;
  border-radius: 0 4px 4px 0;
  padding: 10px 12px;
  color: #666;
}

.rate-preview {
  margin-top: 8px;
  font-size: 14px;
  color: #666;
}

.form-group textarea,
.form-group input[type="date"] {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-family: inherit;
}

.radio-group {
  display: flex;
  gap: 20px;
  margin-bottom: 15px;
}

.radio-option {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}

.radio-option input[type="radio"] {
  margin: 0;
}

.calculation-preview {
  background: #f8f9fa;
  padding: 20px;
  border-radius: 6px;
  margin-bottom: 20px;
}

.calculation-preview h4 {
  margin: 0 0 15px 0;
  color: #333;
}

.preview-examples {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.example {
  display: flex;
  justify-content: space-between;
  padding: 8px 12px;
  background: white;
  border-radius: 4px;
  font-size: 14px;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-primary {
  background: #3498db;
  color: white;
}

.btn-primary:hover {
  background: #2980b9;
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
</style>
