<?php
/**
 * API 錯誤碼定義
 * 統一的錯誤碼系統
 */

class ErrorCodes {
    
    // 成功碼
    const SUCCESS = 'SUCCESS';
    
    // 通用錯誤碼 (1000-1999)
    const INVALID_REQUEST = 'E1001';
    const INVALID_JSON = 'E1002';
    const MISSING_PARAMETER = 'E1003';
    const INVALID_PARAMETER = 'E1004';
    const METHOD_NOT_ALLOWED = 'E1005';
    const INTERNAL_SERVER_ERROR = 'E1006';
    
    // 認證相關錯誤碼 (2000-2999)
    const UNAUTHORIZED = 'E2001';
    const INVALID_TOKEN = 'E2002';
    const TOKEN_EXPIRED = 'E2003';
    const TOKEN_REVOKED = 'E2004';
    const INSUFFICIENT_PERMISSION = 'E2005';
    const LOGIN_FAILED = 'E2006';
    const ACCOUNT_LOCKED = 'E2007';
    const ACCOUNT_SUSPENDED = 'E2008';
    const ACCOUNT_DELETED = 'E2009';
    
    // 用戶相關錯誤碼 (3000-3999)
    const USER_NOT_FOUND = 'E3001';
    const USER_ALREADY_EXISTS = 'E3002';
    const EMAIL_ALREADY_EXISTS = 'E3003';
    const INVALID_EMAIL = 'E3004';
    const INVALID_PASSWORD = 'E3005';
    const PASSWORD_TOO_WEAK = 'E3006';
    const USER_NOT_VERIFIED = 'E3007';
    const VERIFICATION_FAILED = 'E3008';
    
    // 任務相關錯誤碼 (4000-4999)
    const TASK_NOT_FOUND = 'E4001';
    const TASK_ACCESS_DENIED = 'E4002';
    const TASK_STATUS_INVALID = 'E4003';
    const TASK_ALREADY_APPLIED = 'E4004';
    const TASK_APPLICATION_NOT_FOUND = 'E4005';
    const TASK_CANNOT_APPLY_OWN = 'E4006';
    const TASK_POINTS_INSUFFICIENT = 'E4007';
    const TASK_EXPIRED = 'E4008';
    
    // 聊天相關錯誤碼 (5000-5999)
    const CHAT_ROOM_NOT_FOUND = 'E5001';
    const CHAT_ACCESS_DENIED = 'E5002';
    const MESSAGE_TOO_LONG = 'E5003';
    const FILE_UPLOAD_FAILED = 'E5004';
    const FILE_TOO_LARGE = 'E5005';
    const FILE_TYPE_NOT_ALLOWED = 'E5006';
    
    // 節流相關錯誤碼 (6000-6999)
    const RATE_LIMIT_EXCEEDED = 'E6001';
    const TOO_MANY_REQUESTS = 'E6002';
    const DAILY_LIMIT_EXCEEDED = 'E6003';
    
    // 業務邏輯錯誤碼 (7000-7999)
    const DUPLICATE_OPERATION = 'E7001';
    const OPERATION_NOT_ALLOWED = 'E7002';
    const RESOURCE_CONFLICT = 'E7003';
    const QUOTA_EXCEEDED = 'E7004';
    const FEATURE_DISABLED = 'E7005';
    
    // 第三方服務錯誤碼 (8000-8999)
    const OAUTH_ERROR = 'E8001';
    const PAYMENT_ERROR = 'E8002';
    const EMAIL_SERVICE_ERROR = 'E8003';
    const SMS_SERVICE_ERROR = 'E8004';
    
    // 資料驗證錯誤碼 (9000-9999)
    const VALIDATION_FAILED = 'E9001';
    const INVALID_FORMAT = 'E9002';
    const VALUE_OUT_OF_RANGE = 'E9003';
    const REQUIRED_FIELD_MISSING = 'E9004';
    
