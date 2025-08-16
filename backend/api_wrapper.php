<?php
/**
 * MAMP 兼容的 API 包裝器
 * 處理查詢參數中的 token 驗證
 */

// 設置 CORS 頭
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

// 處理 OPTIONS 預檢請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

/**
 * 從各種來源獲取 token
 */
function getTokenFromRequest() {
    // 方法1：從查詢參數獲取
    $token = $_GET['token'] ?? null;
    
    // 方法2：從 POST 數據獲取
    if (!$token && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        $token = $input['token'] ?? null;
    }
    
    // 方法3：從 Authorization 頭獲取（如果有的話）
    if (!$token) {
        $headers = getallheaders();
        if (isset($headers['Authorization'])) {
            $auth = $headers['Authorization'];
            if (strpos($auth, 'Bearer ') === 0) {
                $token = substr($auth, 7);
            }
        }
    }
    
    // 方法4：從自定義頭獲取
    if (!$token) {
        $headers = getallheaders();
        if (isset($headers['X-Auth-Token'])) {
            $token = $headers['X-Auth-Token'];
        }
    }
    
    return $token;
}

/**
 * 驗證 token 並返回用戶 ID
 */
function validateToken($token) {
    if (!$token || empty(trim($token))) {
        return null;
    }
    
    try {
        // 這裡應該調用您的 token 驗證邏輯
        // 暫時返回一個模擬的用戶 ID
        if (strpos($token, 'test_token_') === 0) {
            return 2; // 模擬用戶 ID
        }
        
        // 實際的 token 驗證邏輯
        // $userData = validateJWTToken($token);
        // return $userData['user_id'] ?? null;
        
        return null;
    } catch (Exception $e) {
        error_log("Token validation error: " . $e->getMessage());
        return null;
    }
}

/**
 * 驗證請求並返回用戶 ID
 */
function authenticateRequest() {
    $token = getTokenFromRequest();
    
    if (!$token) {
        $response = [
            'success' => false,
            'message' => 'Authentication required',
            'error_code' => 'AUTH_REQUIRED',
            'timestamp' => date('Y-m-d H:i:s'),
            'usage' => [
                'query_param' => '?token=YOUR_TOKEN',
                'post_body' => '{"token": "YOUR_TOKEN"}',
                'header' => 'Authorization: Bearer YOUR_TOKEN or X-Auth-Token: YOUR_TOKEN'
            ]
        ];
        
        http_response_code(401);
        echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        return null;
    }
    
    $userId = validateToken($token);
    
    if (!$userId) {
        $response = [
            'success' => false,
            'message' => 'Invalid token',
            'error_code' => 'INVALID_TOKEN',
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        http_response_code(401);
        echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        return null;
    }
    
    return $userId;
}

/**
 * 設置響應頭
 */
function setResponseHeaders($statusCode = 200) {
    http_response_code($statusCode);
}

/**
 * 返回成功響應
 */
function returnSuccessResponse($data, $message = 'Success') {
    setResponseHeaders(200);
    $response = [
        'success' => true,
        'message' => $message,
        'data' => $data,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}

/**
 * 返回錯誤響應
 */
function returnErrorResponse($message, $errorCode = 'ERROR', $statusCode = 400) {
    setResponseHeaders($statusCode);
    $response = [
        'success' => false,
        'message' => $message,
        'error_code' => $errorCode,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
