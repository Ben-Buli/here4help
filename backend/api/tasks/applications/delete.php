<?php
require_once __DIR__ . '/../../../config/env_loader.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
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
    
    // 從 URL 參數獲取 application_id
    $applicationId = $_GET['application_id'] ?? '';
    
    // 驗證必要欄位
    if (empty($applicationId)) {
        throw new Exception('Application ID is required');
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
    
    // 檢查權限：只有任務創建者可以刪除應徵
    if ($application['creator_id'] != $userId) {
        throw new Exception('You do not have permission to delete this application');
    }
    
    // 檢查應徵狀態：不能刪除已接受的應徵
    if ($application['status'] === 'accepted') {
        throw new Exception('Cannot delete an accepted application. Please reject it first.');
    }
    
    // 開始資料庫交易
    $pdo->beginTransaction();
    
    try {
        // 軟刪除應徵記錄
        $deleteStmt = $pdo->prepare("
            UPDATE task_applications 
            SET deleted_at = NOW(), updated_at = NOW() 
            WHERE id = ?
        ");
        
        $deleteStmt->execute([$applicationId]);
        
        // 記錄操作日誌
        $logSql = "
            INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
            VALUES (?, 'application_deleted', ?, ?, NOW())
        ";
        
        $logStmt = $pdo->prepare($logSql);
        $logStmt->execute([
            $userId, 
            json_encode([
                'application_id' => $applicationId,
                'task_id' => $application['task_id'],
                'task_title' => $application['title'],
                'applicant_id' => $application['user_id'],
                'previous_status' => $application['status'],
                'deleted_at' => date('Y-m-d H:i:s')
            ]),
            $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
        
        // 提交交易
        $pdo->commit();
        
        $response = [
            'success' => true,
            'message' => 'Application deleted successfully',
            'data' => [
                'application_id' => $applicationId,
                'deleted_at' => date('Y-m-d H:i:s')
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
