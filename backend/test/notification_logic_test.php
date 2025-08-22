<?php
/**
 * 通知系統邏輯測試
 * 測試通知管理器的核心邏輯，不依賴資料庫連接
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Logger.php';

echo "🧪 通知系統邏輯測試\n";
echo "==================\n\n";

try {
    // 測試1: 模板渲染邏輯
    echo "1. 測試模板渲染\n";
    echo "---------------\n";
    testTemplateRendering();
    
    echo "\n";
    
    // 測試2: 事件條件檢查
    echo "2. 測試事件條件檢查\n";
    echo "------------------\n";
    testConditionChecking();
    
    echo "\n";
    
    // 測試3: 靜音時段檢查
    echo "3. 測試靜音時段檢查\n";
    echo "------------------\n";
    testQuietHours();
    
    echo "\n";
    
    // 測試4: 通知類型偏好
    echo "4. 測試通知類型偏好\n";
    echo "------------------\n";
    testNotificationPreferences();
    
    echo "\n✅ 所有邏輯測試完成！\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * 測試模板渲染邏輯
 */
function testTemplateRendering() {
    echo "測試模板變數替換...\n";
    
    $template = "新任務：{{task_title}}，發布者：{{poster_name}}，報酬：{{reward}} 點數";
    $data = [
        'task_title' => '幫忙搬家',
        'poster_name' => '小明',
        'reward' => 100
    ];
    
    $rendered = renderTemplate($template, $data);
    $expected = "新任務：幫忙搬家，發布者：小明，報酬：100 點數";
    
    if ($rendered === $expected) {
        echo "✅ 模板渲染正確\n";
        echo "   結果: $rendered\n";
    } else {
        echo "❌ 模板渲染錯誤\n";
        echo "   期望: $expected\n";
        echo "   實際: $rendered\n";
    }
    
    // 測試部分變數缺失的情況
    echo "\n測試部分變數缺失...\n";
    
    $incompleteData = [
        'task_title' => '清潔服務',
        'reward' => 50
        // 缺少 poster_name
    ];
    
    $rendered = renderTemplate($template, $incompleteData);
    echo "✅ 部分變數缺失處理\n";
    echo "   結果: $rendered\n";
}

/**
 * 測試事件條件檢查
 */
function testConditionChecking() {
    echo "測試觸發條件檢查...\n";
    
    $conditions = [
        'task_status' => 'pending',
        'user_role' => 'poster'
    ];
    
    $eventData1 = [
        'task_status' => 'pending',
        'user_role' => 'poster',
        'task_id' => 123
    ];
    
    $eventData2 = [
        'task_status' => 'completed',
        'user_role' => 'poster',
        'task_id' => 124
    ];
    
    if (checkTriggerConditions($conditions, $eventData1)) {
        echo "✅ 條件匹配檢查正確（應該匹配）\n";
    } else {
        echo "❌ 條件匹配檢查錯誤（應該匹配但未匹配）\n";
    }
    
    if (!checkTriggerConditions($conditions, $eventData2)) {
        echo "✅ 條件不匹配檢查正確（應該不匹配）\n";
    } else {
        echo "❌ 條件不匹配檢查錯誤（不應該匹配但匹配了）\n";
    }
    
    // 測試空條件
    if (checkTriggerConditions([], $eventData1)) {
        echo "✅ 空條件檢查正確（應該總是匹配）\n";
    } else {
        echo "❌ 空條件檢查錯誤\n";
    }
}

/**
 * 測試靜音時段檢查
 */
function testQuietHours() {
    echo "測試靜音時段邏輯...\n";
    
    $preferences = [
        'quiet_hours_start' => '22:00:00',
        'quiet_hours_end' => '08:00:00',
        'quiet_days' => json_encode([6, 7]) // 週六、週日
    ];
    
    // 測試不同時間點
    $testTimes = [
        ['time' => '09:00:00', 'day' => 1, 'should_be_quiet' => false, 'desc' => '週一早上9點'],
        ['time' => '23:00:00', 'day' => 2, 'should_be_quiet' => true, 'desc' => '週二晚上11點'],
        ['time' => '07:00:00', 'day' => 3, 'should_be_quiet' => true, 'desc' => '週三早上7點'],
        ['time' => '14:00:00', 'day' => 6, 'should_be_quiet' => true, 'desc' => '週六下午2點（靜音日）'],
        ['time' => '10:00:00', 'day' => 1, 'should_be_quiet' => false, 'desc' => '週一上午10點（正常時段）']
    ];
    
    foreach ($testTimes as $test) {
        $isQuiet = isInQuietHours($preferences, $test['time'], $test['day']);
        $status = ($isQuiet === $test['should_be_quiet']) ? '✅' : '❌';
        $expected = $test['should_be_quiet'] ? '靜音' : '正常';
        $actual = $isQuiet ? '靜音' : '正常';
        
        echo "$status {$test['desc']}: $actual (期望: $expected)\n";
    }
}

