<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

// 清理 OAuth 暫存資料 API
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    // 引入必要的檔案
    require_once __DIR__ . '/../../config/database.php';
    require_once __DIR__ . '/../../utils/Response.php';
    
    // 載入環境配置
    require_once __DIR__ . '/../../config/env_loader.php';
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['oauth_token'])) {
        throw new Exception('OAuth token is required');
    }
    
    $oauthToken = $input['oauth_token'];
    
    if (empty($oauthToken)) {
        throw new Exception('OAuth token cannot be empty');
    }
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查暫存資料是否存在
    $stmt = $db->query(
        "SELECT id FROM oauth_temp_users WHERE token = ?",
        [$oauthToken]
    );
    
    $tempUser = $stmt->fetch();
    
    if (!$tempUser) {
        // 暫存資料不存在，視為成功（可能已經被清理）
        echo json_encode([
            'success' => true,
            'message' => 'OAuth temp data already cleaned up or not found'
        ]);
        exit;
    }
    
    // 刪除暫存資料
    $stmt = $db->query(
        "DELETE FROM oauth_temp_users WHERE token = ?",
        [$oauthToken]
    );
    
    if ($stmt->rowCount() > 0) {
        error_log("OAuth temp data cleaned up successfully for token: $oauthToken");
        echo json_encode([
            'success' => true,
            'message' => 'OAuth temp data cleaned up successfully'
        ]);
    } else {
        throw new Exception('Failed to clean up OAuth temp data');
    }
    
} catch (Exception $e) {
    error_log("OAuth temp cleanup error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
