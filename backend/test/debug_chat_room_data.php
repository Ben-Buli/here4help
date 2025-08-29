<?php
/**
 * 聊天室數據結構偵錯腳本
 * 用於檢查聊天室數據的結構，幫助診斷 accept 功能的問題
 */

// 設置錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

// 數據庫連接配置
$host = 'localhost';
$port = 8889;
$dbname = 'here4help';
$username = 'root';
$password = 'root';

try {
    // 使用 Unix socket 連接 MAMP MySQL
    $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "✅ 數據庫連接成功\n";
    
    // 查詢聊天室數據
    echo "\n🔍 檢查聊天室數據結構...\n";
    
    $sql = "
        SELECT 
            cr.id as room_id,
            cr.creator_id,
            cr.participant_id,
            cr.task_id,
            cr.created_at,
            cr.updated_at,
            t.title as task_title,
            t.status as task_status,
            t.creator_id as task_creator_id,
            t.participant_id as task_participant_id,
            u1.name as creator_name,
            u2.name as participant_name
        FROM chat_rooms cr
        LEFT JOIN tasks t ON cr.task_id = t.id
        LEFT JOIN users u1 ON cr.creator_id = u1.id
        LEFT JOIN users u2 ON cr.participant_id = u2.id
        WHERE cr.status = 'active'
        ORDER BY cr.created_at DESC
        LIMIT 5
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $rooms = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "📊 找到 " . count($rooms) . " 個活躍聊天室\n\n";
    
    foreach ($rooms as $index => $room) {
        echo "=== 聊天室 " . ($index + 1) . " ===\n";
        echo "房間ID: " . $room['room_id'] . "\n";
        echo "任務ID: " . $room['task_id'] . "\n";
        echo "任務標題: " . $room['task_title'] . "\n";
        echo "任務狀態: " . $room['task_status'] . "\n";
        echo "創建者ID: " . $room['creator_id'] . " (" . $room['creator_name'] . ")\n";
        echo "參與者ID: " . $room['participant_id'] . " (" . $room['participant_name'] . ")\n";
        echo "任務創建者ID: " . $room['task_creator_id'] . "\n";
        echo "任務參與者ID: " . $room['task_participant_id'] . "\n";
        echo "創建時間: " . $room['created_at'] . "\n";
        echo "更新時間: " . $room['updated_at'] . "\n";
        echo "\n";
    }
    
    // 檢查特定任務的申請者
    echo "🔍 檢查任務申請者...\n";
    
    $sql = "
        SELECT 
            t.id as task_id,
            t.title as task_title,
            t.status as task_status,
            t.creator_id as task_creator_id,
            COUNT(ta.id) as application_count,
            GROUP_CONCAT(ta.user_id) as applicant_ids,
            GROUP_CONCAT(u.name) as applicant_names
        FROM tasks t
        LEFT JOIN task_applications ta ON t.id = ta.task_id
        LEFT JOIN users u ON ta.user_id = u.id
        WHERE t.status = 'open'
        GROUP BY t.id
        ORDER BY t.created_at DESC
        LIMIT 5
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "📊 找到 " . count($tasks) . " 個開放任務\n\n";
    
    foreach ($tasks as $index => $task) {
        echo "=== 任務 " . ($index + 1) . " ===\n";
        echo "任務ID: " . $task['task_id'] . "\n";
        echo "任務標題: " . $task['task_title'] . "\n";
        echo "任務狀態: " . $task['task_status'] . "\n";
        echo "任務創建者ID: " . $task['task_creator_id'] . "\n";
        echo "申請者數量: " . $task['application_count'] . "\n";
        echo "申請者ID: " . $task['applicant_ids'] . "\n";
        echo "申請者名稱: " . $task['applicant_names'] . "\n";
        echo "\n";
    }
    
    // 檢查用戶數據
    echo "🔍 檢查用戶數據...\n";
    
    $sql = "
        SELECT 
            id,
            name,
            email,
            created_at
        FROM users
        ORDER BY created_at DESC
        LIMIT 5
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "📊 找到 " . count($users) . " 個用戶\n\n";
    
    foreach ($users as $index => $user) {
        echo "=== 用戶 " . ($index + 1) . " ===\n";
        echo "用戶ID: " . $user['id'] . "\n";
        echo "用戶名稱: " . $user['name'] . "\n";
        echo "用戶郵箱: " . $user['email'] . "\n";
        echo "創建時間: " . $user['created_at'] . "\n";
        echo "\n";
    }
    
    // 檢查 get_chat_detail_data API 的數據結構
    echo "🔍 模擬 get_chat_detail_data API 數據結構...\n";
    
    if (!empty($rooms)) {
        $sampleRoom = $rooms[0];
        $roomId = $sampleRoom['room_id'];
        
        echo "使用房間ID: $roomId 作為示例\n";
        
        // 查詢完整的聊天室數據
        $sql = "
            SELECT 
                cr.*,
                t.*,
                u1.name as creator_name,
                u1.avatar_url as creator_avatar,
                u2.name as participant_name,
                u2.avatar_url as participant_avatar,
                ta.id as application_id,
                ta.cover_letter,
                ta.answers_json
            FROM chat_rooms cr
            LEFT JOIN tasks t ON cr.task_id = t.id
            LEFT JOIN users u1 ON cr.creator_id = u1.id
            LEFT JOIN users u2 ON cr.participant_id = u2.id
            LEFT JOIN task_applications ta ON (t.id = ta.task_id AND cr.participant_id = ta.user_id)
            WHERE cr.id = :room_id
        ";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute(['room_id' => $roomId]);
        $chatData = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($chatData) {
            echo "✅ 找到聊天室數據\n";
            echo "數據結構:\n";
            echo "- chat_room:\n";
            echo "  - id: " . $chatData['id'] . "\n";
            echo "  - creator_id: " . $chatData['creator_id'] . "\n";
            echo "  - participant_id: " . $chatData['participant_id'] . "\n";
            echo "  - task_id: " . $chatData['task_id'] . "\n";
            echo "- task:\n";
            echo "  - id: " . $chatData['task_id'] . "\n";
            echo "  - title: " . $chatData['title'] . "\n";
            echo "  - status: " . $chatData['status'] . "\n";
            echo "  - creator_id: " . $chatData['creator_id'] . "\n";
            echo "- creator:\n";
            echo "  - name: " . $chatData['creator_name'] . "\n";
            echo "  - avatar: " . $chatData['creator_avatar'] . "\n";
            echo "- participant:\n";
            echo "  - name: " . $chatData['participant_name'] . "\n";
            echo "  - avatar: " . $chatData['participant_avatar'] . "\n";
            echo "- application:\n";
            echo "  - id: " . $chatData['application_id'] . "\n";
            echo "  - cover_letter: " . ($chatData['cover_letter'] ? '有' : '無') . "\n";
            echo "  - answers_json: " . ($chatData['answers_json'] ? '有' : '無') . "\n";
        } else {
            echo "❌ 未找到聊天室數據\n";
        }
    }
    
} catch (PDOException $e) {
    echo "❌ 數據庫錯誤: " . $e->getMessage() . "\n";
} catch (Exception $e) {
    echo "❌ 一般錯誤: " . $e->getMessage() . "\n";
}

echo "\n🎯 診斷建議:\n";
echo "1. 檢查聊天室數據中的 creator_id 和 participant_id 是否正確\n";
echo "2. 確認任務狀態是否為 'open' 或 'applying_tasker'\n";
echo "3. 驗證用戶ID是否與聊天室中的角色匹配\n";
echo "4. 檢查前端傳遞的用戶ID是否正確\n";
?>
