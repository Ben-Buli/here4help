<?php
/**
 * TraceId 生成器
 * 用於追蹤 API 請求的唯一識別符
 */

class TraceId {
    
    private static $currentTraceId = null;
    
    /**
     * 生成新的 TraceId
     */
    public static function generate() {
        // 格式：timestamp(8) + random(8) + process_id(4)
        $timestamp = dechex(time());
        $random = bin2hex(random_bytes(4));
        $processId = str_pad(dechex(getmypid()), 4, '0', STR_PAD_LEFT);
        
        return strtoupper($timestamp . $random . $processId);
    }
    
    /**
     * 獲取當前請求的 TraceId
     */
    public static function current() {
        if (self::$currentTraceId === null) {
            self::$currentTraceId = self::generate();
        }
        return self::$currentTraceId;
    }
    
    /**
     * 設定當前請求的 TraceId
     */
    public static function set($traceId) {
        self::$currentTraceId = $traceId;
    }
    
    /**
     * 從請求標頭獲取 TraceId
     */
    public static function fromRequest() {
        // 檢查是否有客戶端傳遞的 TraceId
        $headers = getallheaders();
        
        // 常見的 TraceId 標頭名稱
        $traceHeaders = [
            'X-Trace-Id',
            'X-Request-Id', 
            'X-Correlation-Id',
            'Trace-Id',
            'Request-Id'
        ];
        
        foreach ($traceHeaders as $header) {
            if (isset($headers[$header])) {
                $traceId = trim($headers[$header]);
                if (self::isValidTraceId($traceId)) {
                    self::set($traceId);
                    return $traceId;
                }
            }
        }
        
        // 如果沒有有效的 TraceId，生成新的
        return self::current();
    }
    
    /**
     * 驗證 TraceId 格式
     */
    public static function isValidTraceId($traceId) {
        // TraceId 應該是 8-32 字元的十六進制字串
        return preg_match('/^[A-Fa-f0-9]{8,32}$/', $traceId);
    }
    
    /**
     * 解析 TraceId 資訊
     */
    public static function parse($traceId) {
        if (!self::isValidTraceId($traceId)) {
            return null;
        }
        
        // 如果是我們生成的格式（20字元）
        if (strlen($traceId) === 20) {
            $timestamp = hexdec(substr($traceId, 0, 8));
            $random = substr($traceId, 8, 8);
            $processId = hexdec(substr($traceId, 16, 4));
            
            return [
                'timestamp' => $timestamp,
                'datetime' => date('Y-m-d H:i:s', $timestamp),
                'random' => $random,
                'process_id' => $processId,
                'age_seconds' => time() - $timestamp
            ];
        }
        
        return [
            'trace_id' => $traceId,
            'format' => 'external'
        ];
    }
    
    /**
     * 添加 TraceId 到回應標頭
     */
    public static function addToHeaders($traceId = null) {
        $traceId = $traceId ?: self::current();
        header("X-Trace-Id: $traceId");
        header("X-Request-Id: $traceId"); // 備用標頭名稱
    }
    
    /**
     * 記錄 TraceId 到日誌
     */
    public static function log($message, $level = 'INFO', $context = []) {
        $traceId = self::current();
        $timestamp = date('Y-m-d H:i:s');
        
        $logEntry = [
            'timestamp' => $timestamp,
            'trace_id' => $traceId,
            'level' => $level,
            'message' => $message,
            'context' => $context,
            'request_uri' => $_SERVER['REQUEST_URI'] ?? '',
            'method' => $_SERVER['REQUEST_METHOD'] ?? '',
            'ip' => $_SERVER['REMOTE_ADDR'] ?? ''
        ];
        
        // 寫入日誌檔案
        $logDir = __DIR__ . '/../storage/logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $logFile = $logDir . '/trace.log';
        file_put_contents($logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
        
        // 也記錄到 PHP 錯誤日誌
        error_log("[$traceId] $level: $message");
    }
    
    /**
     * 開始請求追蹤
     */
    public static function startRequest() {
        $traceId = self::fromRequest();
        self::addToHeaders($traceId);
        
        // 記錄請求開始
        self::log('Request started', 'INFO', [
            'method' => $_SERVER['REQUEST_METHOD'] ?? '',
            'uri' => $_SERVER['REQUEST_URI'] ?? '',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? '',
            'ip' => $_SERVER['REMOTE_ADDR'] ?? ''
        ]);
        
        return $traceId;
    }
    
    /**
     * 結束請求追蹤
     */
    public static function endRequest($responseCode = null, $responseData = null) {
        $traceId = self::current();
        
        // 記錄請求結束
        self::log('Request completed', 'INFO', [
            'response_code' => $responseCode,
            'response_size' => $responseData ? strlen(json_encode($responseData)) : 0,
            'execution_time' => self::getExecutionTime()
        ]);
        
        return $traceId;
    }
    
    /**
     * 獲取執行時間
     */
    private static function getExecutionTime() {
        if (defined('REQUEST_START_TIME')) {
            return round((microtime(true) - REQUEST_START_TIME) * 1000, 2) . 'ms';
        }
        return 'unknown';
    }
    
    /**
     * 清理舊的追蹤日誌
     */
    public static function cleanupLogs($daysToKeep = 7) {
        $logDir = __DIR__ . '/../storage/logs';
        $logFile = $logDir . '/trace.log';
        
        if (!file_exists($logFile)) {
            return 0;
        }
        
        $cutoffTime = time() - ($daysToKeep * 24 * 60 * 60);
        $lines = file($logFile, FILE_IGNORE_NEW_LINES);
        $keptLines = [];
        $removedCount = 0;
        
        foreach ($lines as $line) {
            $data = json_decode($line, true);
            if ($data && isset($data['timestamp'])) {
                $logTime = strtotime($data['timestamp']);
                if ($logTime >= $cutoffTime) {
                    $keptLines[] = $line;
                } else {
                    $removedCount++;
                }
            } else {
                // 保留無法解析的行
                $keptLines[] = $line;
            }
        }
        
        // 重寫日誌檔案
        file_put_contents($logFile, implode("\n", $keptLines) . "\n");
        
        return $removedCount;
    }
}

// 定義請求開始時間常數
if (!defined('REQUEST_START_TIME')) {
    define('REQUEST_START_TIME', microtime(true));
}
?>
