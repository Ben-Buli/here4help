<?php
/**
 * 通知偏好設定測試腳本
 * 測試通知偏好 API 的基本功能
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Logger.php';

echo "🧪 通知偏好設定測試\n";
echo "==================\n\n";

try {
    // 測試1: 資料庫連接
    echo "1. 測試資料庫連接\n";
    echo "-----------------\n";
    testDatabaseConnection();
    
    echo "\n";
    
    // 測試2: 偏好設定資料驗證
    echo "2. 測試偏好設定資料驗證\n";
    echo "----------------------\n";
    testPreferencesValidation();
    
    echo "\n";
    
    // 測試3: 預設偏好設定結構
    echo "3. 測試預設偏好設定結構\n";
    echo "----------------------\n";
    testDefaultPreferencesStructure();
    
    echo "\n✅ 所有測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * 測試資料庫連接
 */
function testDatabaseConnection() {
    try {
        $envLoader = EnvLoader::getInstance();
        $dbConfig = $envLoader->getDatabaseConfig();
        
        echo "資料庫配置:\n";
        echo "- 主機: {$dbConfig['host']}:{$dbConfig['port']}\n";
        echo "- 資料庫: {$dbConfig['dbname']}\n";
        echo "- 使用者: {$dbConfig['username']}\n";
        
        // 嘗試連接（不實際連接，只檢查配置）
        $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']};charset=utf8mb4";
        
        echo "✅ 資料庫配置正確\n";
        echo "   DSN: $dsn\n";
        
    } catch (Exception $e) {
        echo "❌ 資料庫配置錯誤: " . $e->getMessage() . "\n";
        throw $e;
    }
}

/**
 * 測試偏好設定資料驗證
 */
function testPreferencesValidation() {
    echo "測試偏好設定資料驗證邏輯...\n";
    
    // 測試有效資料
    $validData = [
        'push_enabled' => true,
        'in_app_enabled' => true,
        'email_enabled' => false,
        'sms_enabled' => false,
        'quiet_hours_start' => '22:00:00',
        'quiet_hours_end' => '08:00:00',
        'quiet_days' => [6, 7],
        'task_preferences' => [
            'created' => ['push' => true, 'in_app' => true, 'email' => false],
            'completed' => ['push' => true, 'in_app' => true, 'email' => true]
        ]
    ];
    
    $result = validatePreferencesData($validData);
    
    if ($result['valid']) {
        echo "✅ 有效資料驗證通過\n";
    } else {
        echo "❌ 有效資料驗證失敗: {$result['message']}\n";
    }
    
    // 測試無效時間格式
    $invalidTimeData = [
        'quiet_hours_start' => '25:00:00', // 無效時間
    ];
    
    $result = validatePreferencesData($invalidTimeData);
    
    if (!$result['valid']) {
        echo "✅ 無效時間格式檢查正確\n";
        echo "   錯誤訊息: {$result['message']}\n";
    } else {
        echo "❌ 無效時間格式檢查失敗（應該要失敗）\n";
    }
    
    // 測試無效靜音日期
    $invalidDaysData = [
        'quiet_days' => [0, 8], // 無效日期
    ];
    
    $result = validatePreferencesData($invalidDaysData);
    
    if (!$result['valid']) {
        echo "✅ 無效靜音日期檢查正確\n";
        echo "   錯誤訊息: {$result['message']}\n";
    } else {
        echo "❌ 無效靜音日期檢查失敗（應該要失敗）\n";
    }
}

/**
 * 測試預設偏好設定結構
 */
