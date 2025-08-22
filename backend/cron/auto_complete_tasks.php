<?php
/**
 * 自動完成任務排程腳本
 * 
 * 功能：檢查 pending confirmation 狀態超過7天的任務，自動標記為 completed
 * 執行方式：透過 cron job 定期執行（建議每小時執行一次）
 * 
 * Cron 設定範例：
 * 0 * * * * /usr/bin/php /path/to/backend/cron/auto_complete_tasks.php
 */

// 設定錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

// 載入必要的檔案
require_once __DIR__ . '/../config/database.php';

/**
 * 記錄日誌
 */
function logMessage($message, $level = 'INFO') {
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] [$level] $message" . PHP_EOL;
    
    // 寫入日誌檔案
    $logFile = __DIR__ . '/../logs/auto_complete_' . date('Y-m') . '.log';
    $logDir = dirname($logFile);
    
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    file_put_contents($logFile, $logMessage, FILE_APPEND | LOCK_EX);
    
    // 同時輸出到控制台（用於 cron 調試）
    echo $logMessage;
}

/**
 * 自動完成超過7天的 pending confirmation 任務
 */
function autoCompleteTasks() {
    try {
        $db = Database::getInstance()->getConnection();
        
        logMessage("開始執行自動完成任務檢查");
        
        // 查詢超過7天的 pending confirmation 任務
        $sql = "
            SELECT 
                t.id,
                t.title,
                t.creator_id,
                t.participant_id,
                t.status_id,
                ts.code as status_code,
                t.updated_at,
                DATEDIFF(NOW(), t.updated_at) as days_pending
            FROM tasks t
            JOIN task_statuses ts ON t.status_id = ts.id
            WHERE ts.code = 'pending_confirmation'
            AND DATEDIFF(NOW(), t.updated_at) >= 7
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        $pendingTasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (empty($pendingTasks)) {
            logMessage("沒有找到需要自動完成的任務");
            return;
        }
        
        logMessage("找到 " . count($pendingTasks) . " 個需要自動完成的任務");
        
        // 獲取 completed 狀態的 ID
        $completedStatusSql = "SELECT id FROM task_statuses WHERE code = 'completed' LIMIT 1";
        $completedStatusStmt = $db->prepare($completedStatusSql);
        $completedStatusStmt->execute();
        $completedStatus = $completedStatusStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$completedStatus) {
            logMessage("錯誤：找不到 completed 狀態", 'ERROR');
            return;
        }
        
        $completedStatusId = $completedStatus['id'];
        $completedCount = 0;
        
        // 開始資料庫交易
        $db->beginTransaction();
        
        foreach ($pendingTasks as $task) {
            try {
                // 更新任務狀態為 completed
                $updateTaskSql = "
                    UPDATE tasks 
                    SET status_id = :status_id, updated_at = NOW() 
                    WHERE id = :task_id
                ";
                $updateTaskStmt = $db->prepare($updateTaskSql);
                $updateTaskStmt->execute([
                    ':status_id' => $completedStatusId,
                    ':task_id' => $task['id']
                ]);
                
                // 記錄到 task_logs
                $logSql = "
                    INSERT INTO task_logs (
                        task_id, 
                        user_id, 
                        action, 
                        old_status, 
                        new_status, 
                        notes, 
                        created_at
                    ) VALUES (
                        :task_id,
                        NULL,
                        'auto_complete',
                        :old_status,
                        'completed',
                        :notes,
                        NOW()
                    )
                ";
                $logStmt = $db->prepare($logSql);
                $logStmt->execute([
                    ':task_id' => $task['id'],
                    ':old_status' => $task['status_code'],
                    ':notes' => "系統自動完成：pending confirmation 超過 {$task['days_pending']} 天"
                ]);
                
                // 記錄到用戶活動日誌（創建者和接受者）
                $activitySql = "
                    INSERT INTO user_activity_logs (
                        user_id,
                        action,
                        resource_type,
                        resource_id,
                        details,
                        created_at
                    ) VALUES (?, ?, ?, ?, ?, NOW())
                ";
                $activityStmt = $db->prepare($activitySql);
                
                // 為創建者記錄
                if ($task['creator_id']) {
                    $activityStmt->execute([
                        $task['creator_id'],
                        'task_auto_completed',
                        'task',
                        $task['id'],
                        json_encode([
                            'task_title' => $task['title'],
                            'days_pending' => $task['days_pending'],
                            'auto_completed_at' => date('Y-m-d H:i:s')
                        ])
                    ]);
                }
                
                // 為接受者記錄
                if ($task['participant_id']) {
                    $activityStmt->execute([
                        $task['participant_id'],
                        'task_auto_completed',
                        'task',
                        $task['id'],
                        json_encode([
                            'task_title' => $task['title'],
                            'days_pending' => $task['days_pending'],
                            'auto_completed_at' => date('Y-m-d H:i:s')
                        ])
                    ]);
                }
                
                $completedCount++;
                logMessage("任務 ID {$task['id']} ('{$task['title']}') 已自動完成 ({$task['days_pending']} 天)");
                
            } catch (Exception $e) {
                logMessage("處理任務 ID {$task['id']} 時發生錯誤: " . $e->getMessage(), 'ERROR');
                // 繼續處理其他任務，不中斷整個流程
            }
        }
        
        // 提交交易
        $db->commit();
        
        logMessage("自動完成任務檢查完成，共處理 $completedCount 個任務");
        
    } catch (Exception $e) {
        // 回滾交易
        if ($db && $db->inTransaction()) {
            $db->rollback();
        }
        
        logMessage("自動完成任務時發生嚴重錯誤: " . $e->getMessage(), 'ERROR');
        throw $e;
    }
}

/**
 * 清理舊日誌檔案（保留最近3個月）
 */
function cleanupOldLogs() {
    $logDir = __DIR__ . '/../logs/';
    if (!is_dir($logDir)) {
        return;
    }
    
    $files = glob($logDir . 'auto_complete_*.log');
    $cutoffDate = date('Y-m', strtotime('-3 months'));
    
    foreach ($files as $file) {
        if (preg_match('/auto_complete_(\d{4}-\d{2})\.log$/', basename($file), $matches)) {
            $fileDate = $matches[1];
            if ($fileDate < $cutoffDate) {
                unlink($file);
                logMessage("已刪除舊日誌檔案: " . basename($file));
            }
        }
    }
}

// 主執行邏輯
try {
    logMessage("=== 自動完成任務排程開始 ===");
    
    // 執行自動完成檢查
    autoCompleteTasks();
    
    // 清理舊日誌（每月第一天執行）
    if (date('d') === '01') {
        cleanupOldLogs();
    }
    
    logMessage("=== 自動完成任務排程結束 ===");
    
} catch (Exception $e) {
    logMessage("排程執行失敗: " . $e->getMessage(), 'ERROR');
    exit(1);
}

exit(0);