    /**
     * 錯誤碼對應的預設訊息
     */
    private static $messages = [
        // 成功
        self::SUCCESS => 'Operation completed successfully',
        
        // 通用錯誤
        self::INVALID_REQUEST => '無效的請求',
        self::INVALID_JSON => '無效的 JSON 格式',
        self::MISSING_PARAMETER => '缺少必要參數',
        self::INVALID_PARAMETER => '參數格式錯誤',
        self::METHOD_NOT_ALLOWED => '不支援的請求方法',
        self::INTERNAL_SERVER_ERROR => '伺服器內部錯誤',
        
        // 認證相關
        self::UNAUTHORIZED => '未授權訪問',
        self::INVALID_TOKEN => '無效的認證令牌',
        self::TOKEN_EXPIRED => '認證令牌已過期',
        self::TOKEN_REVOKED => '認證令牌已撤銷',
        self::INSUFFICIENT_PERMISSION => '權限不足',
        self::LOGIN_FAILED => '登入失敗',
        self::ACCOUNT_LOCKED => '帳號已鎖定',
        self::ACCOUNT_SUSPENDED => '帳號已停用',
        self::ACCOUNT_DELETED => '帳號已刪除',
        
        // 用戶相關
        self::USER_NOT_FOUND => '用戶不存在',
        self::USER_ALREADY_EXISTS => '用戶已存在',
        self::EMAIL_ALREADY_EXISTS => '電子郵件已被使用',
        self::INVALID_EMAIL => '無效的電子郵件格式',
        self::INVALID_PASSWORD => '密碼錯誤',
        self::PASSWORD_TOO_WEAK => '密碼強度不足',
        self::USER_NOT_VERIFIED => '用戶未驗證',
        self::VERIFICATION_FAILED => '驗證失敗',
        
        // 任務相關
        self::TASK_NOT_FOUND => '任務不存在',
        self::TASK_ACCESS_DENIED => '無權限訪問此任務',
        self::TASK_STATUS_INVALID => '任務狀態無效',
        self::TASK_ALREADY_APPLIED => '已申請過此任務',
        self::TASK_APPLICATION_NOT_FOUND => '申請記錄不存在',
        self::TASK_CANNOT_APPLY_OWN => '不能申請自己的任務',
        self::TASK_POINTS_INSUFFICIENT => '點數不足',
        self::TASK_EXPIRED => '任務已過期',
        
        // 聊天相關
        self::CHAT_ROOM_NOT_FOUND => '聊天室不存在',
        self::CHAT_ACCESS_DENIED => '無權限訪問此聊天室',
        self::MESSAGE_TOO_LONG => '訊息過長',
        self::FILE_UPLOAD_FAILED => '檔案上傳失敗',
        self::FILE_TOO_LARGE => '檔案過大',
        self::FILE_TYPE_NOT_ALLOWED => '不支援的檔案類型',
        
        // 節流相關
        self::RATE_LIMIT_EXCEEDED => '請求過於頻繁',
        self::TOO_MANY_REQUESTS => '請求次數過多',
        self::DAILY_LIMIT_EXCEEDED => '已達每日限制',
        
        // 業務邏輯
        self::DUPLICATE_OPERATION => '重複操作',
        self::OPERATION_NOT_ALLOWED => '不允許的操作',
        self::RESOURCE_CONFLICT => '資源衝突',
        self::QUOTA_EXCEEDED => '配額已滿',
        self::FEATURE_DISABLED => '功能已停用',
        
        // 第三方服務
        self::OAUTH_ERROR => '第三方登入錯誤',
        self::PAYMENT_ERROR => '支付處理錯誤',
        self::EMAIL_SERVICE_ERROR => '郵件服務錯誤',
        self::SMS_SERVICE_ERROR => '簡訊服務錯誤',
        
        // 資料驗證
        self::VALIDATION_FAILED => '資料驗證失敗',
        self::INVALID_FORMAT => '格式錯誤',
        self::VALUE_OUT_OF_RANGE => '數值超出範圍',
        self::REQUIRED_FIELD_MISSING => '必填欄位缺失',
    ];
    
