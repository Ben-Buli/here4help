<?php
/**
 * 簡化的通知系統初始化腳本
 * 直接使用 EnvLoader 和 Database 類別
 */

require_once __DIR__ . '/../config/env_loader.php';

try {
    // 直接建立資料庫連接
    echo "envLoader: " . $envLoader . "\n";
    echo "dbConfig: " . $dbConfig . "\n";
    $envLoader = EnvLoader::getInstance();
    $dbConfig = $envLoader->getDatabaseConfig();
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']};charset=utf8mb4";
    echo "{$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']}  {$dbConfig['username']} {$dbConfig['password']}\n";
    $db = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    
    echo "🌱 開始初始化通知系統...\n";
    echo "=======================\n\n";
    
    // 檢查資料表是否存在
    echo "1. 檢查資料表結構\n";
    echo "-----------------\n";
    
    $tables = [
        'notification_templates',
        'notification_events', 
        'user_notification_preferences',
        'notification_queue',
        'in_app_notifications',
        'notification_stats'
    ];
    
    foreach ($tables as $table) {
        $sql = "SHOW TABLES LIKE '$table'";
        $result = $db->query($sql);
        
        if ($result->rowCount() > 0) {
            echo "✅ 資料表 $table 存在\n";
        } else {
            echo "❌ 資料表 $table 不存在，請先執行遷移腳本\n";
        }
    }
    
    // 檢查是否已有模板資料
    echo "\n2. 檢查現有資料\n";
    echo "---------------\n";
    
    try {
        $templateCount = $db->query("SELECT COUNT(*) FROM notification_templates")->fetchColumn();
        $eventCount = $db->query("SELECT COUNT(*) FROM notification_events")->fetchColumn();
        
        echo "現有模板數: $templateCount\n";
        echo "現有事件數: $eventCount\n";
        
        if ($templateCount > 0 && $eventCount > 0) {
            echo "✅ 通知系統已初始化\n";
            
            // 顯示模板列表
            echo "\n3. 現有模板列表\n";
            echo "---------------\n";
            
            $templates = $db->query("
                SELECT template_key, name, supports_push, supports_in_app, supports_email 
                FROM notification_templates 
                WHERE is_active = 1 
                ORDER BY template_key
            ")->fetchAll();
            
            foreach ($templates as $template) {
                $supports = [];
                if ($template['supports_push']) $supports[] = 'Push';
                if ($template['supports_in_app']) $supports[] = 'In-App';
                if ($template['supports_email']) $supports[] = 'Email';
                
                echo "- {$template['template_key']}: {$template['name']} (" . implode(', ', $supports) . ")\n";
            }
            
            // 顯示事件矩陣
            echo "\n4. 事件矩陣\n";
            echo "-----------\n";
            
            $events = $db->query("
                SELECT event_type, event_action, template_key, target_roles
                FROM notification_events 
                WHERE is_active = 1 
                ORDER BY event_type, event_action
            ")->fetchAll();
            
            foreach ($events as $event) {
                $roles = json_decode($event['target_roles'], true);
                echo "- {$event['event_type']}.{$event['event_action']} -> {$event['template_key']} (目標: " . implode(', ', $roles) . ")\n";
            }
            
        } else {
            echo "⚠️  通知系統尚未初始化，需要手動建立模板和事件\n";
            echo "\n建議執行以下 SQL 來建立基本模板:\n";
            echo "INSERT INTO notification_templates (template_key, name, title_template, body_template) VALUES\n";
            echo "('task_created', '任務建立通知', '新任務：{{task_title}}', '{{poster_name}} 發布了新任務'),\n";
            echo "('chat_new_message', '新訊息通知', '{{sender_name}} 傳送了訊息', '{{message_preview}}');\n";
        }
        
    } catch (Exception $e) {
        echo "❌ 資料表查詢失敗: " . $e->getMessage() . "\n";
        echo "可能是資料表尚未建立，請先執行遷移腳本\n";
    }
    
    echo "\n🎉 通知系統檢查完成！\n";
    
} catch (Exception $e) {
    echo "❌ 初始化失敗: " . $e->getMessage() . "\n";
    exit(1);
}
