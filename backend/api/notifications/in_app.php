<?php
/**
 * 站內通知 API
 * 處理站內通知的查詢、標記已讀、刪除等操作
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../database/database_manager.php';
require_once __DIR__ . '/../../utils/Logger.php';

// 設定 CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    // JWT 驗證
    $jwt = JWTManager::validateToken();
    if (!$jwt['valid']) {
        Response::error('UNAUTHORIZED', $jwt['message']);
        exit;
    }
    
    $userId = $jwt['payload']['user_id'];
    $method = $_SERVER['REQUEST_METHOD'];
    
    switch ($method) {
        case 'GET':
            handleGetNotifications($userId);
            break;
            
        case 'POST':
            handleCreateNotification($userId);
            break;
            
        case 'PUT':
            handleUpdateNotification($userId);
            break;
            
        case 'DELETE':
            handleDeleteNotification($userId);
            break;
            
        default:
            Response::error('METHOD_NOT_ALLOWED', '不支援的請求方法');
    }
    
} catch (Exception $e) {
    Logger::logError('in_app_notification_api_failed', ['user_id' => $userId ?? null], $e);
    Response::error('INTERNAL_ERROR', '站內通知 API 處理失敗');
}

/**
 * 獲取站內通知列表
 */
function handleGetNotifications($userId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        // 分頁參數
        $page = max(1, intval($_GET['page'] ?? 1));
        $perPage = min(50, max(1, intval($_GET['per_page'] ?? 20)));
        $offset = ($page - 1) * $perPage;
        
        // 篩選參數
        $unreadOnly = isset($_GET['unread_only']) && $_GET['unread_only'] === 'true';
        $pinnedOnly = isset($_GET['pinned_only']) && $_GET['pinned_only'] === 'true';
        
        // 建構查詢條件
        $whereConditions = ['user_id = ?'];
        $params = [$userId];
        
        if ($unreadOnly) {
            $whereConditions[] = 'is_read = 0';
        }
        
        if ($pinnedOnly) {
            $whereConditions[] = 'is_pinned = 1';
        }
        
        $whereClause = implode(' AND ', $whereConditions);
        
        // 查詢通知列表
        $sql = "
            SELECT id, title, body, icon, image_url, action_type, action_data,
                   is_read, is_pinned, read_at, related_type, related_id,
                   expires_at, created_at, updated_at
            FROM in_app_notifications 
            WHERE $whereClause
            AND (expires_at IS NULL OR expires_at > NOW())
            ORDER BY is_pinned DESC, created_at DESC
            LIMIT ? OFFSET ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute(array_merge($params, [$perPage, $offset]));
        $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 處理通知資料
        foreach ($notifications as &$notification) {
            $notification['action_data'] = json_decode($notification['action_data'], true);
            $notification['is_read'] = (bool)$notification['is_read'];
            $notification['is_pinned'] = (bool)$notification['is_pinned'];
        }
        
        // 查詢總數
        $countSql = "
            SELECT COUNT(*) 
            FROM in_app_notifications 
            WHERE $whereClause
            AND (expires_at IS NULL OR expires_at > NOW())
        ";
        
        $countStmt = $db->prepare($countSql);
        $countStmt->execute($params);
        $total = $countStmt->fetchColumn();
        
        // 查詢未讀數量
        $unreadSql = "
            SELECT COUNT(*) 
            FROM in_app_notifications 
            WHERE user_id = ? AND is_read = 0
            AND (expires_at IS NULL OR expires_at > NOW())
        ";
        
        $unreadStmt = $db->prepare($unreadSql);
        $unreadStmt->execute([$userId]);
        $unreadCount = $unreadStmt->fetchColumn();
        
        Response::success([
            'notifications' => $notifications,
            'pagination' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'total_pages' => ceil($total / $perPage)
            ],
            'unread_count' => $unreadCount
        ]);
        
    } catch (Exception $e) {
        Logger::logError('get_notifications_failed', ['user_id' => $userId], $e);
        Response::error('QUERY_FAILED', '查詢通知失敗');
    }
}

/**
 * 建立站內通知（管理員功能）
 */
