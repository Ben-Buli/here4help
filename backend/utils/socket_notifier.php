<?php
/**
 * Socket 通知工具類
 * 用於在任務狀態或應徵狀態變化時發送 Socket 事件
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../config/database.php';

class SocketNotifier {
    private static $instance = null;
    private $socketUrl;
    private $socketToken;
    
    private function __construct() {
        // 從環境變數獲取 Socket.IO 服務器配置
        $this->socketUrl = $_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001';
        $this->socketToken = $_ENV['SOCKET_SERVER_TOKEN'] ?? 'your-socket-server-token';
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * 發送任務狀態更新事件
     * @param string $taskId 任務ID
     * @param string $roomId 聊天室ID
     * @param array $statusData 狀態數據
     * @param array $userIds 需要通知的用戶ID列表
     */
    public function notifyTaskStatusUpdate($taskId, $roomId, $statusData, $userIds = []) {
        $eventData = [
            'event' => 'task_status_update',
            'data' => [
                'task_id' => $taskId,
                'room_id' => $roomId,
                'status' => $statusData,
                'timestamp' => date('Y-m-d H:i:s'),
            ]
        ];
        
        $this->sendSocketEvent($eventData, $userIds);
    }
    
    /**
     * 發送應徵狀態更新事件
     * @param string $taskId 任務ID
     * @param string $roomId 聊天室ID
     * @param string $applicationStatus 應徵狀態
     * @param array $userIds 需要通知的用戶ID列表
     */
    public function notifyApplicationStatusUpdate($taskId, $roomId, $applicationStatus, $userIds = []) {
        $eventData = [
            'event' => 'application_status_update',
            'data' => [
                'task_id' => $taskId,
                'room_id' => $roomId,
                'application_status' => $applicationStatus,
                'timestamp' => date('Y-m-d H:i:s'),
            ]
        ];
        
        $this->sendSocketEvent($eventData, $userIds);
    }
    
    /**
     * 發送 Socket 事件到指定用戶
     * @param array $eventData 事件數據
     * @param array $userIds 用戶ID列表
     */
    private function sendSocketEvent($eventData, $userIds) {
        try {
            // 構建請求數據
            $requestData = [
                'token' => $this->socketToken,
                'event' => $eventData['event'],
                'data' => $eventData['data'],
                'userIds' => $userIds,
            ];
            
            // 使用 file_get_contents 發送 HTTP 請求到 Socket.IO 服務器
            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => [
                        'Content-Type: application/json',
                        'Authorization: Bearer ' . $this->socketToken,
                        'Content-Length: ' . strlen(json_encode($requestData))
                    ],
                    'content' => json_encode($requestData),
                    'timeout' => 5
                ]
            ]);
            
            $response = file_get_contents($this->socketUrl . '/api/notify', false, $context);
            
            if ($response !== false) {
                error_log("[SocketNotifier] Event sent successfully: " . $eventData['event']);
            } else {
                error_log("[SocketNotifier] Failed to send event");
            }
            
        } catch (Exception $e) {
            error_log("[SocketNotifier] Error sending socket event: " . $e->getMessage());
        }
    }
    
    /**
     * 從聊天室獲取相關用戶ID
     * @param string $roomId 聊天室ID
     * @return array 用戶ID列表
     */
    public function getRoomUserIds($roomId) {
        try {
            $db = Database::getInstance();
            $sql = "SELECT creator_id, participant_id FROM chat_rooms WHERE id = ?";
            $row = $db->fetch($sql, [$roomId]);
            
            if ($row) {
                return [
                    (int)$row['creator_id'],
                    (int)$row['participant_id']
                ];
            }
            
            return [];
        } catch (Exception $e) {
            error_log("[SocketNotifier] Error getting room user IDs: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * 從任務ID獲取相關聊天室的用戶ID
     * @param string $taskId 任務ID
     * @return array 用戶ID列表
     */
    public function getTaskUserIds($taskId) {
        try {
            $db = Database::getInstance();
            $sql = "SELECT creator_id, participant_id FROM chat_rooms WHERE task_id = ?";
            $rows = $db->fetchAll($sql, [$taskId]);
            
            $userIds = [];
            foreach ($rows as $row) {
                $userIds[] = (int)$row['creator_id'];
                $userIds[] = (int)$row['participant_id'];
            }
            
            return array_unique($userIds);
        } catch (Exception $e) {
            error_log("[SocketNotifier] Error getting task user IDs: " . $e->getMessage());
            return [];
        }
    }
}
?>
