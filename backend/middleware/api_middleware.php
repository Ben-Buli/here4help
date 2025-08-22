<?php
/**
 * API 中介層
 * 統一處理 CORS、節流、認證等
 */

require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../utils/RateLimiter.php';
require_once __DIR__ . '/../config/env_loader.php';

class ApiMiddleware {
    
    /**
     * 執行所有中介層檢查
     */
    public static function handle($options = []) {
        // 載入環境變數
        EnvLoader::load();
        
        // 1. 設定 CORS 標頭
        self::handleCors();
        
        // 2. 檢查節流限制
        if (!isset($options['skip_rate_limit']) || !$options['skip_rate_limit']) {
            self::handleRateLimit();
        }
        
        // 3. 安全標頭
        self::setSecurityHeaders();
        
        // 4. 錯誤處理設定
        self::setupErrorHandling();
    }
    
    /**
     * 處理 CORS
     */
    private static function handleCors() {
        CorsConfig::setCorsHeaders();
    }
    
    /**
     * 處理節流限制
     */
    private static function handleRateLimit() {
        $endpoint = $_SERVER['REQUEST_URI'] ?? '';
        
        // 移除查詢參數，只保留路徑
        if (strpos($endpoint, '?') !== false) {
            $endpoint = substr($endpoint, 0, strpos($endpoint, '?'));
        }
        
        RateLimiter::middleware($endpoint);
    }
    
