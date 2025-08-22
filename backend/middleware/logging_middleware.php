<?php
/**
 * 日誌中間件
 * 自動記錄所有 API 請求和響應
 */

require_once __DIR__ . '/../utils/Logger.php';
require_once __DIR__ . '/../utils/TraceId.php';
require_once __DIR__ . '/../utils/JWTManager.php';

class LoggingMiddleware {
    
    /**
     * 初始化日誌記錄
     */
    public static function init() {
        // 開始請求追蹤
        $traceId = TraceId::startRequest();
        
        // 獲取用戶 ID（如果已認證）
        $userId = self::getCurrentUserId();
        
        // 記錄請求
        Logger::logRequest($userId, [
            'trace_id' => $traceId
        ]);
        
        // 註冊關閉處理器來記錄響應
        register_shutdown_function([self::class, 'logResponse']);
        
        return $traceId;
    }
    
    /**
     * 記錄響應（在腳本結束時調用）
     */
    public static function logResponse() {
        $statusCode = http_response_code();
        
        // 如果沒有設置狀態碼，默認為 200
        if ($statusCode === false) {
            $statusCode = 200;
        }
        
        Logger::logResponse($statusCode);
        TraceId::endRequest($statusCode);
    }
    
    /**
     * 記錄商務事件
     */
    public static function logBusinessEvent($event, $context = []) {
        $userId = self::getCurrentUserId();
        Logger::logBusiness($event, $userId, $context);
    }
    
    /**
     * 記錄安全事件
     */
    public static function logSecurityEvent($event, $context = []) {
        $userId = self::getCurrentUserId();
        Logger::logSecurity($event, $userId, $context);
    }
    
    /**
     * 記錄錯誤事件
     */
    public static function logError($message, $context = [], $exception = null) {
        Logger::logError($message, $context, $exception);
    }
    
    /**
     * 記錄性能事件
     */
    public static function logPerformance($operation, $startTime, $context = []) {
        $duration = (microtime(true) - $startTime) * 1000; // 轉換為毫秒
        Logger::logPerformance($operation, $duration, $context);
    }
    
    /**
     * 獲取當前用戶 ID
     */
    private static function getCurrentUserId() {
        try {
            // 嘗試從 JWT Token 獲取用戶 ID
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
            if (strpos($authHeader, 'Bearer ') === 0) {
                $token = substr($authHeader, 7);
                $payload = JWTManager::validateToken($token);
                return $payload['user_id'] ?? null;
            }
        } catch (Exception $e) {
            // 忽略認證錯誤，可能是公開 API
        }
        
        return null;
    }
    
    /**
     * 包裝 API 執行，自動記錄錯誤
     */
    public static function wrapApiExecution($callback, $operationName = 'API Operation') {
        $startTime = microtime(true);
        
        try {
            $result = $callback();
            
            // 記錄成功的性能數據
            self::logPerformance($operationName, $startTime, [
                'status' => 'success'
            ]);
            
            return $result;
            
        } catch (Exception $e) {
            // 記錄錯誤
            self::logError("$operationName failed", [
                'operation' => $operationName,
                'execution_time' => (microtime(true) - $startTime) * 1000
            ], $e);
            
            // 重新拋出異常
            throw $e;
        }
    }
    
    /**
     * 記錄 API 調用統計
     */
    public static function logApiStats() {
        $stats = Logger::getStats(null, 1); // 最近 1 小時
        
        Logger::log(Logger::LEVEL_INFO, 'API Statistics', [
            'period' => '1 hour',
            'stats' => $stats
        ], Logger::TYPE_PERFORMANCE);
        
        return $stats;
    }
    
    /**
     * 檢查是否需要發送警報
     */
    public static function checkAlerts() {
        $stats = Logger::getStats(Logger::TYPE_ERROR, 1); // 最近 1 小時的錯誤
        
        // 如果 5xx 錯誤超過閾值，記錄警報事件
        $errorThreshold = 10; // 1 小時內超過 10 個 5xx 錯誤
        
        if ($stats['error_count'] >= $errorThreshold) {
            Logger::log(Logger::LEVEL_CRITICAL, 'High Error Rate Alert', [
                'error_count' => $stats['error_count'],
                'threshold' => $errorThreshold,
                'period' => '1 hour',
                'recent_errors' => array_slice($stats['recent_errors'], 0, 5)
            ], Logger::TYPE_SECURITY);
            
            // 這裡可以添加實際的通知邏輯（郵件、Slack 等）
            self::sendAlert($stats);
        }
    }
    
    /**
     * 發送警報通知（佔位符實現）
     */
    private static function sendAlert($stats) {
        // TODO: 實現實際的通知機制
        // 例如：發送郵件、Slack 通知、推送到監控系統等
        
        error_log("ALERT: High error rate detected - {$stats['error_count']} errors in the last hour");
    }
}

// 自動初始化日誌記錄（如果在 API 上下文中）
if (isset($_SERVER['REQUEST_METHOD']) && !defined('LOGGING_MIDDLEWARE_DISABLED')) {
    LoggingMiddleware::init();
}
