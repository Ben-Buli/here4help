<?php
/**
 * 通知模板初始化腳本
 * 建立預設的通知模板和事件矩陣
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../database/database_manager.php';

try {
    $db = Database::getInstance()->getConnection();
    
    echo "🌱 開始初始化通知模板...\n";
    
    // 清理現有資料（開發環境用）
    if (isset($_GET['reset']) && $_GET['reset'] === 'true') {
        echo "🧹 清理現有通知模板資料...\n";
        $db->exec("DELETE FROM notification_events");
        $db->exec("DELETE FROM notification_templates");
        echo "✅ 清理完成\n\n";
    }
    
    // 插入通知模板
    $templates = [
        // 任務相關模板
        [
            'template_key' => 'task_created',
            'name' => '任務建立通知',
            'description' => '當新任務建立時通知相關使用者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => false,
            'title_template' => '新任務：{{task_title}}',
            'body_template' => '{{poster_name}} 發布了新任務「{{task_title}}」，報酬 {{reward}} 點數',
            'priority' => 'normal'
        ],
        [
            'template_key' => 'task_accepted',
            'name' => '任務接受通知',
            'description' => '當任務被接受時通知發布者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => false,
            'title_template' => '任務已被接受',
            'body_template' => '{{acceptor_name}} 接受了您的任務「{{task_title}}」',
            'priority' => 'high'
        ],
        [
            'template_key' => 'task_completed',
            'name' => '任務完成通知',
            'description' => '當任務完成時通知相關使用者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => true,
            'title_template' => '任務已完成',
            'body_template' => '任務「{{task_title}}」已完成，請確認並評價',
            'email_subject_template' => '任務完成通知 - {{task_title}}',
            'email_body_template' => '<h2>任務完成通知</h2><p>您的任務「{{task_title}}」已完成，請登入系統確認並評價。</p>',
            'priority' => 'high'
        ],
        [
            'template_key' => 'task_cancelled',
            'name' => '任務取消通知',
            'description' => '當任務被取消時通知相關使用者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => false,
            'title_template' => '任務已取消',
            'body_template' => '任務「{{task_title}}」已被取消',
            'priority' => 'normal'
        ],
        [
            'template_key' => 'task_dispute_created',
            'name' => '任務申訴通知',
            'description' => '當任務產生申訴時通知管理員',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => true,
            'title_template' => '任務申訴',
            'body_template' => '任務「{{task_title}}」產生申訴，需要管理員處理',
            'email_subject_template' => '任務申訴通知 - {{task_title}}',
            'email_body_template' => '<h2>任務申訴通知</h2><p>任務「{{task_title}}」產生申訴，請儘快處理。</p>',
            'priority' => 'urgent'
        ],
        
        // 聊天相關模板
        [
            'template_key' => 'chat_new_message',
            'name' => '新訊息通知',
            'description' => '當收到新聊天訊息時通知使用者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => false,
            'title_template' => '{{sender_name}} 傳送了訊息',
            'body_template' => '{{message_preview}}',
            'priority' => 'normal'
        ],
        
        // 客服相關模板
        [
            'template_key' => 'support_event_created',
            'name' => '客服事件建立通知',
            'description' => '當建立新客服事件時通知管理員',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => true,
            'title_template' => '新客服事件',
            'body_template' => '{{user_name}} 建立了客服事件：{{event_title}}',
            'email_subject_template' => '新客服事件 - {{event_title}}',
            'email_body_template' => '<h2>新客服事件</h2><p>使用者 {{user_name}} 建立了客服事件：{{event_title}}</p>',
            'priority' => 'high'
        ],
        [
            'template_key' => 'support_event_updated',
            'name' => '客服事件更新通知',
            'description' => '當客服事件狀態更新時通知使用者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => false,
            'title_template' => '客服事件更新',
            'body_template' => '您的客服事件「{{event_title}}」狀態已更新為：{{new_status}}',
            'priority' => 'normal'
        ],
        [
            'template_key' => 'support_event_resolved',
            'name' => '客服事件解決通知',
            'description' => '當客服事件解決時通知使用者',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => true,
            'title_template' => '客服事件已解決',
            'body_template' => '您的客服事件「{{event_title}}」已解決，請查看處理結果',
            'email_subject_template' => '客服事件已解決 - {{event_title}}',
            'email_body_template' => '<h2>客服事件已解決</h2><p>您的客服事件「{{event_title}}」已解決，請登入查看處理結果。</p>',
            'priority' => 'high'
        ],
        
        // 管理相關模板
        [
            'template_key' => 'admin_system_alert',
            'name' => '系統警示通知',
            'description' => '系統異常或重要事件警示',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => true,
            'title_template' => '系統警示：{{alert_type}}',
            'body_template' => '{{alert_message}}',
            'email_subject_template' => '系統警示 - {{alert_type}}',
            'email_body_template' => '<h2>系統警示</h2><p>{{alert_message}}</p>',
            'priority' => 'urgent'
        ],
        [
            'template_key' => 'admin_user_report',
            'name' => '使用者檢舉通知',
            'description' => '當有使用者檢舉時通知管理員',
            'supports_push' => true,
            'supports_in_app' => true,
            'supports_email' => true,
            'title_template' => '使用者檢舉',
            'body_template' => '{{reporter_name}} 檢舉了 {{reported_name}}，原因：{{report_reason}}',
            'email_subject_template' => '使用者檢舉通知',
            'email_body_template' => '<h2>使用者檢舉通知</h2><p>{{reporter_name}} 檢舉了 {{reported_name}}，原因：{{report_reason}}</p>',
            'priority' => 'high'
        ]
    ];
    
    $templateSql = "
        INSERT INTO notification_templates 
        (template_key, name, description, supports_push, supports_in_app, supports_email, supports_sms,
         title_template, body_template, email_subject_template, email_body_template, priority)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        description = VALUES(description),
        supports_push = VALUES(supports_push),
        supports_in_app = VALUES(supports_in_app),
        supports_email = VALUES(supports_email),
        title_template = VALUES(title_template),
        body_template = VALUES(body_template),
        email_subject_template = VALUES(email_subject_template),
        email_body_template = VALUES(email_body_template),
        priority = VALUES(priority),
        updated_at = CURRENT_TIMESTAMP
    ";
    
    $templateStmt = $db->prepare($templateSql);
    
    foreach ($templates as $template) {
        $templateStmt->execute([
            $template['template_key'],
            $template['name'],
            $template['description'],
            $template['supports_push'],
            $template['supports_in_app'],
            $template['supports_email'],
            $template['supports_sms'] ?? false,
            $template['title_template'],
            $template['body_template'],
            $template['email_subject_template'] ?? null,
            $template['email_body_template'] ?? null,
            $template['priority']
        ]);
        
        echo "✅ 模板建立: {$template['name']}\n";
    }
    
    // 插入通知事件矩陣
    $events = [
        // 任務事件
        [
            'event_type' => 'task',
            'event_action' => 'created',
            'template_key' => 'task_created',
            'target_roles' => json_encode(['all']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'task',
            'event_action' => 'accepted',
            'template_key' => 'task_accepted',
            'target_roles' => json_encode(['poster']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'task',
            'event_action' => 'completed',
            'template_key' => 'task_completed',
            'target_roles' => json_encode(['poster', 'acceptor']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'task',
            'event_action' => 'cancelled',
            'template_key' => 'task_cancelled',
            'target_roles' => json_encode(['poster', 'acceptor']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'task',
            'event_action' => 'dispute_created',
            'template_key' => 'task_dispute_created',
            'target_roles' => json_encode(['admin']),
            'delay_minutes' => 0
        ],
        
        // 聊天事件
        [
            'event_type' => 'chat',
            'event_action' => 'new_message',
            'template_key' => 'chat_new_message',
            'target_roles' => json_encode(['recipient']),
            'delay_minutes' => 0
        ],
        
        // 客服事件
        [
            'event_type' => 'support',
            'event_action' => 'created',
            'template_key' => 'support_event_created',
            'target_roles' => json_encode(['admin']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'support',
            'event_action' => 'updated',
            'template_key' => 'support_event_updated',
            'target_roles' => json_encode(['user']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'support',
            'event_action' => 'resolved',
            'template_key' => 'support_event_resolved',
            'target_roles' => json_encode(['user']),
            'delay_minutes' => 0
        ],
        
        // 管理事件
        [
            'event_type' => 'admin',
            'event_action' => 'system_alert',
            'template_key' => 'admin_system_alert',
            'target_roles' => json_encode(['admin']),
            'delay_minutes' => 0
        ],
        [
            'event_type' => 'admin',
            'event_action' => 'user_report',
            'template_key' => 'admin_user_report',
            'target_roles' => json_encode(['admin']),
            'delay_minutes' => 0
        ]
    ];
    
    $eventSql = "
        INSERT INTO notification_events 
        (event_type, event_action, template_key, target_roles, delay_minutes, max_retries)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        target_roles = VALUES(target_roles),
        delay_minutes = VALUES(delay_minutes),
        max_retries = VALUES(max_retries),
        updated_at = CURRENT_TIMESTAMP
    ";
    
    $eventStmt = $db->prepare($eventSql);
    
    foreach ($events as $event) {
        $eventStmt->execute([
            $event['event_type'],
            $event['event_action'],
            $event['template_key'],
            $event['target_roles'],
            $event['delay_minutes'],
            $event['max_retries'] ?? 3
        ]);
        
        echo "✅ 事件矩陣建立: {$event['event_type']}.{$event['event_action']} -> {$event['template_key']}\n";
    }
    
    echo "\n🎉 通知模板初始化完成！\n";
    echo "📊 建立了 " . count($templates) . " 個模板和 " . count($events) . " 個事件矩陣\n";
    
    // 顯示統計資訊
    $stats = $db->query("
        SELECT 
            (SELECT COUNT(*) FROM notification_templates WHERE is_active = 1) as active_templates,
            (SELECT COUNT(*) FROM notification_events WHERE is_active = 1) as active_events,
            (SELECT COUNT(*) FROM notification_templates WHERE supports_push = 1) as push_templates,
            (SELECT COUNT(*) FROM notification_templates WHERE supports_email = 1) as email_templates
    ")->fetch(PDO::FETCH_ASSOC);
    
    echo "\n📈 統計資訊:\n";
    echo "- 啟用模板: {$stats['active_templates']} 個\n";
    echo "- 啟用事件: {$stats['active_events']} 個\n";
    echo "- 支援推播: {$stats['push_templates']} 個\n";
    echo "- 支援Email: {$stats['email_templates']} 個\n";
    
} catch (Exception $e) {
    echo "❌ 初始化失敗: " . $e->getMessage() . "\n";
    echo "堆疊追蹤:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}
