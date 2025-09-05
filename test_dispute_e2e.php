<?php
/**
 * 任務爭議模組端到端測試腳本
 * 模擬完整的用戶和管理員流程
 */

require_once __DIR__ . '/backend/config/database.php';
require_once __DIR__ . '/backend/utils/JWTManager.php';

class DisputeE2ETest {
    private $baseUrl;
    private $db;
    private $userToken;
    private $adminToken;
    private $testData = [];
    
    public function __construct() {
        $this->baseUrl = 'http://127.0.0.1:8888/here4help/backend/api';
        $this->db = Database::getInstance()->getConnection();
        
        echo "🚀 任務爭議模組端到端測試開始\n";
        echo "=================================\n\n";
    }
    
    /**
     * 執行完整測試流程
     */
    public function runFullTest() {
        try {
            // 1. 準備測試環境
            $this->setupTestEnvironment();
            
            // 2. 測試用戶流程
            $this->testUserFlow();
            
            // 3. 測試管理員流程  
            $this->testAdminFlow();
            
            // 4. 清理測試資料
            $this->cleanup();
            
            echo "\n🎉 所有測試完成！\n";
            
        } catch (Exception $e) {
            echo "\n❌ 測試失敗: " . $e->getMessage() . "\n";
            $this->cleanup();
        }
    }
    
    /**
     * 準備測試環境
     */
    private function setupTestEnvironment() {
        echo "📋 1. 準備測試環境\n";
        echo "-------------------\n";
        
        // 創建測試用戶 JWT token
        $this->userToken = $this->createTestUserToken();
        echo "✅ 用戶 JWT Token 創建完成\n";
        
        // 創建測試管理員 JWT token  
        $this->adminToken = $this->createTestAdminToken();
        echo "✅ 管理員 JWT Token 創建完成\n";
        
        // 準備測試資料
        $this->prepareTestData();
        echo "✅ 測試資料準備完成\n\n";
    }
    
    /**
     * 創建測試用戶 Token
     */
    private function createTestUserToken() {
        // 查找現有測試用戶
        $stmt = $this->db->prepare("SELECT id, email, name, permission FROM users WHERE email = ? LIMIT 1");
        $stmt->execute(['micahel@test.com']);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            throw new Exception("測試用戶不存在，請先創建 micahel@test.com 用戶");
        }
        
        $payload = [
            'user_id' => $user['id'],
            'email' => $user['email'], 
            'name' => $user['name'],
            'permission' => $user['permission'],
            'iat' => time(),
            'exp' => time() + 3600,
            'nbf' => time()
        ];
        