    /**
     * 錯誤碼對應的 HTTP 狀態碼
     */
    private static $httpCodes = [
        // 成功
        self::SUCCESS => 200,
        
        // 通用錯誤 - 400 Bad Request
        self::INVALID_REQUEST => 400,
        self::INVALID_JSON => 400,
        self::MISSING_PARAMETER => 400,
        self::INVALID_PARAMETER => 400,
        self::METHOD_NOT_ALLOWED => 405,
        self::INTERNAL_SERVER_ERROR => 500,
        
        // 認證相關 - 401 Unauthorized / 403 Forbidden
        self::UNAUTHORIZED => 401,
        self::INVALID_TOKEN => 401,
        self::TOKEN_EXPIRED => 401,
        self::TOKEN_REVOKED => 401,
        self::INSUFFICIENT_PERMISSION => 403,
        self::LOGIN_FAILED => 401,
        self::ACCOUNT_LOCKED => 403,
        self::ACCOUNT_SUSPENDED => 403,
        self::ACCOUNT_DELETED => 403,
        
        // 用戶相關 - 404 Not Found / 409 Conflict
        self::USER_NOT_FOUND => 404,
        self::USER_ALREADY_EXISTS => 409,
        self::EMAIL_ALREADY_EXISTS => 409,
        self::INVALID_EMAIL => 400,
        self::INVALID_PASSWORD => 400,
        self::PASSWORD_TOO_WEAK => 400,
        self::USER_NOT_VERIFIED => 403,
        self::VERIFICATION_FAILED => 400,
        
        // 任務相關 - 404 Not Found / 403 Forbidden / 409 Conflict
        self::TASK_NOT_FOUND => 404,
        self::TASK_ACCESS_DENIED => 403,
        self::TASK_STATUS_INVALID => 400,
        self::TASK_ALREADY_APPLIED => 409,
        self::TASK_APPLICATION_NOT_FOUND => 404,
        self::TASK_CANNOT_APPLY_OWN => 403,
        self::TASK_POINTS_INSUFFICIENT => 402,
        self::TASK_EXPIRED => 410,
        
        // 聊天相關 - 404 Not Found / 403 Forbidden / 413 Payload Too Large
        self::CHAT_ROOM_NOT_FOUND => 404,
        self::CHAT_ACCESS_DENIED => 403,
        self::MESSAGE_TOO_LONG => 413,
        self::FILE_UPLOAD_FAILED => 500,
        self::FILE_TOO_LARGE => 413,
        self::FILE_TYPE_NOT_ALLOWED => 415,
        
        // 節流相關 - 429 Too Many Requests
        self::RATE_LIMIT_EXCEEDED => 429,
        self::TOO_MANY_REQUESTS => 429,
        self::DAILY_LIMIT_EXCEEDED => 429,
        
        // 業務邏輯 - 409 Conflict / 403 Forbidden
        self::DUPLICATE_OPERATION => 409,
        self::OPERATION_NOT_ALLOWED => 403,
        self::RESOURCE_CONFLICT => 409,
        self::QUOTA_EXCEEDED => 429,
        self::FEATURE_DISABLED => 503,
        
        // 第三方服務 - 502 Bad Gateway / 503 Service Unavailable
        self::OAUTH_ERROR => 502,
        self::PAYMENT_ERROR => 502,
        self::EMAIL_SERVICE_ERROR => 503,
        self::SMS_SERVICE_ERROR => 503,
        
        // 資料驗證 - 422 Unprocessable Entity
        self::VALIDATION_FAILED => 422,
        self::INVALID_FORMAT => 422,
        self::VALUE_OUT_OF_RANGE => 422,
        self::REQUIRED_FIELD_MISSING => 422,
    ];
    
    /**
     * 獲取錯誤碼對應的訊息
     */
    public static function getMessage($code) {
        return self::$messages[$code] ?? 'Unknown error';
    }
    
    /**
     * 獲取錯誤碼對應的 HTTP 狀態碼
     */
    public static function getHttpCode($code) {
        return self::$httpCodes[$code] ?? 500;
    }
    
    /**
     * 檢查是否為有效的錯誤碼
     */
    public static function isValidCode($code) {
        return isset(self::$messages[$code]);
    }
    
    /**
     * 獲取所有錯誤碼
     */
    public static function getAllCodes() {
        return array_keys(self::$messages);
    }
    
    /**
     * 獲取錯誤碼分類
     */
    public static function getCodeCategory($code) {
        if ($code === self::SUCCESS) {
            return 'success';
        }
        
        $prefix = substr($code, 0, 2);
        switch ($prefix) {
            case 'E1': return 'general';
            case 'E2': return 'authentication';
            case 'E3': return 'user';
            case 'E4': return 'task';
            case 'E5': return 'chat';
            case 'E6': return 'rate_limit';
            case 'E7': return 'business_logic';
            case 'E8': return 'third_party';
            case 'E9': return 'validation';
            default: return 'unknown';
        }
    }
}
?>

