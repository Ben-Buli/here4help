<?php
/**
 * 通知管理器
 * 處理事件→通知矩陣、模板渲染、佇列管理
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../database/database_manager.php';
require_once __DIR__ . '/Logger.php';

class NotificationManager {
    
    private $db;
    private $config;
    
    // 事件類型常數
    const EVENT_TASK = 'task';
    const EVENT_CHAT = 'chat';
    const EVENT_SUPPORT = 'support';
    const EVENT_ADMIN = 'admin';
    
    // 通知類型常數
    const TYPE_PUSH = 'push';
    const TYPE_IN_APP = 'in_app';
    const TYPE_EMAIL = 'email';
    const TYPE_SMS = 'sms';
    
    // 優先級常數
    const PRIORITY_LOW = 'low';
    const PRIORITY_NORMAL = 'normal';
    const PRIORITY_HIGH = 'high';
    const PRIORITY_URGENT = 'urgent';
    
    public function __construct() {
        $this->db = Database::getInstance()->getConnection();
        $this->loadConfig();
    }
    
    /**
     * 載入配置
     */
    private function loadConfig() {
        $envLoader = EnvLoader::getInstance();
        
        $this->config = [
            'fcm_server_key' => $_ENV['FCM_SERVER_KEY'] ?? '',
            'email_from' => $_ENV['NOTIFICATION_EMAIL_FROM'] ?? 'noreply@here4help.com',
            'email_name' => $_ENV['NOTIFICATION_EMAIL_NAME'] ?? 'Here4Help',
            'sms_provider' => $_ENV['SMS_PROVIDER'] ?? 'none',
            'max_queue_size' => $_ENV['NOTIFICATION_MAX_QUEUE_SIZE'] ?? 10000,
            'batch_size' => $_ENV['NOTIFICATION_BATCH_SIZE'] ?? 100,
            'retry_delay' => $_ENV['NOTIFICATION_RETRY_DELAY'] ?? 300, // 5分鐘
        ];
    }
    
    /**
     * 觸發事件通知
     * 
     * @param string $eventType 事件類型
     * @param string $eventAction 事件動作
     * @param array $eventData 事件資料
     * @param array $targetUsers 目標使用者ID陣列
     * @return array 處理結果
     */
    public function triggerEvent($eventType, $eventAction, $eventData = [], $targetUsers = []) {
        try {
            Logger::logBusiness('notification_event_triggered', null, [
                'event_type' => $eventType,
                'event_action' => $eventAction,
                'target_users_count' => count($targetUsers),
                'event_data' => $eventData
            ]);
            
            // 查找匹配的通知事件配置
            $events = $this->getMatchingEvents($eventType, $eventAction, $eventData);
            
            if (empty($events)) {
                Logger::logBusiness('no_notification_events_found', null, [
                    'event_type' => $eventType,
                    'event_action' => $eventAction
                ]);
                return ['success' => true, 'message' => '沒有匹配的通知事件', 'queued' => 0];
            }
            
            $totalQueued = 0;
            
            foreach ($events as $event) {
                $queued = $this->processNotificationEvent($event, $eventData, $targetUsers);
                $totalQueued += $queued;
            }
            
            return [
                'success' => true,
                'message' => "成功處理 {$totalQueued} 個通知",
                'queued' => $totalQueued
            ];
            
        } catch (Exception $e) {
            Logger::logError('notification_event_failed', [], $e);
            return [
                'success' => false,
                'message' => '通知事件處理失敗: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * 查找匹配的通知事件
     */
    private function getMatchingEvents($eventType, $eventAction, $eventData) {
        $sql = "
            SELECT ne.*, nt.title_template, nt.body_template, nt.email_subject_template, 
                   nt.email_body_template, nt.supports_push, nt.supports_in_app, 
                   nt.supports_email, nt.supports_sms, nt.priority as template_priority
            FROM notification_events ne
            JOIN notification_templates nt ON ne.template_key = nt.template_key
            WHERE ne.event_type = ? AND ne.event_action = ? AND ne.is_active = 1 AND nt.is_active = 1
            ORDER BY ne.id
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$eventType, $eventAction]);
        $events = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 過濾符合觸發條件的事件
        $matchingEvents = [];
        foreach ($events as $event) {
            if ($this->checkTriggerConditions($event, $eventData)) {
                $matchingEvents[] = $event;
            }
        }
        
        return $matchingEvents;
    }
    
    /**
     * 檢查觸發條件
     */
    private function checkTriggerConditions($event, $eventData) {
        if (empty($event['trigger_conditions'])) {
            return true; // 沒有條件限制
        }
        
        $conditions = json_decode($event['trigger_conditions'], true);
        if (!$conditions) {
            return true;
        }
        
        // 簡單的條件檢查邏輯
        foreach ($conditions as $key => $expectedValue) {
            if (!isset($eventData[$key]) || $eventData[$key] != $expectedValue) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * 處理單個通知事件
     */
    private function processNotificationEvent($event, $eventData, $targetUsers) {
        $queuedCount = 0;
        
        // 解析目標角色
        $targetRoles = json_decode($event['target_roles'], true) ?? [];
        
        foreach ($targetUsers as $userId) {
            // 檢查使用者角色是否匹配
            if (!empty($targetRoles) && !$this->checkUserRole($userId, $targetRoles, $eventData)) {
                continue;
            }
            
            // 獲取使用者通知偏好
            $preferences = $this->getUserNotificationPreferences($userId);
            
            // 根據支援的通知類型和使用者偏好建立通知
            $notifications = $this->createNotifications($event, $eventData, $userId, $preferences);
            
            foreach ($notifications as $notification) {
                if ($this->queueNotification($notification)) {
                    $queuedCount++;
                }
            }
        }
        
        return $queuedCount;
    }
    
    /**
     * 檢查使用者角色
     */
    private function checkUserRole($userId, $targetRoles, $eventData) {
        // 根據事件資料判斷使用者在此事件中的角色
        $userRole = $this->determineUserRole($userId, $eventData);
        
        return in_array($userRole, $targetRoles) || in_array('all', $targetRoles);
    }
    
    /**
     * 判斷使用者角色
     */
    private function determineUserRole($userId, $eventData) {
        // 根據事件類型和資料判斷角色
        if (isset($eventData['poster_id']) && $eventData['poster_id'] == $userId) {
            return 'poster';
        }
        
        if (isset($eventData['acceptor_id']) && $eventData['acceptor_id'] == $userId) {
            return 'acceptor';
        }
        
        if (isset($eventData['user_id']) && $eventData['user_id'] == $userId) {
            return 'user';
        }
        
        // 檢查是否為管理員
        if ($this->isAdmin($userId)) {
            return 'admin';
        }
        
        return 'user'; // 預設角色
    }
    
    /**
     * 檢查是否為管理員
     */
    private function isAdmin($userId) {
        $sql = "SELECT COUNT(*) FROM users WHERE id = ? AND role = 'admin'";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId]);
        return $stmt->fetchColumn() > 0;
    }
    
    /**
     * 獲取使用者通知偏好
     */
    private function getUserNotificationPreferences($userId) {
        $sql = "
            SELECT * FROM user_notification_preferences 
            WHERE user_id = ?
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$userId]);
        $preferences = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$preferences) {
            // 建立預設偏好
            $preferences = $this->createDefaultPreferences($userId);
        }
        
        return $preferences;
    }
    
    /**
     * 建立預設通知偏好
     */
    private function createDefaultPreferences($userId) {
        $defaultPreferences = [
            'user_id' => $userId,
            'push_enabled' => true,
            'in_app_enabled' => true,
            'email_enabled' => true,
            'sms_enabled' => false,
            'task_preferences' => json_encode([
                'created' => ['push' => true, 'in_app' => true, 'email' => false],
                'accepted' => ['push' => true, 'in_app' => true, 'email' => false],
                'completed' => ['push' => true, 'in_app' => true, 'email' => true],
                'cancelled' => ['push' => true, 'in_app' => true, 'email' => false]
            ]),
            'chat_preferences' => json_encode([
                'new_message' => ['push' => true, 'in_app' => true, 'email' => false]
            ]),
            'support_preferences' => json_encode([
                'created' => ['push' => true, 'in_app' => true, 'email' => true],
                'updated' => ['push' => true, 'in_app' => true, 'email' => false],
                'resolved' => ['push' => true, 'in_app' => true, 'email' => true]
            ]),
            'admin_preferences' => json_encode([
                'system_alert' => ['push' => true, 'in_app' => true, 'email' => true]
            ])
        ];
        
        $sql = "
            INSERT INTO user_notification_preferences 
            (user_id, push_enabled, in_app_enabled, email_enabled, sms_enabled, 
             task_preferences, chat_preferences, support_preferences, admin_preferences)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            $userId,
            $defaultPreferences['push_enabled'],
            $defaultPreferences['in_app_enabled'],
            $defaultPreferences['email_enabled'],
            $defaultPreferences['sms_enabled'],
            $defaultPreferences['task_preferences'],
            $defaultPreferences['chat_preferences'],
            $defaultPreferences['support_preferences'],
            $defaultPreferences['admin_preferences']
        ]);
        
        return $defaultPreferences;
    }
    
    /**
     * 建立通知
     */
    private function createNotifications($event, $eventData, $userId, $preferences) {
        $notifications = [];
        
        // 檢查靜音時段
        if ($this->isInQuietHours($preferences)) {
            // 只建立站內通知
            if ($event['supports_in_app'] && $preferences['in_app_enabled']) {
                $notifications[] = $this->buildNotification(
                    $event, $eventData, $userId, self::TYPE_IN_APP
                );
            }
            return $notifications;
        }
        
        // 根據支援的類型和使用者偏好建立通知
        $types = [
            self::TYPE_PUSH => $event['supports_push'] && $preferences['push_enabled'],
            self::TYPE_IN_APP => $event['supports_in_app'] && $preferences['in_app_enabled'],
            self::TYPE_EMAIL => $event['supports_email'] && $preferences['email_enabled'],
            self::TYPE_SMS => $event['supports_sms'] && $preferences['sms_enabled']
        ];
        
        foreach ($types as $type => $enabled) {
            if ($enabled && $this->checkTypePreference($event, $type, $preferences)) {
                $notifications[] = $this->buildNotification($event, $eventData, $userId, $type);
            }
        }
        
        return $notifications;
    }
    
    /**
     * 檢查是否在靜音時段
     */
    private function isInQuietHours($preferences) {
        if (empty($preferences['quiet_hours_start']) || empty($preferences['quiet_hours_end'])) {
            return false;
        }
        
        $now = new DateTime();
        $currentTime = $now->format('H:i:s');
        $currentDay = $now->format('N'); // 1=Monday, 7=Sunday
        
        // 檢查靜音日期
        if (!empty($preferences['quiet_days'])) {
            $quietDays = json_decode($preferences['quiet_days'], true);
            if (in_array($currentDay, $quietDays)) {
                return true;
            }
        }
        
        // 檢查靜音時段
        $startTime = $preferences['quiet_hours_start'];
        $endTime = $preferences['quiet_hours_end'];
        
        if ($startTime <= $endTime) {
            // 同一天內的時段
            return $currentTime >= $startTime && $currentTime <= $endTime;
        } else {
            // 跨日的時段
            return $currentTime >= $startTime || $currentTime <= $endTime;
        }
    }
    
    /**
     * 檢查特定類型的偏好設定
     */
    private function checkTypePreference($event, $type, $preferences) {
        $eventType = $event['event_type'];
        $eventAction = $event['event_action'];
        
        $preferencesKey = $eventType . '_preferences';
        if (!isset($preferences[$preferencesKey])) {
            return true; // 沒有特定偏好，使用預設
        }
        
        $typePreferences = json_decode($preferences[$preferencesKey], true);
        if (!$typePreferences || !isset($typePreferences[$eventAction])) {
            return true; // 沒有特定動作偏好，使用預設
        }
        
        return $typePreferences[$eventAction][$type] ?? true;
    }
    
    /**
     * 建構通知物件
     */
    private function buildNotification($event, $eventData, $userId, $type) {
        // 渲染模板
        $title = $this->renderTemplate($event['title_template'], $eventData);
        $body = $this->renderTemplate($event['body_template'], $eventData);
        
        $notification = [
            'user_id' => $userId,
            'template_key' => $event['template_key'],
            'notification_type' => $type,
            'title' => $title,
            'body' => $body,
            'priority' => $event['template_priority'] ?? self::PRIORITY_NORMAL,
            'data' => json_encode($eventData),
            'related_type' => $event['event_type'],
            'related_id' => $eventData['id'] ?? null,
            'max_retries' => $event['max_retries'] ?? 3
        ];
        
        // 設定延遲發送
        if ($event['delay_minutes'] > 0) {
            $scheduledAt = new DateTime();
            $scheduledAt->add(new DateInterval('PT' . $event['delay_minutes'] . 'M'));
            $notification['scheduled_at'] = $scheduledAt->format('Y-m-d H:i:s');
        }
        
        return $notification;
    }
    
    /**
     * 渲染模板
     */
    private function renderTemplate($template, $data) {
        $rendered = $template;
        
        foreach ($data as $key => $value) {
            if (is_scalar($value)) {
                $rendered = str_replace('{{' . $key . '}}', $value, $rendered);
            }
        }
        
        return $rendered;
    }
    
    /**
     * 將通知加入佇列
     */
    private function queueNotification($notification) {
        try {
            $sql = "
                INSERT INTO notification_queue 
                (user_id, template_key, notification_type, title, body, data, 
                 priority, scheduled_at, related_type, related_id, max_retries)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ";
            
            $stmt = $this->db->prepare($sql);
            $success = $stmt->execute([
                $notification['user_id'],
                $notification['template_key'],
                $notification['notification_type'],
                $notification['title'],
                $notification['body'],
                $notification['data'],
                $notification['priority'],
                $notification['scheduled_at'] ?? date('Y-m-d H:i:s'),
                $notification['related_type'],
                $notification['related_id'],
                $notification['max_retries']
            ]);
            
            if ($success) {
                Logger::logBusiness('notification_queued', $notification['user_id'], [
                    'template_key' => $notification['template_key'],
                    'type' => $notification['notification_type'],
                    'priority' => $notification['priority']
                ]);
            }
            
            return $success;
            
        } catch (Exception $e) {
            Logger::logError('notification_queue_failed', [], $e);
            return false;
        }
    }
    
    /**
     * 處理佇列中的通知
     */
    public function processQueue($batchSize = null) {
        $batchSize = $batchSize ?? $this->config['batch_size'];
        
        try {
            // 獲取待處理的通知
            $sql = "
                SELECT * FROM notification_queue 
                WHERE status = 'pending' 
                AND scheduled_at <= NOW()
                AND retry_count < max_retries
                ORDER BY priority DESC, created_at ASC
                LIMIT ?
            ";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$batchSize]);
            $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            $processed = 0;
            $successful = 0;
            
            foreach ($notifications as $notification) {
                // 標記為處理中
                $this->updateNotificationStatus($notification['id'], 'processing');
                
                $result = $this->sendNotification($notification);
                
                if ($result['success']) {
                    $this->updateNotificationStatus(
                        $notification['id'], 
                        'sent', 
                        $result['external_id'] ?? null,
                        $result['message'] ?? null
                    );
                    $successful++;
                } else {
                    $this->handleNotificationFailure($notification, $result);
                }
                
                $processed++;
            }
            
            Logger::logBusiness('notification_queue_processed', null, [
                'processed' => $processed,
                'successful' => $successful,
                'failed' => $processed - $successful
            ]);
            
            return [
                'success' => true,
                'processed' => $processed,
                'successful' => $successful
            ];
            
        } catch (Exception $e) {
            Logger::logError('notification_queue_process_failed', [], $e);
            return [
                'success' => false,
                'message' => $e->getMessage()
            ];
        }
    }
    
    /**
     * 發送通知
     */
    private function sendNotification($notification) {
        switch ($notification['notification_type']) {
            case self::TYPE_PUSH:
                return $this->sendPushNotification($notification);
                
            case self::TYPE_IN_APP:
                return $this->sendInAppNotification($notification);
                
            case self::TYPE_EMAIL:
                return $this->sendEmailNotification($notification);
                
            case self::TYPE_SMS:
                return $this->sendSmsNotification($notification);
                
            default:
                return [
                    'success' => false,
                    'message' => '不支援的通知類型: ' . $notification['notification_type']
                ];
        }
    }
    
    /**
     * 發送推播通知
     */
    private function sendPushNotification($notification) {
        // 這裡實現 FCM 推播邏輯
        // 暫時返回模擬結果
        return [
            'success' => true,
            'message' => '推播通知發送成功',
            'external_id' => 'fcm_' . uniqid()
        ];
    }
    
    /**
     * 發送站內通知
     */
    private function sendInAppNotification($notification) {
        try {
            $data = json_decode($notification['data'], true) ?? [];
            
            $sql = "
                INSERT INTO in_app_notifications 
                (user_id, title, body, related_type, related_id, template_key, action_data)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ";
            
            $stmt = $this->db->prepare($sql);
            $success = $stmt->execute([
                $notification['user_id'],
                $notification['title'],
                $notification['body'],
                $notification['related_type'],
                $notification['related_id'],
                $notification['template_key'],
                json_encode($data['action_data'] ?? [])
            ]);
            
            return [
                'success' => $success,
                'message' => $success ? '站內通知建立成功' : '站內通知建立失敗',
                'external_id' => $success ? $this->db->lastInsertId() : null
            ];
            
        } catch (Exception $e) {
            return [
                'success' => false,
                'message' => '站內通知建立失敗: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * 發送Email通知
     */
    private function sendEmailNotification($notification) {
        // 這裡實現 Email 發送邏輯
        // 暫時返回模擬結果
        return [
            'success' => true,
            'message' => 'Email通知發送成功',
            'external_id' => 'email_' . uniqid()
        ];
    }
    
    /**
     * 發送簡訊通知
     */
    private function sendSmsNotification($notification) {
        // 這裡實現簡訊發送邏輯
        // 暫時返回模擬結果
        return [
            'success' => true,
            'message' => '簡訊通知發送成功',
            'external_id' => 'sms_' . uniqid()
        ];
    }
    
    /**
     * 更新通知狀態
     */
    private function updateNotificationStatus($notificationId, $status, $externalId = null, $message = null) {
        $sql = "
            UPDATE notification_queue 
            SET status = ?, result_code = ?, result_message = ?, external_id = ?, 
                sent_at = CASE WHEN ? = 'sent' THEN NOW() ELSE sent_at END,
                updated_at = NOW()
            WHERE id = ?
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$status, $status, $message, $externalId, $status, $notificationId]);
    }
    
    /**
     * 處理通知發送失敗
     */
    private function handleNotificationFailure($notification, $result) {
        $retryCount = $notification['retry_count'] + 1;
        
        if ($retryCount >= $notification['max_retries']) {
            // 達到最大重試次數，標記為失敗
            $this->updateNotificationStatus(
                $notification['id'], 
                'failed', 
                null, 
                $result['message']
            );
        } else {
            // 安排重試
            $nextRetry = new DateTime();
            $nextRetry->add(new DateInterval('PT' . $this->config['retry_delay'] . 'S'));
            
            $sql = "
                UPDATE notification_queue 
                SET status = 'pending', retry_count = ?, 
                    scheduled_at = ?, result_message = ?, updated_at = NOW()
                WHERE id = ?
            ";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([
                $retryCount,
                $nextRetry->format('Y-m-d H:i:s'),
                $result['message'],
                $notification['id']
            ]);
        }
    }
    
    /**
     * 獲取通知統計
     */
    public function getNotificationStats($startDate = null, $endDate = null) {
        $startDate = $startDate ?? date('Y-m-d', strtotime('-7 days'));
        $endDate = $endDate ?? date('Y-m-d');
        
        $sql = "
            SELECT 
                template_key,
                notification_type,
                SUM(sent_count) as total_sent,
                SUM(delivered_count) as total_delivered,
                SUM(opened_count) as total_opened,
                SUM(clicked_count) as total_clicked,
                SUM(failed_count) as total_failed
            FROM notification_stats 
            WHERE date BETWEEN ? AND ?
            GROUP BY template_key, notification_type
            ORDER BY total_sent DESC
        ";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$startDate, $endDate]);
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
