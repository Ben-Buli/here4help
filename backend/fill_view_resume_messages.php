<?php
/**
 * 填充 View Resume 訊息腳本
 * 將現有的 task_applications 資料轉換為 chat_messages 中的 applyMessage 類型訊息
 */

require_once 'config/database.php';

try {
    $db = Database::getInstance();
    
    echo "🔧 開始填充 View Resume 訊息...\n\n";
    
    // 1. 首先修改 chat_messages 表的 kind 欄位
    echo "📝 修改 chat_messages 表結構...\n";
    try {
        $db->query("ALTER TABLE chat_messages MODIFY COLUMN kind ENUM('user', 'system', 'applyMessage') DEFAULT 'user'");
        echo "✅ chat_messages 表結構修改成功\n";
    } catch (Exception $e) {
        echo "ℹ️  chat_messages 表結構已存在或無需修改: " . $e->getMessage() . "\n";
    }
    
    // 2. 獲取所有需要填充的應徵記錄
    echo "\n📋 獲取應徵記錄...\n";
    $applications = $db->fetchAll("
        SELECT 
            ta.id,
            ta.task_id,
            ta.user_id,
            ta.cover_letter,
            ta.answers_json,
            ta.created_at,
            cr.id as room_id
        FROM task_applications ta
        LEFT JOIN chat_rooms cr ON ta.task_id = cr.task_id 
            AND (ta.user_id = cr.creator_id OR ta.user_id = cr.participant_id)
        WHERE ta.status = 'applied'
        ORDER BY ta.created_at
    ");
    
    echo "找到 " . count($applications) . " 條應徵記錄\n";
    
    // 3. 為每條應徵記錄創建 View Resume 訊息
    $insertedCount = 0;
    $updatedCount = 0;
    
    foreach ($applications as $app) {
        if (!$app['room_id']) {
            echo "⚠️  應徵記錄 ID {$app['id']} 沒有對應的聊天室，跳過\n";
            continue;
        }
        
        // 檢查是否已經存在 applyMessage 類型的訊息
        $existingMessage = $db->fetch("
            SELECT id FROM chat_messages 
            WHERE room_id = ? AND kind = 'applyMessage' AND from_user_id = ?
        ", [$app['room_id'], $app['user_id']]);
        
        if ($existingMessage) {
            echo "ℹ️  聊天室 {$app['room_id']} 已存在 applyMessage，跳過\n";
            continue;
        }
        
        // 構建 View Resume 訊息內容
        $messageContent = $app['cover_letter'] ?? '';
        
        if (!empty($app['answers_json'])) {
            try {
                $answers = json_decode($app['answers_json'], true);
                if ($answers && is_array($answers)) {
                    $messageContent .= "\n\n應徵者回答：\n";
                    foreach ($answers as $question => $answer) {
                        $messageContent .= "• {$question}: {$answer}\n";
                    }
                }
            } catch (Exception $e) {
                echo "⚠️  解析 answers_json 失敗: " . $e->getMessage() . "\n";
            }
        }
        
        if (empty(trim($messageContent))) {
            echo "⚠️  應徵記錄 ID {$app['id']} 沒有內容，跳過\n";
            continue;
        }
        
        // 插入 View Resume 訊息
        try {
            $db->query("
                INSERT INTO chat_messages (
                    room_id, 
                    from_user_id, 
                    sender_id,
                    kind, 
                    content, 
                    message,
                    created_at
                ) VALUES (?, ?, ?, 'applyMessage', ?, ?, '2025-08-01 00:00:00')
            ", [
                $app['room_id'],
                $app['user_id'],
                $app['user_id'],
                $messageContent,
                $messageContent
            ]);
            
            $insertedCount++;
            echo "✅ 聊天室 {$app['room_id']} 的 View Resume 訊息創建成功\n";
            
        } catch (Exception $e) {
            echo "❌ 插入失敗: " . $e->getMessage() . "\n";
        }
    }
    
    echo "\n🎉 View Resume 訊息填充完成！\n";
    echo "📊 統計：\n";
    echo "- 新增訊息數量: {$insertedCount}\n";
    echo "- 跳過數量: " . (count($applications) - $insertedCount) . "\n";
    
    // 4. 驗證結果
    echo "\n🔍 驗證結果...\n";
    $totalMessages = $db->fetch("SELECT COUNT(*) as count FROM chat_messages")['count'];
    $applyMessages = $db->fetch("SELECT COUNT(*) as count FROM chat_messages WHERE kind = 'applyMessage'")['count'];
    
    echo "- 總訊息數量: {$totalMessages}\n";
    echo "- applyMessage 數量: {$applyMessages}\n";
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    echo "堆疊追蹤: " . $e->getTraceAsString() . "\n";
}
?> 