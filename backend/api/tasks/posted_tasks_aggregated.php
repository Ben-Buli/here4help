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
    
    // 聚合查詢：任務基本資訊 + 應徵者統計
    $sql = "SELECT 
              t.*, 
              s.id AS status_id,
              s.code AS status_code,
              s.display_name AS status_display,
              s.progress_ratio,
              s.sort_order,
              u.id AS creator_id,
              u.name AS creator_name,
              u.avatar_url AS creator_avatar,
              COALESCE(app_stats.total_applications, 0) AS total_applications,
              COALESCE(app_stats.pending_applications, 0) AS pending_applications,
              COALESCE(app_stats.approved_applications, 0) AS approved_applications
            FROM tasks t
            LEFT JOIN task_statuses s ON t.status_id = s.id
            LEFT JOIN users u ON t.creator_id = u.id
            LEFT JOIN (
                SELECT 
                    task_id,
                    COUNT(*) AS total_applications,
                    SUM(CASE WHEN status = 'applied' THEN 1 ELSE 0 END) AS pending_applications,
                    SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved_applications
                FROM task_applications 
                GROUP BY task_id
            ) app_stats ON t.id = app_stats.task_id
            $whereClause
            ORDER BY t.created_at DESC 
            LIMIT ? OFFSET ?";
    
    $params[] = $limit;
    $params[] = $offset;
    
    $tasks = $db->fetchAll($sql, $params);
    
    // 為每個任務獲取詳細的應徵者資訊（包含聊天室ID）
    foreach ($tasks as &$task) {
        $taskId = $task['id'];
        
        // 獲取應徵者詳細資訊
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
                
                -- 計算用戶平均評分（假設有評分系統）
                COALESCE(ratings.avg_rating, 0.0) AS avg_rating,
                COALESCE(ratings.review_count, 0) AS review_count,
                
                -- 獲取聊天室ID
                cr.id AS chat_room_id,
                
                -- 獲取第一則訊息片段
                COALESCE(
                    SUBSTRING(ta.cover_letter, 1, 100),
                    'Applied for this task'
                ) AS first_message_snippet
                
            FROM task_applications ta
            LEFT JOIN users u ON ta.user_id = u.id
            LEFT JOIN (
                -- 假設的評分統計（需要根據實際評分表結構調整）
                SELECT 
                    user_id,
                    AVG(rating) AS avg_rating,
                    COUNT(*) AS review_count
                FROM user_ratings ur
                GROUP BY user_id
            ) ratings ON u.id = ratings.user_id
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
            if (strlen($applicant['first_message_snippet']) > 97) {
                $applicant['first_message_snippet'] = substr($applicant['first_message_snippet'], 0, 97) . '...';
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
