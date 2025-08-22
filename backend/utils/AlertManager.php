<?php
/**
 * 警報管理器
 * 處理系統警報和通知
 */

require_once __DIR__ . '/Logger.php';

class AlertManager {
    
    // 警報類型
    const TYPE_ERROR_RATE = 'error_rate';
    const TYPE_CONSECUTIVE_5XX = 'consecutive_5xx';
    const TYPE_PERFORMANCE = 'performance';
    const TYPE_SECURITY = 'security';
    
    // 警報級別
    const LEVEL_INFO = 'info';
    const LEVEL_WARNING = 'warning';
    const LEVEL_CRITICAL = 'critical';
    const LEVEL_EMERGENCY = 'emergency';
    
    private static $alertDir = null;
    
    /**
     * 初始化警報目錄
     */
    private static function initAlertDir() {
        if (self::$alertDir === null) {
            self::$alertDir = __DIR__ . '/../storage/alerts';
            if (!is_dir(self::$alertDir)) {
                mkdir(self::$alertDir, 0755, true);
            }
        }
    }
    
    /**
     * 發送警報
     */
    public static function sendAlert($type, $level, $message, $context = []) {
        self::initAlertDir();
        
        $alert = [
            'id' => self::generateAlertId(),
            'timestamp' => date('Y-m-d H:i:s'),
            'type' => $type,
            'level' => $level,
            'message' => $message,
            'context' => $context,
            'status' => 'active',
            'sent_notifications' => []
        ];
        
        // 保存警報記錄
        self::saveAlert($alert);
        
        // 記錄到日誌
        Logger::log(Logger::LEVEL_WARNING, "Alert: $message", [
            'alert_id' => $alert['id'],
            'alert_type' => $type,
            'alert_level' => $level,
            'context' => $context
        ], Logger::TYPE_SECURITY);
        
        // 根據級別決定通知方式
        switch ($level) {
            case self::LEVEL_EMERGENCY:
                self::sendEmergencyNotification($alert);
                break;
            case self::LEVEL_CRITICAL:
                self::sendCriticalNotification($alert);
                break;
            case self::LEVEL_WARNING:
                self::sendWarningNotification($alert);
                break;
            default:
                self::sendInfoNotification($alert);
        }
        
        return $alert['id'];
    }
    
