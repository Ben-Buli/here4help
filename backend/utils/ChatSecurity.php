<?php
/**
 * 聊天系統安全性驗證工具 - 遵循聊天系統規格文件標準
 * 
 * 實現規格文件的安全性要求：
 * - 房間參與者驗證
 * - 權限檢查
 * - 資料存取控制
 */

require_once __DIR__ . '/../config/database.php';

class ChatSecurity {
    
    /**
     * 驗證用戶是否為指定聊天室的參與者
     * 
     * @param int $userId 用戶 ID
     * @param string $roomId 聊天室 ID
     * @return array|null 返回房間資訊，如果無權限則返回 null
     */
    public static function verifyRoomParticipant($userId, $roomId) {
        try {
            $db = Database::getInstance();
            
            $sql = "
                SELECT 
                    id, 
                    task_id, 
                    creator_id, 
                    participant_id,
                    created_at
                FROM chat_rooms 
                WHERE id = ? AND (creator_id = ? OR participant_id = ?)
            ";
            
            $room = $db->query($sql, [$roomId, $userId, $userId])->fetch();
            
            if (!$room) {
                error_log("ChatSecurity: 用戶 $userId 無權限存取聊天室 $roomId");
                return null;
            }
            
            return $room;
        } catch (Exception $e) {
            error_log("ChatSecurity: 驗證房間參與者失敗: " . $e->getMessage());
            return null;
        }
    }
    
    /**
     * 獲取用戶在聊天室中的角色
     * 
     * @param int $userId 用戶 ID
     * @param array $room 聊天室資訊
     * @return string 'creator' 或 'participant'
     */
    public static function getUserRole($userId, $room) {
        if ((int)$room['creator_id'] === (int)$userId) {
            return 'creator';
        } elseif ((int)$room['participant_id'] === (int)$userId) {
            return 'participant';
        }
        
        throw new Exception("用戶 $userId 不是聊天室 {$room['id']} 的參與者");
    }
    
    /**
     * 驗證用戶對聊天室的讀取權限
     * 
     * @param int $userId 用戶 ID
     * @param string $roomId 聊天室 ID
     * @return bool
     */
    public static function canReadRoom($userId, $roomId) {
        $room = self::verifyRoomParticipant($userId, $roomId);
        return $room !== null;
    }
    
    /**
     * 驗證用戶對聊天室的寫入權限
     * 
     * @param int $userId 用戶 ID
     * @param string $roomId 聊天室 ID
     * @return bool
     */
    public static function canWriteRoom($userId, $roomId) {
        // 目前讀取和寫入權限相同，未來可能會有不同的邏輯
        return self::canReadRoom($userId, $roomId);
    }
    
    /**
     * 驗證用戶對 scope 的存取權限
     * 
     * @param int $userId 用戶 ID
     * @param string $scope 查詢範圍 ('posted', 'myworks', 'all')
     * @return bool
     */
    public static function canAccessScope($userId, $scope) {
        // 所有認證用戶都可以存取任何 scope
        // 實際的資料過濾在 SQL 查詢中進行
        return in_array($scope, ['posted', 'myworks', 'all']);
    }
    
    /**
     * 獲取用戶可存取的聊天室 IDs
     * 
     * @param int $userId 用戶 ID
     * @param string $scope 查詢範圍
     * @return array 聊天室 ID 陣列
     */
    public static function getUserAccessibleRooms($userId, $scope = 'all') {
        try {
            $db = Database::getInstance();
            
            $conditions = [];
            $params = [];
            
            if ($scope === 'posted') {
                $conditions[] = 'creator_id = ?';
                $params[] = $userId;
            } elseif ($scope === 'myworks') {
                $conditions[] = 'participant_id = ?';
                $params[] = $userId;
            } else {
                $conditions[] = '(creator_id = ? OR participant_id = ?)';
                $params[] = $userId;
                $params[] = $userId;
            }
            
            $whereClause = implode(' AND ', $conditions);
            
            $sql = "SELECT id FROM chat_rooms WHERE $whereClause";
            $results = $db->fetchAll($sql, $params);
            
            return array_map(function($row) {
                return $row['id'];
            }, $results);
            
        } catch (Exception $e) {
            error_log("ChatSecurity: 獲取可存取聊天室失敗: " . $e->getMessage());
            return [];
        }
    }
    
    /**
     * 記錄安全性事件
     * 
     * @param string $event 事件類型
     * @param int $userId 用戶 ID
     * @param array $context 上下文資料
     */
    public static function logSecurityEvent($event, $userId, $context = []) {
        $contextStr = json_encode($context);
        $timestamp = date('Y-m-d H:i:s');
        
        error_log("ChatSecurity [$timestamp]: $event - 用戶 $userId - $contextStr");
    }
    
    /**
     * 防範 SQL 注入的參數清理
     * 
     * @param mixed $input 輸入參數
     * @param string $type 預期類型 ('int', 'string', 'array')
     * @return mixed 清理後的參數
     */
    public static function sanitizeInput($input, $type = 'string') {
        switch ($type) {
            case 'int':
                return (int)$input;
            
            case 'string':
                return is_string($input) ? trim($input) : '';
            
            case 'array':
                return is_array($input) ? $input : [];
            
            default:
                return $input;
        }
    }
    
    /**
     * 驗證聊天室是否存在
     * 
     * @param string $roomId 聊天室 ID
     * @return bool
     */
    public static function roomExists($roomId) {
        try {
            $db = Database::getInstance();
            $result = $db->query("SELECT id FROM chat_rooms WHERE id = ?", [$roomId])->fetch();
            return $result !== false;
        } catch (Exception $e) {
            error_log("ChatSecurity: 檢查聊天室存在失敗: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * 檢查用戶是否被封鎖
     * 
     * @param int $userId 用戶 ID
     * @param string $roomId 聊天室 ID (可選)
     * @return bool
     */
    public static function isUserBlocked($userId, $roomId = null) {
        // 這裡可以實現更複雜的封鎖邏輯
        // 目前簡單返回 false，表示沒有用戶被封鎖
        return false;
    }
    
    /**
     * 驗證訊息內容
     * 
     * @param string $content 訊息內容
     * @return array ['valid' => bool, 'message' => string]
     */
    public static function validateMessageContent($content) {
        $content = trim($content);
        
        if (empty($content)) {
            return ['valid' => false, 'message' => '訊息內容不能為空'];
        }
        
        if (strlen($content) > 10000) {
            return ['valid' => false, 'message' => '訊息內容過長'];
        }
        
        // 這裡可以加入更多內容驗證邏輯，例如：
        // - 敏感詞過濾
        // - HTML 標籤清理
        // - 惡意內容檢測
        
        return ['valid' => true, 'message' => ''];
    }
}
