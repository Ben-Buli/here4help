<?php
/**
 * Posted Tasks 聚合 API
 * GET /api/tasks/posted_tasks_aggregated.php
 * 專為 Posted Tasks 分頁設計的聚合數據API
 */

require_once '../../config/database.php';
require_once '../../utils/Response.php';

// 設定 CORS 標頭
Response::setCorsHeaders();

// 只允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 獲取查詢參數
    $creator_id = $_GET['creator_id'] ?? null;
    $status = $_GET['status'] ?? null;
    $location = $_GET['location'] ?? null;
    $language = $_GET['language'] ?? null;
    $limit = (int)($_GET['limit'] ?? 20);
    $offset = (int)($_GET['offset'] ?? 0);
    
    if (!$creator_id) {
        Response::validationError(['creator_id' => 'creator_id is required']);
    }
    
    // 建立查詢條件
    $whereConditions = ['t.creator_id = ?'];
    $params = [(int)$creator_id];
    
    if ($status) {
        if (is_numeric($status)) {
            $whereConditions[] = "t.status_id = ?";
            $params[] = (int)$status;
        } else {
            $whereConditions[] = "s.code = ?";
            $params[] = $status;
        }
    }
    
    if ($location) {
        $whereConditions[] = "t.location LIKE ?";
        $params[] = "%$location%";
    }
    
    if ($language) {
        $whereConditions[] = "t.language_requirement = ?";
        $params[] = $language;
    }
    
    $whereClause = 'WHERE ' . implode(' AND ', $whereConditions);
    
    // 簡化查詢：先確保基本任務數據能取得
    $sql = "SELECT 
              t.*, 
              s.id AS status_id,
              s.code AS status_code,
              s.display_name AS status_display,
              s.progress_ratio,
              s.sort_order,
              u.id AS creator_id,
              u.name AS creator_name,
              u.avatar_url AS creator_avatar
            FROM tasks t
            LEFT JOIN task_statuses s ON t.status_id = s.id
            LEFT JOIN users u ON t.creator_id = u.id
            $whereClause
            ORDER BY t.status_id DESC, t.updated_at DESC 
            LIMIT ? OFFSET ?";
    
    $params[] = $limit;
    $params[] = $offset;
    
    // 添加除錯資訊
    error_log("🔍 [Posted Tasks Aggregated] 查詢用戶 ID: $creator_id");
    error_log("🔍 [Posted Tasks Aggregated] SQL: $sql");
    error_log("🔍 [Posted Tasks Aggregated] 參數: " . json_encode($params));
    
    $tasks = $db->fetchAll($sql, $params);
    
    error_log("🔍 [Posted Tasks Aggregated] 查詢結果數量: " . count($tasks));
    
    // 檢查是否有遺漏的任務
    $totalTasksCount = $db->fetch("SELECT COUNT(*) as count FROM tasks WHERE creator_id = ?", [(int)$creator_id])['count'];
    error_log("🔍 [Posted Tasks Aggregated] 資料庫總任務數: $totalTasksCount, API 返回: " . count($tasks));
    
    if ($totalTasksCount > count($tasks)) {
        error_log("⚠️ [Posted Tasks Aggregated] 發現遺漏任務！資料庫: $totalTasksCount, API: " . count($tasks));
    }
    
    // 為每個任務獲取詳細的應徵者資訊（包含聊天室ID）
    foreach ($tasks as &$task) {
        $taskId = $task['id'];
        
        // 簡化應徵者查詢：移除評分統計以確保基本功能
        $applicantsSql = "
            SELECT 
                ta.id AS application_id,
                ta.user_id,
                ta.status AS application_status,
                ta.cover_letter,
                ta.answers_json,
                ta.created_at AS application_created_at,
                ta.updated_at AS application_updated_at,
                
                u.name AS applier_name,
                u.avatar_url AS applier_avatar,
                u.email AS applier_email,
                
                -- 暫時使用預設評分值
                4.0 AS avg_rating,
                0 AS review_count,
                
                -- 獲取聊天室ID
                cr.id AS chat_room_id,
                
                -- 獲取最新聊天訊息片段
                COALESCE(
                    (SELECT SUBSTRING(cm.content, 1, 100)
                     FROM chat_messages cm 
                     WHERE cm.room_id = cr.id 
                     ORDER BY cm.created_at DESC 
                     LIMIT 1),
                    SUBSTRING(ta.cover_letter, 1, 100),
                    'Applied for this task'
                ) AS latest_message_snippet
                
            FROM task_applications ta
            LEFT JOIN users u ON ta.user_id = u.id
            LEFT JOIN chat_rooms cr ON (
                cr.task_id = ta.task_id 
                AND cr.participant_id = ta.user_id 
                AND cr.creator_id = ?
            )
            WHERE ta.task_id = ?
            ORDER BY ta.created_at DESC
        ";
        
        $applicants = $db->fetchAll($applicantsSql, [$creator_id, $taskId]);
        
        // 處理訊息片段截斷
        foreach ($applicants as &$applicant) {
            if (isset($applicant['latest_message_snippet']) && strlen($applicant['latest_message_snippet']) > 97) {
                $applicant['latest_message_snippet'] = substr($applicant['latest_message_snippet'], 0, 97) . '...';
            }
        }
        
        $task['applicants'] = $applicants;
        
        // 獲取申請問題
        $questionsSql = "SELECT * FROM application_questions WHERE task_id = ?";
        $questions = $db->fetchAll($questionsSql, [$taskId]);
        $task['application_questions'] = $questions;
        
        // 處理標籤
        if ($task['hashtags']) {
            $task['hashtags'] = explode(',', $task['hashtags']);
        } else {
            $task['hashtags'] = [];
        }
    }
    
    // 獲取總數
    $countSql = "SELECT COUNT(*) as total FROM tasks t 
                 LEFT JOIN task_statuses s ON t.status_id = s.id
                 LEFT JOIN users u ON t.creator_id = u.id
                 $whereClause";
    $countParams = $params;
    // 去除 LIMIT/OFFSET 兩個參數
    array_pop($countParams);
    array_pop($countParams);
    $totalResult = $db->fetch($countSql, $countParams);
    $total = $totalResult['total'];
    
    Response::success([
        'tasks' => $tasks,
        'pagination' => [
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => ($offset + $limit) < $total
        ]
    ], 'Posted tasks with aggregated data retrieved successfully');
    
} catch (Exception $e) {
    Response::serverError('Failed to retrieve posted tasks: ' . $e->getMessage());
}
?>