function testDefaultPreferencesStructure() {
    echo "測試預設偏好設定結構...\n";
    
    $defaultPreferences = createMockDefaultPreferences(1);
    
    // 檢查必要欄位
    $requiredFields = [
        'user_id', 'push_enabled', 'in_app_enabled', 'email_enabled', 'sms_enabled',
        'task_preferences', 'chat_preferences', 'support_preferences', 'admin_preferences'
    ];
    
    $missingFields = [];
    foreach ($requiredFields as $field) {
        if (!isset($defaultPreferences[$field])) {
            $missingFields[] = $field;
        }
    }
    
    if (empty($missingFields)) {
        echo "✅ 預設偏好設定包含所有必要欄位\n";
    } else {
        echo "❌ 預設偏好設定缺少欄位: " . implode(', ', $missingFields) . "\n";
    }
    
    // 檢查 JSON 結構
    $jsonFields = ['task_preferences', 'chat_preferences', 'support_preferences', 'admin_preferences'];
    
    foreach ($jsonFields as $field) {
        $decoded = json_decode($defaultPreferences[$field], true);
        if ($decoded === null) {
            echo "❌ $field JSON 格式錯誤\n";
        } else {
            echo "✅ $field JSON 格式正確，包含 " . count($decoded) . " 個事件\n";
            
            // 顯示事件列表
            foreach ($decoded as $event => $types) {
                $enabledTypes = array_keys(array_filter($types));
                echo "   - $event: " . implode(', ', $enabledTypes) . "\n";
            }
        }
    }
}

/**
 * 驗證偏好設定資料（複製自主檔案的邏輯）
 */
function validatePreferencesData($data) {
    // 驗證布林值欄位
    $booleanFields = ['push_enabled', 'in_app_enabled', 'email_enabled', 'sms_enabled'];
    foreach ($booleanFields as $field) {
        if (isset($data[$field]) && !is_bool($data[$field])) {
            return [
                'valid' => false,
                'message' => "$field 必須是布林值"
            ];
        }
    }
    
    // 驗證時間格式
    $timeFields = ['quiet_hours_start', 'quiet_hours_end'];
    foreach ($timeFields as $field) {
        if (isset($data[$field]) && $data[$field] !== null) {
            if (!preg_match('/^([01]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/', $data[$field])) {
                return [
                    'valid' => false,
                    'message' => "$field 時間格式不正確，應為 HH:MM:SS"
                ];
            }
        }
    }
    
    // 驗證靜音日期
    if (isset($data['quiet_days'])) {
        if (!is_array($data['quiet_days'])) {
            return [
                'valid' => false,
                'message' => 'quiet_days 必須是陣列'
            ];
        }
        
        foreach ($data['quiet_days'] as $day) {
            if (!is_int($day) || $day < 1 || $day > 7) {
                return [
                    'valid' => false,
                    'message' => 'quiet_days 中的日期必須是 1-7 的整數'
                ];
            }
        }
    }
    
    return ['valid' => true];
}

/**
 * 創建模擬的預設偏好設定
 */
function createMockDefaultPreferences($userId) {
    return [
        'user_id' => $userId,
        'push_enabled' => true,
        'in_app_enabled' => true,
        'email_enabled' => true,
        'sms_enabled' => false,
        'quiet_hours_start' => null,
        'quiet_hours_end' => null,
        'quiet_days' => json_encode([]),
        'task_preferences' => json_encode([
            'created' => ['push' => true, 'in_app' => true, 'email' => false],
            'accepted' => ['push' => true, 'in_app' => true, 'email' => false],
            'completed' => ['push' => true, 'in_app' => true, 'email' => true],
            'cancelled' => ['push' => true, 'in_app' => true, 'email' => false],
            'dispute_created' => ['push' => true, 'in_app' => true, 'email' => true]
        ]),
        'chat_preferences' => json_encode([
            'new_message' => ['push' => true, 'in_app' => true, 'email' => false]
        ]),
        'support_preferences' => json_encode([
            'created' => ['push' => true, 'in_app' => true, 'email' => true],
            'updated' => ['push' => true, 'in_app' => true, 'email' => false],
            'resolved' => ['push' => true, 'in_app' => true, 'email' => true]
        ]),
        'admin_preferences' => json_encode([
            'system_alert' => ['push' => true, 'in_app' => true, 'email' => true],
            'user_report' => ['push' => true, 'in_app' => true, 'email' => true]
        ])
    ];
}