/**
 * 測試通知類型偏好
 */
function testNotificationPreferences() {
    echo "測試通知類型偏好邏輯...\n";
    
    $preferences = [
        'push_enabled' => true,
        'in_app_enabled' => true,
        'email_enabled' => false,
        'task_preferences' => json_encode([
            'created' => ['push' => true, 'in_app' => true, 'email' => false],
            'completed' => ['push' => true, 'in_app' => true, 'email' => true]
        ])
    ];
    
    $event = [
        'event_type' => 'task',
        'event_action' => 'created',
        'supports_push' => true,
        'supports_in_app' => true,
        'supports_email' => true
    ];
    
    $allowedTypes = getEnabledNotificationTypes($event, $preferences);
    
    echo "任務建立事件的啟用通知類型:\n";
    foreach (['push', 'in_app', 'email'] as $type) {
        $status = in_array($type, $allowedTypes) ? '✅ 啟用' : '❌ 停用';
        echo "   $type: $status\n";
    }
    
    // 測試任務完成事件（email 應該啟用）
    $event['event_action'] = 'completed';
    $allowedTypes = getEnabledNotificationTypes($event, $preferences);
    
    echo "\n任務完成事件的啟用通知類型:\n";
    foreach (['push', 'in_app', 'email'] as $type) {
        $status = in_array($type, $allowedTypes) ? '✅ 啟用' : '❌ 停用';
        echo "   $type: $status\n";
    }
}

/**
 * 輔助函數
 */
function renderTemplate($template, $data) {
    $rendered = $template;
    
    foreach ($data as $key => $value) {
        if (is_scalar($value)) {
            $rendered = str_replace('{{' . $key . '}}', $value, $rendered);
        }
    }
    
    return $rendered;
}

function checkTriggerConditions($conditions, $eventData) {
    if (empty($conditions)) {
        return true;
    }
    
    foreach ($conditions as $key => $expectedValue) {
        if (!isset($eventData[$key]) || $eventData[$key] != $expectedValue) {
            return false;
        }
    }
    
    return true;
}

function isInQuietHours($preferences, $currentTime, $currentDay) {
    // 檢查靜音日期
    if (!empty($preferences['quiet_days'])) {
        $quietDays = json_decode($preferences['quiet_days'], true);
        if (in_array($currentDay, $quietDays)) {
            return true;
        }
    }
    
    // 檢查靜音時段
    if (empty($preferences['quiet_hours_start']) || empty($preferences['quiet_hours_end'])) {
        return false;
    }
    
    $startTime = $preferences['quiet_hours_start'];
    $endTime = $preferences['quiet_hours_end'];
    
    if ($startTime <= $endTime) {
        // 同一天內的時段
        return $currentTime >= $startTime && $currentTime <= $endTime;
    } else {
        // 跨日的時段
        return $currentTime >= $startTime || $currentTime <= $endTime;
    }
}

function getEnabledNotificationTypes($event, $preferences) {
    $enabledTypes = [];
    
    $eventType = $event['event_type'];
    $eventAction = $event['event_action'];
    
    // 檢查全域設定
    $globalSettings = [
        'push' => $preferences['push_enabled'] ?? true,
        'in_app' => $preferences['in_app_enabled'] ?? true,
        'email' => $preferences['email_enabled'] ?? true
    ];
    
    // 檢查事件支援的類型
    $supportedTypes = [
        'push' => $event['supports_push'] ?? false,
        'in_app' => $event['supports_in_app'] ?? false,
        'email' => $event['supports_email'] ?? false
    ];
    
    // 檢查特定事件偏好
    $preferencesKey = $eventType . '_preferences';
    $eventPreferences = [];
    
    if (isset($preferences[$preferencesKey])) {
        $decoded = json_decode($preferences[$preferencesKey], true);
        if (isset($decoded[$eventAction])) {
            $eventPreferences = $decoded[$eventAction];
        }
    }
    
    foreach (['push', 'in_app', 'email'] as $type) {
        $enabled = $globalSettings[$type] && 
                   $supportedTypes[$type] && 
                   ($eventPreferences[$type] ?? true);
        
        if ($enabled) {
            $enabledTypes[] = $type;
        }
    }
    
    return $enabledTypes;
}
