<?php
/**
 * API 節流限制器
 * 防止暴力攻擊和濫用
 */

class RateLimiter {
    
    private static $redisConnection = null;
    private static $useFileStorage = true; // 預設使用檔案儲存
    
    /**
     * 節流規則配置
     */
    private static $rules = [
        'auth' => [
            'requests' => 5,
            'window' => 300, // 5分鐘
            'endpoints' => [
                '/api/auth/login.php',
                '/api/auth/register.php',
                '/api/auth/google-callback.php',
                '/api/auth/facebook-callback.php',
                '/api/auth/apple-callback.php'
            ]
        ],
        'messaging' => [
            'requests' => 30,
            'window' => 60, // 1分鐘
            'endpoints' => [
                '/api/chat/send_message.php',
                '/api/chat/upload_image.php'
            ]
        ],
        'reporting' => [
            'requests' => 3,
            'window' => 3600, // 1小時
            'endpoints' => [
                '/api/tasks/reports.php',
                '/api/support/events.php'
            ]
        ],
        'general' => [
            'requests' => 100,
            'window' => 60, // 1分鐘
            'endpoints' => ['*'] // 所有其他端點
        ]
    ];
    
    /**
     * 檢查是否超過節流限制
     */
    public static function checkLimit($endpoint, $identifier = null) {
        // 獲取客戶端識別符
        if (!$identifier) {
            $identifier = self::getClientIdentifier();
        }
        
        // 獲取適用的規則
        $rule = self::getApplicableRule($endpoint);
        if (!$rule) {
            return true; // 沒有規則，允許通過
        }
        
        // 檢查限制
        $key = self::generateKey($endpoint, $identifier, $rule);
        $currentCount = self::getCurrentCount($key);
        
        if ($currentCount >= $rule['requests']) {
            // 超過限制
            self::logRateLimitExceeded($endpoint, $identifier, $currentCount, $rule);
            return false;
        }
        
        // 增加計數
        self::incrementCount($key, $rule['window']);
        return true;
    }
    
    /**
     * 獲取客戶端識別符
     */
    private static function getClientIdentifier() {
        // 優先使用用戶 ID（如果已認證）
        $userId = self::getUserIdFromToken();
        if ($userId) {
            return "user:$userId";
        }
        
        // 使用 IP 地址
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        
        // 如果是多個 IP（通過代理），取第一個
        if (strpos($ip, ',') !== false) {
            $ip = trim(explode(',', $ip)[0]);
        }
        
        return "ip:$ip";
    }
    
    /**
     * 從 token 獲取用戶 ID
     */
    private static function getUserIdFromToken() {
        try {
            // 嘗試從各種來源獲取 token
            $token = null;
            
            // Authorization header
            $headers = getallheaders();
            if (isset($headers['Authorization'])) {
                $auth = $headers['Authorization'];
                if (strpos($auth, 'Bearer ') === 0) {
                    $token = substr($auth, 7);
                }
            }
            
            // Query parameter
            if (!$token && isset($_GET['token'])) {
                $token = $_GET['token'];
            }
            // POST data
            if (
                !$token &&
                isset($_SERVER) &&
                isset($_SERVER['REQUEST_METHOD']) &&
                $_SERVER['REQUEST_METHOD'] === 'POST'
            ) {
                $input = json_decode(file_get_contents('php://input'), true);
                $token = $input['token'] ?? null;
            }
            if (!$token) {
                return null;
            }
            
            // 簡單的 JWT 解析（不驗證簽名，只取 payload）
            $parts = explode('.', $token);
            if (count($parts) !== 3) {
                return null;
            }
            
            $payload = json_decode(base64_decode($parts[1]), true);
            return $payload['user_id'] ?? null;
            
        } catch (Exception $e) {
            return null;
        }
    }
    
    /**
     * 獲取適用的規則
     */
    private static function getApplicableRule($endpoint) {
        foreach (self::$rules as $ruleName => $rule) {
            foreach ($rule['endpoints'] as $pattern) {
                if ($pattern === '*' || strpos($endpoint, $pattern) !== false) {
                    return $rule;
                }
            }
        }
        return null;
    }
    
    /**
     * 生成快取鍵
     */
    private static function generateKey($endpoint, $identifier, $rule) {
        $window = floor(time() / $rule['window']);
        return "rate_limit:" . md5($endpoint . ':' . $identifier . ':' . $window);
    }
    
    /**
     * 獲取當前計數
     */
    private static function getCurrentCount($key) {
        if (self::$useFileStorage) {
            return self::getFileCount($key);
        } else {
            // Redis 實現（如果有的話）
            return 0;
        }
    }
    