    /**
     * 檢查連續 5xx 錯誤
     */
    public static function checkConsecutive5xxErrors($threshold = 5) {
        $logFile = __DIR__ . '/../storage/logs/response.log';
        
        if (!file_exists($logFile)) {
            return false;
        }
        
        $lines = file($logFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        $lines = array_reverse($lines); // 最新的在前
        
        $consecutiveCount = 0;
        $errors = [];
        $cutoffTime = time() - (60 * 60); // 最近 1 小時
        
        foreach ($lines as $line) {
            $entry = json_decode($line, true);
            if (!$entry || !isset($entry['context']['status_code'])) continue;
            
            $entryTime = strtotime($entry['timestamp']);
            if ($entryTime < $cutoffTime) break;
            
            $statusCode = $entry['context']['status_code'];
            
            if ($statusCode >= 500) {
                $consecutiveCount++;
                $errors[] = $entry;
            } else {
                // 遇到非 5xx 錯誤，重置計數
                break;
            }
        }
        
        if ($consecutiveCount >= $threshold) {
            $alertId = self::sendAlert(
                self::TYPE_CONSECUTIVE_5XX,
                $consecutiveCount >= 10 ? self::LEVEL_EMERGENCY : self::LEVEL_CRITICAL,
                "連續 {$consecutiveCount} 個 5xx 錯誤",
                [
                    'consecutive_count' => $consecutiveCount,
                    'threshold' => $threshold,
                    'recent_errors' => array_slice($errors, 0, 3)
                ]
            );
            
            return $alertId;
        }
        
        return false;
    }
    
    /**
     * 檢查錯誤率
     */
    public static function checkErrorRate($threshold = 5.0) {
        $errorStats = Logger::getStats(Logger::TYPE_ERROR, 1);
        $responseStats = Logger::getStats(Logger::TYPE_RESPONSE, 1);
        
        if ($responseStats['total_entries'] == 0) {
            return false;
        }
        
        $errorRate = ($errorStats['error_count'] / $responseStats['total_entries']) * 100;
        
        if ($errorRate > $threshold) {
            $level = $errorRate > 20 ? self::LEVEL_CRITICAL : self::LEVEL_WARNING;
            
            $alertId = self::sendAlert(
                self::TYPE_ERROR_RATE,
                $level,
                "錯誤率過高: {$errorRate}%",
                [
                    'error_rate' => $errorRate,
                    'threshold' => $threshold,
                    'error_count' => $errorStats['error_count'],
                    'total_requests' => $responseStats['total_entries']
                ]
            );
            
            return $alertId;
        }
        
        return false;
    }
    
    /**
     * 生成警報 ID
     */
    private static function generateAlertId() {
        return 'alert_' . date('Ymd_His') . '_' . substr(md5(uniqid()), 0, 8);
    }
    
    /**
     * 保存警報記錄
     */
    private static function saveAlert($alert) {
        $alertFile = self::$alertDir . '/' . $alert['id'] . '.json';
        file_put_contents($alertFile, json_encode($alert, JSON_PRETTY_PRINT));
        
        // 也保存到總警報日誌
        $logFile = self::$alertDir . '/alerts.log';
        file_put_contents($logFile, json_encode($alert) . "\n", FILE_APPEND | LOCK_EX);
    }
    
    /**
     * 發送緊急通知
     */
    private static function sendEmergencyNotification($alert) {
        // 記錄到系統日誌
        error_log("🚨 EMERGENCY ALERT: {$alert['message']}");
        
        // TODO: 實現實際通知機制
        // 例如：SMS、電話、即時通訊等
        
        $alert['sent_notifications'][] = [
            'type' => 'system_log',
            'timestamp' => date('Y-m-d H:i:s'),
            'status' => 'sent'
        ];
        
        self::saveAlert($alert);
    }
    
    /**
     * 發送關鍵通知
     */
    private static function sendCriticalNotification($alert) {
        // 記錄到系統日誌
        error_log("🔥 CRITICAL ALERT: {$alert['message']}");
        
        // TODO: 實現郵件通知
        // self::sendEmail($alert);
        
        // TODO: 實現 Slack 通知
        // self::sendSlackNotification($alert);
        
        $alert['sent_notifications'][] = [
            'type' => 'system_log',
            'timestamp' => date('Y-m-d H:i:s'),
            'status' => 'sent'
        ];
        
        self::saveAlert($alert);
    }
    
    /**
     * 發送警告通知
     */
    private static function sendWarningNotification($alert) {
        // 記錄到系統日誌
        error_log("⚠️ WARNING ALERT: {$alert['message']}");
        
        $alert['sent_notifications'][] = [
            'type' => 'system_log',
            'timestamp' => date('Y-m-d H:i:s'),
            'status' => 'sent'
        ];
        
        self::saveAlert($alert);
    }
    
    /**
     * 發送信息通知
     */
    private static function sendInfoNotification($alert) {
        // 記錄到系統日誌
        error_log("ℹ️ INFO ALERT: {$alert['message']}");
        
        $alert['sent_notifications'][] = [
            'type' => 'system_log',
            'timestamp' => date('Y-m-d H:i:s'),
            'status' => 'sent'
        ];
        
        self::saveAlert($alert);
    }
    
    /**
     * 獲取活躍警報
     */
    public static function getActiveAlerts() {
        self::initAlertDir();
        
        $alerts = [];
        $files = glob(self::$alertDir . '/alert_*.json');
        
        foreach ($files as $file) {
            $alert = json_decode(file_get_contents($file), true);
            if ($alert && $alert['status'] === 'active') {
                $alerts[] = $alert;
            }
        }
        
        // 按時間排序（最新的在前）
        usort($alerts, function($a, $b) {
            return strtotime($b['timestamp']) - strtotime($a['timestamp']);
        });
        
        return $alerts;
    }
    
    /**
     * 解決警報
     */
    public static function resolveAlert($alertId, $resolvedBy = 'system') {
        $alertFile = self::$alertDir . '/' . $alertId . '.json';
        
        if (file_exists($alertFile)) {
            $alert = json_decode(file_get_contents($alertFile), true);
            $alert['status'] = 'resolved';
            $alert['resolved_at'] = date('Y-m-d H:i:s');
            $alert['resolved_by'] = $resolvedBy;
            
            self::saveAlert($alert);
            
            Logger::log(Logger::LEVEL_INFO, "Alert resolved: {$alert['message']}", [
                'alert_id' => $alertId,
                'resolved_by' => $resolvedBy
            ], Logger::TYPE_SECURITY);
            
            return true;
        }
        
        return false;
    }
    
    /**
     * 清理舊警報
     */
    public static function cleanup($daysToKeep = 30) {
        self::initAlertDir();
        
        $cutoffTime = time() - ($daysToKeep * 24 * 60 * 60);
        $files = glob(self::$alertDir . '/alert_*.json');
        $cleaned = 0;
        
        foreach ($files as $file) {
            if (filemtime($file) < $cutoffTime) {
                unlink($file);
                $cleaned++;
            }
        }
        
        return $cleaned;
    }
}
