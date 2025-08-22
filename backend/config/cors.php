<?php
/**
 * CORS 配置管理
 * 根據環境設定不同的跨域白名單
 */

class CorsConfig {
    
    /**
     * 獲取允許的來源列表
     */
    public static function getAllowedOrigins() {
        $env = $_ENV['APP_ENV'] ?? 'development';
        
        switch ($env) {
            case 'production':
                return [
                    'https://here4help.com',
                    'https://www.here4help.com',
                    'https://app.here4help.com'
                ];
                
            case 'staging':
                return [
                    'https://staging.here4help.com',
                    'https://test.here4help.com',
                    'http://localhost:3000',
                    'http://localhost:8080'
                ];
                
            case 'development':
            default:
                return [
                    'http://localhost:3000',
                    'http://localhost:8080',
                    'http://localhost:8081',
                    'http://127.0.0.1:3000',
                    'http://127.0.0.1:8080',
                    'http://127.0.0.1:8081',
                    // ngrok 支援
                    'https://*.ngrok-free.app',
                    'https://*.ngrok.io'
                ];
        }
    }
    
    /**
     * 檢查來源是否被允許
     */
    public static function isOriginAllowed($origin) {
        if (empty($origin)) {
            return false;
        }
        
        $allowedOrigins = self::getAllowedOrigins();
        
        // 直接匹配
        if (in_array($origin, $allowedOrigins)) {
            return true;
        }
        
        // 萬用字元匹配（如 *.ngrok-free.app）
        foreach ($allowedOrigins as $allowed) {
            if (strpos($allowed, '*') !== false) {
                $pattern = str_replace('*', '.*', $allowed);
                if (preg_match('/^' . str_replace('/', '\/', $pattern) . '$/', $origin)) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    /**
     * 設定 CORS 標頭
     */
    public static function setCorsHeaders() {
        $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
        
        // 檢查來源是否被允許
        if (self::isOriginAllowed($origin)) {
            header("Access-Control-Allow-Origin: $origin");
        } else {
            // 開發環境允許所有來源，生產環境拒絕
            $env = $_ENV['APP_ENV'] ?? 'development';
            if ($env === 'development') {
                header('Access-Control-Allow-Origin: *');
            }
        }
        
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-Auth-Token');
        header('Access-Control-Allow-Credentials: true');
        header('Access-Control-Max-Age: 86400'); // 24小時
        header('Content-Type: application/json; charset=utf-8');
        
        // 安全標頭
        header('X-Content-Type-Options: nosniff');
        header('X-Frame-Options: DENY');
        header('X-XSS-Protection: 1; mode=block');
        header('Referrer-Policy: strict-origin-when-cross-origin');
        
        // 處理 OPTIONS 預檢請求
        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            http_response_code(200);
            exit;
        }
    }
    
    /**
     * 獲取允許的方法列表
     */
    public static function getAllowedMethods() {
        return ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'];
    }
    
    /**
     * 獲取允許的標頭列表
     */
    public static function getAllowedHeaders() {
        return [
            'Content-Type',
            'Authorization', 
            'X-Requested-With',
            'X-Auth-Token',
            'Accept',
            'Origin'
        ];
    }
}
?>
