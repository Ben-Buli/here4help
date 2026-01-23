<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

require_once __DIR__ . '/../../../utils/TokenValidator.php';
require_once __DIR__ . '/../../../utils/UserActiveLogger.php';
require_once __DIR__ . '/../../../utils/socket_notifier.php';
require_once __DIR__ . '/../../../config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        throw new Exception('Method not allowed');
    }

    // 驗證 JWT token
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($authHeader) || !preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        throw new Exception('Authorization header required');
    }
    
    $userId = TokenValidator::validateAuthHeader($authHeader);
    if (!$userId) {
        throw new Exception('Invalid or expired token');
    }
    $userId = (int)$userId;
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $applicationId = $input['application_id'] ?? '';
    $newStatus = $input['status'] ?? '';
    
    // 驗證必要欄位
    if (empty($applicationId)) {
        throw new Exception('Application ID is required');
    }
    
    if (empty($newStatus)) {
        throw new Exception('Status is required');
    }
    
    // 驗證狀態值
    $allowedStatuses = ['applied', 'accepted', 'rejected', 'cancelled', 'withdrawn'];
    if (!in_array($newStatus, $allowedStatuses)) {
        throw new Exception('Invalid status. Allowed values: ' . implode(', ', $allowedStatuses));
    }
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 查詢應徵記錄並驗證權限
    $stmt = $pdo->prepare("
        SELECT ta.*, t.creator_id, t.title 
        FROM task_applications ta
        JOIN tasks t ON ta.task_id = t.id
        WHERE ta.id = ? 
    ");
    $stmt->execute([$applicationId]);
    $application = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$application) {
        throw new Exception('Application not found');
    }
    
    // 檢查權限：
    // - 任務創建者可以更新應徵狀態（除了 withdrawn）
    // - 應徵者只能將自己的應徵狀態改為 withdrawn 或 cancelled
    $isCreator = ($application['creator_id'] == $userId);
    $isApplicant = ($application['user_id'] == $userId);
    
    if (!$isCreator && !$isApplicant) {
        throw new Exception('You do not have permission to update this application');
    }
    
    // 應徵者只能撤回自己的應徵
    if ($isApplicant && !in_array($newStatus, ['withdrawn', 'cancelled'])) {
        throw new Exception('Applicants can only withdraw or cancel their own applications');
    }
    
    // 任務創建者不能將應徵狀態改為 withdrawn（這是應徵者的專屬操作）
    if ($isCreator && $newStatus === 'withdrawn') {
        throw new Exception('Only applicants can withdraw their applications');
    }
    
    // 檢查當前狀態是否允許更新
    $currentStatus = $application['status'];
    if ($currentStatus === $newStatus) {
        throw new Exception('Application is already in the requested status');
    }
    
    // 開始資料庫交易
    $pdo->beginTransaction();
    
    try {
        // 更新應徵狀態
        $updateStmt = $pdo->prepare("
            UPDATE task_applications 
            SET status = ?, updated_at = NOW() 
            WHERE id = ?
        ");
        
        $updateStmt->execute([$newStatus, $applicationId]);
        
        // 記錄操作日誌
        UserActiveLogger::logAction(
            $pdo,
            $application['user_id'], // 被影響的用戶（應徵者）
            'application_status_updated',
            'status',
            $currentStatus,
            $newStatus,
            "Application status changed from {$currentStatus} to {$newStatus}",
            'user',
            $userId, // 操作者（可能是創建者或應徵者自己）
            $_SERVER['HTTP_X_REQUEST_ID'] ?? null,
            $_SERVER['HTTP_X_TRACE_ID'] ?? null,
            [
                'application_id' => $applicationId,
                'task_id' => $application['task_id'],
                'task_title' => $application['title'],
                'operator_role' => $isCreator ? 'creator' : 'applicant',
                'updated_at' => date('Y-m-d H:i:s')
            ]
        );
        
        // 如果是接受應徵，需要拒絕同一任務的其他應徵
        if ($newStatus === 'accepted') {
            $rejectOthersStmt = $pdo->prepare("
                UPDATE task_applications 
                SET status = 'rejected', updated_at = NOW() 
                WHERE task_id = ? AND id != ? AND status = 'applied'
            ");
            $rejectOthersStmt->execute([$application['task_id'], $applicationId]);
            
            // 記錄自動拒絕其他應徵的日誌
            UserActiveLogger::logAction(
                $pdo,
                $userId, // 操作者（任務創建者）
                'auto_reject_applications',
                'multiple_applications',
                'applied',
                'rejected',
                "Auto-rejected other applications when accepting application {$applicationId}",
                'user',
                $userId,
                $_SERVER['HTTP_X_REQUEST_ID'] ?? null,
                $_SERVER['HTTP_X_TRACE_ID'] ?? null,
                [
                    'accepted_application_id' => $applicationId,
                    'task_id' => $application['task_id'],
                    'task_title' => $application['title'],
                    'rejected_count' => $rejectOthersStmt->rowCount()
                ]
            );
        }
        
        // 提交交易
        $pdo->commit();
        
        // 發送 Socket 通知
        try {
            $socketNotifier = SocketNotifier::getInstance();
            $userIds = $socketNotifier->getTaskUserIds($application['task_id']);
            $db = Database::getInstance();
            $room = $db->fetch(
                "SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1",
                [$application['task_id']]
            );
            $roomId = $room ? $room['id'] : null;
            
            // 通知應徵狀態更新
            $socketNotifier->notifyApplicationStatusUpdate(
                $application['task_id'], 
                $roomId, 
                $newStatus, 
                $userIds
            );
            
            // 如果是撤銷應徵，可能需要額外的任務狀態通知
            if ($newStatus === 'withdrawn') {
                // 檢查是否還有其他應徵者
                $remainingApplications = $db->fetch(
                    "SELECT COUNT(*) as count FROM task_applications WHERE task_id = ? AND status = 'applied'",
                    [$application['task_id']]
                );
                
                // 如果沒有其他應徵者，任務可能需要回到 open 狀態
                if ($remainingApplications && $remainingApplications['count'] == 0) {
                    // 這裡可以添加任務狀態更新邏輯，如果需要的話
                }
            }
        } catch (Exception $e) {
            error_log("Socket notification failed: " . $e->getMessage());
        }
        
        $response = [
            'success' => true,
            'message' => 'Application status updated successfully',
            'data' => [
                'application_id' => $applicationId,
                'old_status' => $currentStatus,
                'new_status' => $newStatus,
                'updated_at' => date('Y-m-d H:i:s')
            ]
        ];
        
        echo json_encode($response);
        
    } catch (Exception $e) {
        // 回滾交易
        $pdo->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
