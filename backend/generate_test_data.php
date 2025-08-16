<?php
/**
 * 測試資料生成腳本
 * 為 users.id = 2 的使用者生成完整的測試資料
 */

require_once 'config/database.php';

try {
    $db = Database::getInstance();
    
    echo "🚀 開始生成測試資料...\n";
    
    // 1. 檢查並創建 users.id = 2 的使用者
    echo "📝 檢查使用者資料...\n";
    $user = $db->fetch("SELECT * FROM users WHERE id = 2");
    
    if (!$user) {
        echo "❌ 使用者 id = 2 不存在，創建中...\n";
        $db->query(
            "INSERT INTO users (id, name, email, password, avatar_url, created_at, updated_at) 
             VALUES (2, 'Test User', 'test@example.com', 'hashed_password', 'assets/images/avatar/avatar-2.png', NOW(), NOW())"
        );
        echo "✅ 使用者創建成功\n";
    } else {
        echo "✅ 使用者已存在: {$user['name']}\n";
    }
    
    // 2. 檢查並創建任務狀態
    echo "📊 檢查任務狀態...\n";
    $statuses = $db->fetchAll("SELECT * FROM task_statuses");
    if (empty($statuses)) {
        echo "❌ 任務狀態表為空，創建預設狀態...\n";
        $db->query("INSERT INTO task_statuses (id, name, display_name, color, created_at) VALUES (1, 'open', 'Open', '#28a745', NOW())");
        $db->query("INSERT INTO task_statuses (id, name, display_name, color, created_at) VALUES (2, 'in_progress', 'In Progress', '#ffc107', NOW())");
        $db->query("INSERT INTO task_statuses (id, name, display_name, color, created_at) VALUES (3, 'completed', 'Completed', '#17a2b8', NOW())");
        $db->query("INSERT INTO task_statuses (id, name, display_name, color, created_at) VALUES (4, 'cancelled', 'Cancelled', '#dc3545', NOW())");
        echo "✅ 任務狀態創建成功\n";
    } else {
        echo "✅ 任務狀態已存在\n";
    }
    
    // 3. 創建其他使用者（用於任務創建和應徵）
    echo "👥 創建其他使用者...\n";
    $otherUsers = [
        ['id' => 1, 'name' => 'Task Creator', 'email' => 'creator@example.com'],
        ['id' => 3, 'name' => 'Another User', 'email' => 'another@example.com'],
        ['id' => 4, 'name' => 'Helper User', 'email' => 'helper@example.com'],
    ];
    
    foreach ($otherUsers as $userData) {
        $existing = $db->fetch("SELECT id FROM users WHERE id = ?", [$userData['id']]);
        if (!$existing) {
            $db->query(
                "INSERT INTO users (id, name, email, password, avatar_url, created_at, updated_at) 
                 VALUES (?, ?, ?, 'hashed_password', 'assets/images/avatar/avatar-{$userData['id']}.png', NOW(), NOW())",
                [$userData['id'], $userData['name'], $userData['email']]
            );
            echo "✅ 使用者 {$userData['name']} 創建成功\n";
        }
    }
    
    // 4. 創建任務（由其他使用者發布，供 users.id = 2 應徵）
    echo "📋 創建任務...\n";
    $tasks = [
        [
            'id' => 'task-001',
            'title' => '網站設計開發',
            'description' => '需要一個現代化的企業網站設計和開發',
            'reward_point' => '5000',
            'location' => '台北市',
            'task_date' => '2025-01-20',
            'language_requirement' => '中文',
            'creator_id' => 1,
            'status_id' => 1
        ],
        [
            'id' => 'task-002', 
            'title' => '手機 App 開發',
            'description' => '開發一個社交媒體手機應用程式',
            'reward_point' => '8000',
            'location' => '新北市',
            'task_date' => '2025-01-25',
            'language_requirement' => '中文',
            'creator_id' => 3,
            'status_id' => 1
        ],
        [
            'id' => 'task-003',
            'title' => '資料庫優化',
            'description' => '優化現有資料庫結構和查詢效能',
            'reward_point' => '3000',
            'location' => '台中市',
            'task_date' => '2025-01-30',
            'language_requirement' => '中文',
            'creator_id' => 4,
            'status_id' => 1
        ]
    ];
    
    foreach ($tasks as $taskData) {
        $existing = $db->fetch("SELECT id FROM tasks WHERE id = ?", [$taskData['id']]);
        if (!$existing) {
            $db->query(
                "INSERT INTO tasks (id, title, description, reward_point, location, task_date, language_requirement, creator_id, status_id, created_at, updated_at) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                [$taskData['id'], $taskData['title'], $taskData['description'], $taskData['reward_point'], $taskData['location'], $taskData['task_date'], $taskData['language_requirement'], $taskData['creator_id'], $taskData['status_id']]
            );
            echo "✅ 任務 '{$taskData['title']}' 創建成功\n";
        }
    }
    
    // 5. 創建任務（由 users.id = 2 發布）
    echo "📋 創建由使用者 2 發布的任務...\n";
    $myTasks = [
        [
            'id' => 'my-task-001',
            'title' => 'Logo 設計',
            'description' => '為我的公司設計一個專業的 Logo',
            'reward_point' => '2000',
            'location' => '台北市',
            'task_date' => '2025-02-01',
            'language_requirement' => '中文',
            'creator_id' => 2,
            'status_id' => 1
        ],
        [
            'id' => 'my-task-002',
            'title' => '行銷文案撰寫',
            'description' => '撰寫產品行銷文案和宣傳材料',
            'reward_point' => '1500',
            'location' => '新北市',
            'task_date' => '2025-02-05',
            'language_requirement' => '中文',
            'creator_id' => 2,
            'status_id' => 2
        ]
    ];
    
    foreach ($myTasks as $taskData) {
        $existing = $db->fetch("SELECT id FROM tasks WHERE id = ?", [$taskData['id']]);
        if (!$existing) {
            $db->query(
                "INSERT INTO tasks (id, title, description, reward_point, location, task_date, language_requirement, creator_id, status_id, created_at, updated_at) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                [$taskData['id'], $taskData['title'], $taskData['description'], $taskData['reward_point'], $taskData['location'], $taskData['task_date'], $taskData['language_requirement'], $taskData['creator_id'], $taskData['status_id']]
            );
            echo "✅ 我的任務 '{$taskData['title']}' 創建成功\n";
        }
    }
    
    // 6. 創建應徵記錄（users.id = 2 應徵其他任務）
    echo "📝 創建應徵記錄...\n";
    $applications = [
        [
            'task_id' => 'task-001',
            'user_id' => 2,
            'cover_letter' => '我是一名經驗豐富的網站設計師，有5年的設計和開發經驗。我擅長使用現代化的設計工具和技術，能夠創建美觀且功能完整的網站。我相信我可以為您的企業網站提供最佳的設計方案。',
            'answers_json' => '{"您有相關的設計作品集嗎？": "是的，我有完整的作品集，包含企業網站、電商平台和個人部落格等項目。", "您預計完成時間是多久？": "根據需求複雜度，預計2-3週可以完成設計和開發。", "您使用哪些設計工具？": "我主要使用 Figma、Adobe XD 進行設計，使用 React、Vue.js 進行前端開發。"}',
            'status' => 'applied'
        ],
        [
            'task_id' => 'task-002',
            'user_id' => 2,
            'cover_letter' => '我是一名全端開發工程師，專精於手機應用程式開發。我有豐富的 React Native 和 Flutter 開發經驗，能夠開發跨平台的社交媒體應用程式。我注重用戶體驗和程式碼品質。',
            'answers_json' => '{"您有開發過類似的社交媒體 App 嗎？": "是的，我開發過多個社交媒體相關的應用程式，包括聊天、分享和社群功能。", "您預計開發週期是多久？": "根據功能複雜度，預計6-8週可以完成開發和測試。", "您如何確保 App 的效能？": "我會使用效能分析工具，優化圖片載入、網路請求和記憶體使用。"}',
            'status' => 'applied'
        ]
    ];
    
    foreach ($applications as $appData) {
        $existing = $db->fetch("SELECT id FROM task_applications WHERE task_id = ? AND user_id = ?", [$appData['task_id'], $appData['user_id']]);
        if (!$existing) {
            $db->query(
                "INSERT INTO task_applications (task_id, user_id, status, cover_letter, answers_json, created_at, updated_at) 
                 VALUES (?, ?, ?, ?, ?, NOW(), NOW())",
                [$appData['task_id'], $appData['user_id'], $appData['status'], $appData['cover_letter'], $appData['answers_json']]
            );
            echo "✅ 應徵記錄創建成功 (任務: {$appData['task_id']})\n";
        }
    }
    
    // 7. 創建聊天室
    echo "💬 創建聊天室...\n";
    $chatRooms = [
        [
            'task_id' => 'task-001',
            'creator_id' => 1,
            'participant_id' => 2,
            'type' => 'application'
        ],
        [
            'task_id' => 'task-002',
            'creator_id' => 3,
            'participant_id' => 2,
            'type' => 'application'
        ]
    ];
    
    foreach ($chatRooms as $roomData) {
        $existing = $db->fetch("SELECT id FROM chat_rooms WHERE task_id = ? AND creator_id = ? AND participant_id = ?", 
            [$roomData['task_id'], $roomData['creator_id'], $roomData['participant_id']]);
        if (!$existing) {
            $db->query(
                "INSERT INTO chat_rooms (task_id, creator_id, participant_id, type, created_at) 
                 VALUES (?, ?, ?, ?, NOW())",
                [$roomData['task_id'], $roomData['creator_id'], $roomData['participant_id'], $roomData['type']]
            );
            $roomId = $db->lastInsertId();
            echo "✅ 聊天室創建成功 (ID: {$roomId})\n";
            
            // 8. 創建應徵訊息（作為聊天室的第一條訊息）
            // 找到對應的應徵記錄
            $application = $db->fetch("SELECT * FROM task_applications WHERE task_id = ? AND user_id = ?", 
                [$roomData['task_id'], $roomData['participant_id']]);
            
            if ($application) {
                $messageContent = $application['cover_letter'];
                if (!empty($application['answers_json'])) {
                    $answers = json_decode($application['answers_json'], true);
                    if ($answers) {
                        $messageContent .= "\n\n應徵者回答：\n";
                        foreach ($answers as $question => $answer) {
                            $messageContent .= "• {$question}: {$answer}\n";
                        }
                    }
                }
                
                $db->query(
                    "INSERT INTO chat_messages (room_id, from_user_id, content, created_at) 
                     VALUES (?, ?, ?, NOW())",
                    [$roomId, $application['user_id'], $messageContent]
                );
                echo "✅ 應徵訊息創建成功\n";
                
                // 注意：task_applications 表可能沒有 room_id 欄位
                // 如果需要關聯，可以通過 task_id 和 user_id 來查詢對應的聊天室
                echo "ℹ️  應徵記錄 ID {$application['id']} 與聊天室 ID {$roomId} 關聯成功\n";
            }
            
            // 移除重複的代碼，這裡不需要額外的插入
        }
    }
    
    // 9. 創建一些普通聊天訊息
    echo "💬 創建普通聊天訊息...\n";
    $rooms = $db->fetchAll("SELECT id FROM chat_rooms");
    foreach ($rooms as $room) {
        $roomId = $room['id'];
        
        // 創建幾條測試訊息
        $messages = [
            ['from_user_id' => 2, 'message' => '您好！我對這個任務很感興趣，請問還有其他細節嗎？'],
            ['from_user_id' => 1, 'message' => '謝謝您的應徵！我們可以詳細討論一下需求。'],
            ['from_user_id' => 2, 'message' => '好的，我隨時可以開始工作。'],
        ];
        
        foreach ($messages as $msgData) {
            $db->query(
                "INSERT INTO chat_messages (room_id, from_user_id, content, created_at) 
                 VALUES (?, ?, ?, NOW())",
                [$roomId, $msgData['from_user_id'], $msgData['message']]
            );
        }
        echo "✅ 聊天訊息創建成功 (聊天室 ID: {$roomId})\n";
    }
    
    echo "\n🎉 測試資料生成完成！\n";
    echo "\n📊 資料摘要：\n";
    echo "- 使用者數量: " . $db->fetch("SELECT COUNT(*) as count FROM users")['count'] . "\n";
    echo "- 任務數量: " . $db->fetch("SELECT COUNT(*) as count FROM tasks")['count'] . "\n";
    echo "- 應徵記錄: " . $db->fetch("SELECT COUNT(*) as count FROM task_applications")['count'] . "\n";
    echo "- 聊天室: " . $db->fetch("SELECT COUNT(*) as count FROM chat_rooms")['count'] . "\n";
    echo "- 聊天訊息: " . $db->fetch("SELECT COUNT(*) as count FROM chat_messages")['count'] . "\n";
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    echo "堆疊追蹤: " . $e->getTraceAsString() . "\n";
}
?> 