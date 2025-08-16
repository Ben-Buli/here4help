<?php
/**
 * Authorization 頭輔助函數
 * 解決 MAMP FastCGI 環境下 Authorization 頭不轉發的問題
 */

/**
 * 獲取 Authorization 頭
 * 嘗試多種方法來獲取 Authorization 頭
 */
function getAuthorizationHeader() {
    // 方法1：檢查 $_SERVER['HTTP_AUTHORIZATION']
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        return $_SERVER['HTTP_AUTHORIZATION'];
    }
    
    // 方法2：檢查 $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
    if (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        return $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    }
    
    // 方法3：使用 getallheaders() 函數
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        if (isset($headers['Authorization'])) {
            return $headers['Authorization'];
        }
        // 檢查小寫版本
        if (isset($headers['authorization'])) {
            return $headers['authorization'];
        }
    }
    
    // 方法4：檢查 $_SERVER 中所有以 HTTP_ 開頭的變數
    foreach ($_SERVER as $key => $value) {
        if (strpos($key, 'HTTP_') === 0) {
            $header_name = str_replace('_', '-', strtolower(substr($key, 5)));
            if ($header_name === 'authorization') {
                return $value;
            }
        }
    }
    
    // 方法5：從 Apache 環境變數中讀取
    if (function_exists('apache_getenv')) {
        $auth = apache_getenv('HTTP_AUTHORIZATION');
        if ($auth) {
            return $auth;
        }
    }
    
    // 方法6：檢查 $_ENV 變數
    if (isset($_ENV['HTTP_AUTHORIZATION'])) {
        return $_ENV['HTTP_AUTHORIZATION'];
    }
    
    return null;
}

/**
 * 檢查是否有有效的 Authorization 頭
 */
function hasValidAuthorization() {
    $auth = getAuthorizationHeader();
    if (!$auth) {
        return false;
    }
    
    // 檢查是否是 Bearer token 格式
    if (strpos($auth, 'Bearer ') !== 0) {
        return false;
    }
    
    $token = substr($auth, 7); // 移除 "Bearer " 前綴
    return !empty(trim($token));
}

/**
 * 從 Authorization 頭中提取 token
 */
function extractTokenFromHeader() {
    $auth = getAuthorizationHeader();
    if (!$auth || strpos($auth, 'Bearer ') !== 0) {
        return null;
    }
    
    return trim(substr($auth, 7));
}

/**
 * 設置 CORS 和 Authorization 相關的響應頭
 */
function setAuthResponseHeaders() {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    header('Content-Type: application/json');
    
    // 處理 OPTIONS 預檢請求
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit;
    }
}

/**
 * 驗證 Authorization 並返回響應
 */
function validateAuthorizationAndRespond() {
    setAuthResponseHeaders();
    
    if (!hasValidAuthorization()) {
        $response = [
            'success' => false,
            'message' => 'Authorization header required',
            'error_code' => 'AUTH_HEADER_MISSING',
            'timestamp' => date('Y-m-d H:i:s'),
            'debug_info' => [
                'auth_header_found' => getAuthorizationHeader() !== null,
                'auth_header_value' => getAuthorizationHeader() ? substr(getAuthorizationHeader(), 0, 20) . '...' : null,
                'server_vars' => array_keys($_SERVER),
                'php_version' => PHP_VERSION
            ]
        ];
        
        http_response_code(401);
        echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        return false;
    }
    
    return true;
}
?>