    /**
     * 設定安全標頭
     */
    private static function setSecurityHeaders() {
        // 防止 MIME 類型嗅探
        header('X-Content-Type-Options: nosniff');
        
        // 防止點擊劫持
        header('X-Frame-Options: DENY');
        
        // XSS 保護
        header('X-XSS-Protection: 1; mode=block');
        
        // 引用者政策
        header('Referrer-Policy: strict-origin-when-cross-origin');
        
        // 內容安全政策（基本）
        $env = $_ENV['APP_ENV'] ?? 'development';
        if ($env === 'production') {
            header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;");
        }
        
        // HSTS（僅 HTTPS）
        if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
            header('Strict-Transport-Security: max-age=31536000; includeSubDomains');
        }
    }
    
    /**
     * 設定錯誤處理
     */
    private static function setupErrorHandling() {
        // 設定錯誤報告等級
        $env = $_ENV['APP_ENV'] ?? 'development';
        
        if ($env === 'production') {
            error_reporting(0);
            ini_set('display_errors', 0);
            ini_set('log_errors', 1);
            ini_set('error_log', __DIR__ . '/../storage/logs/php_errors.log');
        } else {
            error_reporting(E_ALL);
            ini_set('display_errors', 1);
        }
        
        // 設定自定義錯誤處理器
        set_error_handler([self::class, 'errorHandler']);
        set_exception_handler([self::class, 'exceptionHandler']);
    }
    
    /**
     * 自定義錯誤處理器
     */
    public static function errorHandler($severity, $message, $file, $line) {
        $env = $_ENV['APP_ENV'] ?? 'development';
        
        // 記錄錯誤
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'type' => 'error',
            'severity' => $severity,
            'message' => $message,
            'file' => $file,
            'line' => $line,
            'request_uri' => $_SERVER['REQUEST_URI'] ?? '',
            'method' => $_SERVER['REQUEST_METHOD'] ?? '',
            'ip' => $_SERVER['REMOTE_ADDR'] ?? ''
        ];
        
        self::logError($logEntry);
        
        // 在開發環境顯示錯誤，生產環境隱藏
        if ($env !== 'production') {
            return false; // 讓 PHP 預設錯誤處理器處理
        }
        
        return true; // 阻止 PHP 預設錯誤處理器
    }
    
    /**
     * 自定義異常處理器
     */
    public static function exceptionHandler($exception) {
        $env = $_ENV['APP_ENV'] ?? 'development';
        
        // 記錄異常
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'type' => 'exception',
            'message' => $exception->getMessage(),
            'file' => $exception->getFile(),
            'line' => $exception->getLine(),
            'trace' => $exception->getTraceAsString(),
            'request_uri' => $_SERVER['REQUEST_URI'] ?? '',
            'method' => $_SERVER['REQUEST_METHOD'] ?? '',
            'ip' => $_SERVER['REMOTE_ADDR'] ?? ''
        ];
        
        self::logError($logEntry);
        
        // 回應錯誤
        header('HTTP/1.1 500 Internal Server Error');
        header('Content-Type: application/json');
        
        if ($env === 'production') {
            echo json_encode([
                'success' => false,
                'error' => 'INTERNAL_SERVER_ERROR',
                'message' => '伺服器內部錯誤，請稍後再試'
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'INTERNAL_SERVER_ERROR',
                'message' => $exception->getMessage(),
                'file' => $exception->getFile(),
                'line' => $exception->getLine(),
                'trace' => explode("\n", $exception->getTraceAsString())
            ]);
        }
        
        exit;
    }
    
    /**
     * 記錄錯誤到檔案
     */
    private static function logError($logEntry) {
        $logDir = __DIR__ . '/../storage/logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $logFile = $logDir . '/api_errors.log';
        file_put_contents($logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
    }
    
    /**
     * 驗證 JWT Token
     */
    public static function validateJWT($required = true) {
        require_once __DIR__ . '/../utils/JWTManager.php';
        
        try {
            // 獲取 token
            $token = self::getTokenFromRequest();
            
            if (!$token) {
                if ($required) {
                    self::respondUnauthorized('Token required');
                }
                return null;
            }
            
            // 驗證 token
            $payload = JWTManager::validateToken($token);
            
            if (!$payload) {
                if ($required) {
                    self::respondUnauthorized('Invalid token');
                }
                return null;
            }
            
            return $payload;
            
        } catch (Exception $e) {
            if ($required) {
                self::respondUnauthorized('Token validation failed: ' . $e->getMessage());
            }
            return null;
        }
    }
    
    /**
     * 從請求中獲取 token
     */
    private static function getTokenFromRequest() {
        // Authorization header
        $headers = getallheaders();
        if (isset($headers['Authorization'])) {
            $auth = $headers['Authorization'];
            if (strpos($auth, 'Bearer ') === 0) {
                return substr($auth, 7);
            }
        }
        
        // Query parameter
        if (isset($_GET['token'])) {
            return $_GET['token'];
        }
        
        // POST data
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $input = json_decode(file_get_contents('php://input'), true);
            if (isset($input['token'])) {
                return $input['token'];
            }
        }
        
        // Custom header
        if (isset($headers['X-Auth-Token'])) {
            return $headers['X-Auth-Token'];
        }
        
        return null;
    }
    
    /**
     * 回應未授權錯誤
     */
    private static function respondUnauthorized($message = 'Unauthorized') {
        header('HTTP/1.1 401 Unauthorized');
        header('Content-Type: application/json');
        
        echo json_encode([
            'success' => false,
            'error' => 'UNAUTHORIZED',
            'message' => $message
        ]);
        
        exit;
    }
    
    /**
     * 檢查用戶權限
     */
    public static function checkPermission($requiredPermission, $userPayload = null) {
        if (!$userPayload) {
            $userPayload = self::validateJWT(true);
        }
        
        $userPermission = $userPayload['permission'] ?? 0;
        
        if ($userPermission < $requiredPermission) {
            header('HTTP/1.1 403 Forbidden');
            header('Content-Type: application/json');
            
            echo json_encode([
                'success' => false,
                'error' => 'INSUFFICIENT_PERMISSION',
                'message' => '權限不足',
                'required_permission' => $requiredPermission,
                'user_permission' => $userPermission
            ]);
            
            exit;
        }
        
        return true;
    }
}
?>
