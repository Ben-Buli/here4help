<?php
require_once __DIR__ . '/../../../config/env_loader.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        throw new Exception('Method not allowed');
    }

    // 驗證 JWT token
    $jwtManager = new JWTManager();
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = str_replace('Bearer ', '', $authHeader);
    
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
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
    $allowedStatuses = ['applied', 'accepted', 'rejected', 'cancelled'];
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
        WHERE ta.id = ? AND ta.deleted_at IS NULL
    ");
    $stmt->execute([$applicationId]);
    $application = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$application) {
        throw new Exception('Application not found');
    }
    
    // 檢查權限：只有任務創建者可以更新應徵狀態
    if ($application['creator_id'] != $userId) {
        throw new Exception('You do not have permission to update this application');
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
        $logSql = "
            INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
            VALUES (?, 'application_status_updated', ?, ?, NOW())
        ";
        
        $logStmt = $pdo->prepare($logSql);
        $logStmt->execute([
            $userId, 
            json_encode([
                'application_id' => $applicationId,
                'task_id' => $application['task_id'],
                'task_title' => $application['title'],
                'applicant_id' => $application['user_id'],
                'old_status' => $currentStatus,
                'new_status' => $newStatus,
                'updated_at' => date('Y-m-d H:i:s')
            ]),
            $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
        
        // 如果是接受應徵，需要拒絕同一任務的其他應徵
        if ($newStatus === 'accepted') {
            $rejectOthersStmt = $pdo->prepare("
                UPDATE task_applications 
                SET status = 'rejected', updated_at = NOW() 
                WHERE task_id = ? AND id != ? AND status = 'applied'
            ");
            $rejectOthersStmt->execute([$application['task_id'], $applicationId]);
            
            // 記錄自動拒絕其他應徵的日誌
            $autoRejectLogStmt = $pdo->prepare($logSql);
            $autoRejectLogStmt->execute([
                $userId, 
                json_encode([
                    'action' => 'auto_reject_other_applications',
                    'accepted_application_id' => $applicationId,
                    'task_id' => $application['task_id'],
                    'task_title' => $application['title']
                ]),
                $_SERVER['REMOTE_ADDR'] ?? 'unknown'
            ]);
        }
        
        // 提交交易
        $pdo->commit();
        
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