        return JWTManager::encode($payload);
    }
    
    /**
     * 創建測試管理員 Token
     */
    private function createTestAdminToken() {
        // 查找現有管理員
        $stmt = $this->db->prepare("SELECT id, username, email, full_name FROM admins WHERE status = 'active' LIMIT 1");
        $stmt->execute();
        $admin = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$admin) {
            throw new Exception("沒有可用的管理員帳號");
        }
        
        $payload = [
            'admin_id' => $admin['id'],
            'username' => $admin['username'],
            'email' => $admin['email'],
            'full_name' => $admin['full_name'],
            'role' => 'admin',
            'iat' => time(),
            'exp' => time() + 3600,
            'nbf' => time()
        ];
        
        return JWTManager::encode($payload);
    }
    
    /**
     * 準備測試資料
     */
    private function prepareTestData() {
        // 查找現有任務和聊天室
        $stmt = $this->db->prepare("
            SELECT t.id as task_id, cr.id as room_id, t.title, t.creator_id, t.participant_id
            FROM tasks t 
            JOIN chat_rooms cr ON t.id = cr.task_id 
            WHERE t.status_id != 4 AND cr.type = 'application'
            LIMIT 1
        ");
        $stmt->execute();
        $taskData = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$taskData) {
            throw new Exception("沒有可用的測試任務和聊天室");
        }
        
        $this->testData = [
            'task_id' => $taskData['task_id'],
            'room_id' => $taskData['room_id'],
            'task_title' => $taskData['title'],
            'creator_id' => $taskData['creator_id'],
            'participant_id' => $taskData['participant_id']
        ];
        
        echo "   📝 測試任務: {$this->testData['task_title']}\n";
        echo "   🏠 聊天室ID: {$this->testData['room_id']}\n";
    }
    
    /**
     * 測試用戶流程
     */
    private function testUserFlow() {
        echo "👤 2. 測試用戶流程\n";
        echo "-------------------\n";
        
        // 2.1 檢查現有爭議
        echo "🔍 2.1 檢查現有爭議...\n";
        $checkResult = $this->makeRequest(
            'GET',
            "/task-disputes/check.php?chat_room_id={$this->testData['room_id']}",
            null,
            $this->userToken
        );
        
        if ($checkResult['success']) {
            $exists = $checkResult['data']['exists'] ?? false;
            echo $exists ? "   ⚠️  已存在爭議\n" : "   ✅ 無現有爭議，可以提交\n";
            
            if ($exists) {
                echo "   📋 現有爭議資訊:\n";
                $dispute = $checkResult['data']['dispute'];
                echo "      ID: {$dispute['id']}\n";
                echo "      狀態: {$dispute['status']}\n";
                echo "      建立時間: {$dispute['created_at']}\n";
                return; // 如果已存在爭議，跳過提交測試
            }
        }
        
        // 2.2 提交新爭議
        echo "📝 2.2 提交新爭議...\n";
        $disputeData = [
            'task_id' => $this->testData['task_id'],
            'task_dispute_chat_room_id' => $this->testData['room_id'],
            'title' => '測試爭議標題 - 自動化測試',
            'description' => '這是一個自動化測試提交的爭議描述。測試時間: ' . date('Y-m-d H:i:s')
        ];
        
        $createResult = $this->makeRequest(
            'POST',
            '/task-disputes/create.php',
            $disputeData,
            $this->userToken
        );
        
        if ($createResult['success']) {
            $this->testData['dispute_id'] = $createResult['data']['dispute_id'];
            echo "   ✅ 爭議提交成功，ID: {$this->testData['dispute_id']}\n";
            
            // 驗證任務狀態是否更新
            $this->verifyTaskStatusUpdate();
        } else {
            throw new Exception("爭議提交失敗: " . ($createResult['message'] ?? '未知錯誤'));
        }
        
        echo "\n";
    }
    
    /**
     * 測試管理員流程
     */
    private function testAdminFlow() {
        echo "👨‍💼 3. 測試管理員流程\n";
        echo "---------------------\n";
        
        if (!isset($this->testData['dispute_id'])) {
            echo "⚠️  跳過管理員測試 - 沒有可用的爭議ID\n\n";
            return;
        }
        
        // 3.1 查看爭議列表
        echo "📋 3.1 查看爭議列表...\n";
        $listResult = $this->makeRequest(
            'GET',
            '/admin/task-disputes.php?page=1&per_page=10',
            null,
            $this->adminToken
        );
        
        if ($listResult['success']) {
            $total = $listResult['data']['pagination']['total'] ?? 0;
            echo "   ✅ 爭議列表載入成功，共 {$total} 筆\n";
        }
        
        // 3.2 查看聊天室
        echo "💬 3.2 查看爭議聊天室...\n";
        $chatResult = $this->makeRequest(
            'GET',
            "/admin/task-disputes/chat-room.php?dispute_id={$this->testData['dispute_id']}",
            null,
            $this->adminToken
        );
        
        if ($chatResult['success']) {
            $messageCount = count($chatResult['data']['messages'] ?? []);
            echo "   ✅ 聊天室載入成功，共 {$messageCount} 則訊息\n";
        }
        
        // 3.3 處理爭議決策
        echo "⚖️  3.3 處理爭議決策...\n";
        $resolveData = [
            'decision_result' => 'back_to_progress',
            'decision_note' => '經審查後，任務退回進行中狀態。測試時間: ' . date('Y-m-d H:i:s')
        ];
        
        $resolveResult = $this->makeRequest(
            'PATCH',
            "/admin/task-disputes/resolve.php?id={$this->testData['dispute_id']}",
            $resolveData,
            $this->adminToken
        );
        
        if ($resolveResult['success']) {
            echo "   ✅ 爭議決策完成\n";
            
            // 驗證狀態更新
            $this->verifyDisputeResolution();
        } else {
            echo "   ❌ 爭議決策失敗: " . ($resolveResult['message'] ?? '未知錯誤') . "\n";
        }
        
        echo "\n";
    }
    
    /**
     * 驗證任務狀態更新
     */
    private function verifyTaskStatusUpdate() {
        $stmt = $this->db->prepare("SELECT status_id FROM tasks WHERE id = ?");
        $stmt->execute([$this->testData['task_id']]);
        $status = $stmt->fetchColumn();
        
        if ($status == 4) { // 4 = dispute
            echo "   ✅ 任務狀態已更新為爭議中\n";
        } else {
            echo "   ⚠️  任務狀態未正確更新 (當前: {$status})\n";
        }
    }
    
    /**
     * 驗證爭議處理結果
     */
    private function verifyDisputeResolution() {
        $stmt = $this->db->prepare("SELECT status, decision_result FROM task_dispute_events WHERE id = ?");
        $stmt->execute([$this->testData['dispute_id']]);
        $dispute = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($dispute) {
            echo "   📊 爭議狀態: {$dispute['status']}\n";
            echo "   📊 決策結果: {$dispute['decision_result']}\n";
        }
    }
    
    /**
     * 發送 HTTP 請求
     */
    private function makeRequest($method, $endpoint, $data = null, $token = null) {
        $url = $this->baseUrl . $endpoint;
        $ch = curl_init();
        
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        
        $headers = ['Content-Type: application/json'];
        if ($token) {
            $headers[] = 'Authorization: Bearer ' . $token;
        }
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            if ($data) {
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            }
        } elseif ($method === 'PATCH') {
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
            if ($data) {
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            }
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        $result = json_decode($response, true);
        if (!$result) {
            throw new Exception("API 回應解析失敗: $response");
        }
        
        if ($httpCode >= 400) {
            echo "   ❌ HTTP {$httpCode}: " . ($result['message'] ?? '未知錯誤') . "\n";
        }
        
        return $result;
    }
    
    /**
     * 清理測試資料
     */
    private function cleanup() {
        echo "🧹 4. 清理測試資料\n";
        echo "-------------------\n";
        
        if (isset($this->testData['dispute_id'])) {
            // 注意: 在生產環境中不建議刪除爭議記錄
            // 這裡僅為測試目的
            echo "   ℹ️  保留測試爭議記錄 (ID: {$this->testData['dispute_id']}) 供檢查\n";
        }
        
        echo "   ✅ 清理完成\n\n";
    }
}

// 執行測試
try {
    $test = new DisputeE2ETest();
    $test->runFullTest();
} catch (Exception $e) {
    echo "💥 測試執行失敗: " . $e->getMessage() . "\n";
    exit(1);
}
?>
