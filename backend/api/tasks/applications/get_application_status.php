<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../../../../config/database.php';
require_once '../../../../utils/JWTManager.php';

try {
    // 驗證 JWT token
    $token = null;
    $headers = apache_request_headers();
    
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
        if (strpos($authHeader, 'Bearer ') === 0) {
            $token = substr($authHeader, 7);
        }
    }
    
    if (!$token) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => '未提供認證令牌']);
        exit;
    }
    
    $decoded = JWTManager::validateToken($token);
    if (!$decoded) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => '無效的認證令牌']);
        exit;
    }
    
    $currentUserId = $decoded['user_id'];
    
    // 獲取查詢參數
    $roomId = $_GET['room_id'] ?? '';
    $taskId = $_GET['task_id'] ?? '';
    $participantId = $_GET['participant_id'] ?? '';
    
    if (empty($roomId) || empty($taskId) || empty($participantId)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => '缺少必要參數']);
        exit;
    }
    
    // 驗證用戶是否有權限訪問此聊天室
    $db = new Database();
    $pdo = $db->getConnection();
    
    // 檢查聊天室權限
    $stmt = $pdo->prepare("
        SELECT creator_id, participant_id 
        FROM chat_rooms 
        WHERE id = ? AND (creator_id = ? OR participant_id = ?)
    ");
    $stmt->execute([$roomId, $currentUserId, $currentUserId]);
    $room = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$room) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => '您沒有權限訪問此聊天室']);
        exit;
    }
    
    // 檢查應徵狀態
    $stmt = $pdo->prepare("
        SELECT status 
        FROM task_applications 
        WHERE task_id = ? AND user_id = ?
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    $stmt->execute([$taskId, $participantId]);
    $application = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$application) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'not found']);
        exit;
    }
    
    // 返回應徵狀態
    echo json_encode([
        'success' => true,
        'data' => [
            'status' => $application['status'],
            'task_id' => $taskId,
            'user_id' => $participantId,
            'room_id' => $roomId
        ]
    ]);
    
} catch (Exception $e) {
    error_log("get_application_status.php error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => '伺服器內部錯誤']);
}
?>