    /**
     * 增加計數
     */
    private static function incrementCount($key, $window) {
        if (self::$useFileStorage) {
            self::incrementFileCount($key, $window);
        } else {
            // Redis 實現（如果有的話）
        }
    }
    
    /**
     * 檔案儲存實現 - 獲取計數
     */
    private static function getFileCount($key) {
        $dir = __DIR__ . '/../storage/rate_limits';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        
        $file = $dir . '/' . $key . '.txt';
        if (!file_exists($file)) {
            return 0;
        }
        
        $content = file_get_contents($file);
        $data = json_decode($content, true);
        
        if (!$data || $data['expires'] < time()) {
            // 過期了，刪除檔案
            unlink($file);
            return 0;
        }
        
        return $data['count'] ?? 0;
    }
    
    /**
     * 檔案儲存實現 - 增加計數
     */
    private static function incrementFileCount($key, $window) {
        $dir = __DIR__ . '/../storage/rate_limits';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        
        $file = $dir . '/' . $key . '.txt';
        $expires = time() + $window;
        
        if (file_exists($file)) {
            $content = file_get_contents($file);
            $data = json_decode($content, true);
            
            if ($data && $data['expires'] >= time()) {
                $data['count']++;
            } else {
                $data = ['count' => 1, 'expires' => $expires];
            }
        } else {
            $data = ['count' => 1, 'expires' => $expires];
        }
        
        file_put_contents($file, json_encode($data));
    }
    
    /**
     * 記錄節流超限事件
     */
    private static function logRateLimitExceeded($endpoint, $identifier, $count, $rule) {
        $logDir = __DIR__ . '/../storage/logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $logFile = $logDir . '/rate_limit.log';
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'endpoint' => $endpoint,
            'identifier' => $identifier,
            'count' => $count,
            'limit' => $rule['requests'],
            'window' => $rule['window'],
            'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
        ];
        
        file_put_contents($logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
    }
    
    /**
     * 清理過期的節流記錄
     */
    public static function cleanup() {
        $dir = __DIR__ . '/../storage/rate_limits';
        if (!is_dir($dir)) {
            return;
        }
        
        $files = glob($dir . '/*.txt');
        $cleaned = 0;
        
        foreach ($files as $file) {
            $content = file_get_contents($file);
            $data = json_decode($content, true);
            
            if (!$data || $data['expires'] < time()) {
                unlink($file);
                $cleaned++;
            }
        }
        
        return $cleaned;
    }
    
    /**
     * 獲取剩餘請求次數
     */
    public static function getRemainingRequests($endpoint, $identifier = null) {
        if (!$identifier) {
            $identifier = self::getClientIdentifier();
        }
        
        $rule = self::getApplicableRule($endpoint);
        if (!$rule) {
            return -1; // 無限制
        }
        
        $key = self::generateKey($endpoint, $identifier, $rule);
        $currentCount = self::getCurrentCount($key);
        
        return max(0, $rule['requests'] - $currentCount);
    }
    
    /**
     * 獲取重置時間
     */
    public static function getResetTime($endpoint, $identifier = null) {
        if (!$identifier) {
            $identifier = self::getClientIdentifier();
        }
        
        $rule = self::getApplicableRule($endpoint);
        if (!$rule) {
            return null;
        }
        
        $window = floor(time() / $rule['window']);
        return ($window + 1) * $rule['window'];
    }
    
    /**
     * 中介層函數 - 檢查並回應節流限制
     */
    public static function middleware($endpoint = null) {
        if (!$endpoint) {
            $endpoint = $_SERVER['REQUEST_URI'] ?? '';
        }
        
        if (!self::checkLimit($endpoint)) {
            $remaining = self::getRemainingRequests($endpoint);
            $resetTime = self::getResetTime($endpoint);
            
            header('HTTP/1.1 429 Too Many Requests');
            header('Content-Type: application/json');
            header('X-RateLimit-Remaining: ' . $remaining);
            header('X-RateLimit-Reset: ' . $resetTime);
            header('Retry-After: ' . ($resetTime - time()));
            
            echo json_encode([
                'success' => false,
                'error' => 'RATE_LIMIT_EXCEEDED',
                'message' => '請求過於頻繁，請稍後再試',
                'retry_after' => $resetTime - time(),
                'remaining_requests' => $remaining
            ]);
            
            exit;
        }
        
        // 添加節流資訊到回應標頭
        $remaining = self::getRemainingRequests($endpoint);
        $resetTime = self::getResetTime($endpoint);
        
        header('X-RateLimit-Remaining: ' . $remaining);
        header('X-RateLimit-Reset: ' . $resetTime);
    }
}
?>