function handleCreateNotification($userId) {
    try {
        // 檢查管理員權限
        if (!isAdmin($userId)) {
            Response::error('FORBIDDEN', '需要管理員權限');
            exit;
        }
        
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            Response::error('INVALID_JSON', '無效的 JSON 資料');
            exit;
        }
        
        // 驗證必要欄位
        $requiredFields = ['target_user_id', 'title', 'body'];
        foreach ($requiredFields as $field) {
            if (!isset($input[$field]) || empty($input[$field])) {
                Response::error('MISSING_FIELD', "缺少必要欄位: $field");
                exit;
            }
        }
        
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            INSERT INTO in_app_notifications 
            (user_id, title, body, icon, image_url, action_type, action_data, 
             is_pinned, related_type, related_id, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ";
        
        $stmt = $db->prepare($sql);
        $success = $stmt->execute([
            $input['target_user_id'],
            $input['title'],
            $input['body'],
            $input['icon'] ?? null,
            $input['image_url'] ?? null,
            $input['action_type'] ?? null,
            json_encode($input['action_data'] ?? []),
            $input['is_pinned'] ?? false,
            $input['related_type'] ?? null,
            $input['related_id'] ?? null,
            $input['expires_at'] ?? null
        ]);
        
        if ($success) {
            $notificationId = $db->lastInsertId();
            
            Logger::logBusiness('in_app_notification_created', $userId, [
                'notification_id' => $notificationId,
                'target_user_id' => $input['target_user_id']
            ]);
            
            Response::success([
                'id' => $notificationId,
                'message' => '站內通知建立成功'
            ]);
        } else {
            Response::error('CREATE_FAILED', '建立通知失敗');
        }
        
    } catch (Exception $e) {
        Logger::logError('create_notification_failed', ['user_id' => $userId], $e);
        Response::error('CREATE_FAILED', '建立通知失敗');
    }
}

/**
 * 更新通知狀態
 */
function handleUpdateNotification($userId) {
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            Response::error('INVALID_JSON', '無效的 JSON 資料');
            exit;
        }
        
        $notificationId = $input['id'] ?? null;
        if (!$notificationId) {
            Response::error('MISSING_ID', '缺少通知 ID');
            exit;
        }
        
        $db = Database::getInstance()->getConnection();
        
        // 檢查通知是否屬於當前使用者
        $checkSql = "SELECT id FROM in_app_notifications WHERE id = ? AND user_id = ?";
        $checkStmt = $db->prepare($checkSql);
        $checkStmt->execute([$notificationId, $userId]);
        
        if (!$checkStmt->fetch()) {
            Response::error('NOT_FOUND', '通知不存在或無權限');
            exit;
        }
        
        // 準備更新欄位
        $updateFields = [];
        $params = [];
        
        if (isset($input['is_read'])) {
            $updateFields[] = 'is_read = ?';
            $params[] = $input['is_read'] ? 1 : 0;
            
            if ($input['is_read']) {
                $updateFields[] = 'read_at = NOW()';
            }
        }
        
        if (isset($input['is_pinned'])) {
            $updateFields[] = 'is_pinned = ?';
            $params[] = $input['is_pinned'] ? 1 : 0;
        }
        
        if (empty($updateFields)) {
            Response::error('NO_UPDATES', '沒有要更新的欄位');
            exit;
        }
        
        $updateFields[] = 'updated_at = NOW()';
        $params[] = $notificationId;
        
        $sql = "UPDATE in_app_notifications SET " . implode(', ', $updateFields) . " WHERE id = ?";
        
        $stmt = $db->prepare($sql);
        $success = $stmt->execute($params);
        
        if ($success) {
            Logger::logBusiness('in_app_notification_updated', $userId, [
                'notification_id' => $notificationId,
                'updates' => array_keys($input)
            ]);
            
            Response::success(['message' => '通知更新成功']);
        } else {
            Response::error('UPDATE_FAILED', '更新通知失敗');
        }
        
    } catch (Exception $e) {
        Logger::logError('update_notification_failed', ['user_id' => $userId], $e);
        Response::error('UPDATE_FAILED', '更新通知失敗');
    }
}

/**
 * 刪除通知
 */
function handleDeleteNotification($userId) {
    try {
        $notificationId = $_GET['id'] ?? null;
        if (!$notificationId) {
            Response::error('MISSING_ID', '缺少通知 ID');
            exit;
        }
        
        $db = Database::getInstance()->getConnection();
        
        // 檢查通知是否屬於當前使用者
        $sql = "DELETE FROM in_app_notifications WHERE id = ? AND user_id = ?";
        $stmt = $db->prepare($sql);
        $success = $stmt->execute([$notificationId, $userId]);
        
        if ($stmt->rowCount() > 0) {
            Logger::logBusiness('in_app_notification_deleted', $userId, [
                'notification_id' => $notificationId
            ]);
            
            Response::success(['message' => '通知刪除成功']);
        } else {
            Response::error('NOT_FOUND', '通知不存在或無權限');
        }
        
    } catch (Exception $e) {
        Logger::logError('delete_notification_failed', ['user_id' => $userId], $e);
        Response::error('DELETE_FAILED', '刪除通知失敗');
    }
}

/**
 * 檢查是否為管理員
 */
function isAdmin($userId) {
    try {
        $db = Database::getInstance()->getConnection();
        $sql = "SELECT COUNT(*) FROM users WHERE id = ? AND role = 'admin'";
        $stmt = $db->prepare($sql);
        $stmt->execute([$userId]);
        return $stmt->fetchColumn() > 0;
    } catch (Exception $e) {
        return false;
    }
}
