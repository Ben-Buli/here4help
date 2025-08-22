<?php
/**
 * API 回應工具類
 * 提供統一的 JSON 回應格式 {success, code, message, data, traceId}
 */

require_once __DIR__ . '/ErrorCodes.php';
require_once __DIR__ . '/TraceId.php';
require_once __DIR__ . '/Logger.php';

class Response {
    /**
     * 成功回應
     */
    public static function success($data = null, $message = 'Success', $httpCode = 200) {
        self::respond(true, ErrorCodes::SUCCESS, $message, $data, $httpCode);
    }
    
    /**
     * 錯誤回應（使用錯誤碼）
     */
    public static function error($errorCode, $customMessage = null, $data = null) {
        $message = $customMessage ?: ErrorCodes::getMessage($errorCode);
        $httpCode = ErrorCodes::getHttpCode($errorCode);
        self::respond(false, $errorCode, $message, $data, $httpCode);
    }
    
    /**
     * 錯誤回應（舊版相容）
     */
    public static function errorLegacy($message = 'Error', $httpCode = 400, $data = null) {
        self::respond(false, ErrorCodes::INTERNAL_SERVER_ERROR, $message, $data, $httpCode);
    }
    
    /**
     * 驗證錯誤回應
     */
    public static function validationError($errors, $customMessage = null) {
        self::error(ErrorCodes::VALIDATION_FAILED, $customMessage, $errors);
    }
    
    /**
     * 未授權回應
     */
    public static function unauthorized($customMessage = null) {
        self::error(ErrorCodes::UNAUTHORIZED, $customMessage);
    }
    
    /**
     * 禁止訪問回應
     */
    public static function forbidden($customMessage = null) {
        self::error(ErrorCodes::INSUFFICIENT_PERMISSION, $customMessage);
    }
    
    /**
     * 找不到資源回應
     */
    public static function notFound($customMessage = null) {
        self::error(ErrorCodes::USER_NOT_FOUND, $customMessage);
    }
    
    /**
     * 方法不允許回應
     */
    public static function methodNotAllowed($customMessage = null) {
        self::error(ErrorCodes::METHOD_NOT_ALLOWED, $customMessage);
    }
    
    /**
     * 請求錯誤回應
     */
    public static function badRequest($customMessage = null) {
        self::error(ErrorCodes::INVALID_REQUEST, $customMessage);
    }
    
    /**
     * 伺服器錯誤回應
     */
    public static function serverError($customMessage = null) {
        self::error(ErrorCodes::INTERNAL_SERVER_ERROR, $customMessage);
    }
    
    /**
     * 核心回應方法
     */
    private static function respond($success, $code, $message, $data = null, $httpCode = 200) {
        // 設定 HTTP 狀態碼
        http_response_code($httpCode);
        
        // 獲取或生成 TraceId
        $traceId = TraceId::current();
        TraceId::addToHeaders($traceId);
        
        // 準備回應資料
        $response = [
            'success' => $success,
            'code' => $code,
            'message' => $message,
            'data' => $data,
            'traceId' => $traceId,
            'timestamp' => date('c'), // ISO 8601 格式
            'server_time' => time()
        ];
        
        // 移除 null 值（可選）
        $response = array_filter($response, function($value) {
            return $value !== null;
        });
        
        // 記錄響應日誌
        Logger::logResponse($httpCode, $response, [
            'success' => $success,
            'code' => $code,
            'message' => $message
        ]);
        
        // 記錄回應到追蹤日誌
        TraceId::endRequest($httpCode, $response);
        
        // 輸出 JSON 回應
        echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
    
    /**
     * 設定 CORS 標頭
     */
    public static function setCorsHeaders() {
        // 載入 CORS 配置
        require_once __DIR__ . '/../config/cors.php';
        CorsConfig::setCorsHeaders();
    }
}
?> 