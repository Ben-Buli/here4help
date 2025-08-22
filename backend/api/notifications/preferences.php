<?php
/**
 * 通知偏好設定 API
 * 處理使用者通知偏好的查詢和更新
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../database/database_manager.php';
require_once __DIR__ . '/../../utils/Logger.php';

// 設定 CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    // JWT 驗證
    $jwt = JWTManager::validateToken();
    if (!$jwt['valid']) {
        Response::error('UNAUTHORIZED', $jwt['message']);
        exit;
    }
    
    $userId = $jwt['payload']['user_id'];
    $method = $_SERVER['REQUEST_METHOD'];
    
    switch ($method) {
        case 'GET':
            handleGetPreferences($userId);
            break;
            
        case 'PUT':
            handleUpdatePreferences($userId);
            break;
            
        default:
            Response::error('METHOD_NOT_ALLOWED', '不支援的請求方法');
    }
    
} catch (Exception $e) {
    Logger::logError('notification_preferences_api_failed', ['user_id' => $userId ?? null], $e);
    Response::error('INTERNAL_ERROR', '通知偏好 API 處理失敗');
}

/**
 * 獲取使用者通知偏好
 */
function handleGetPreferences($userId) {
    try {
        // 直接建立資料庫連接
        $envLoader = EnvLoader::getInstance();
        $dbConfig = $envLoader->getDatabaseConfig();
        
        $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']};charset=utf8mb4";
        $db = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]);
        
        // 查詢使用者偏好
        $sql = "
            SELECT * FROM user_notification_preferences 
            WHERE user_id = ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$userId]);
        $preferences = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$preferences) {
            // 建立預設偏好
            $preferences = createDefaultPreferences($userId);
        }
        
        // 處理 JSON 欄位
        $preferences['task_preferences'] = json_decode($preferences['task_preferences'], true);
        $preferences['chat_preferences'] = json_decode($preferences['chat_preferences'], true);
        $preferences['support_preferences'] = json_decode($preferences['support_preferences'], true);
        $preferences['admin_preferences'] = json_decode($preferences['admin_preferences'], true);
        $preferences['quiet_days'] = json_decode($preferences['quiet_days'], true);
        
        // 轉換布林值
        $preferences['push_enabled'] = (bool)$preferences['push_enabled'];
        $preferences['in_app_enabled'] = (bool)$preferences['in_app_enabled'];
        $preferences['email_enabled'] = (bool)$preferences['email_enabled'];
        $preferences['sms_enabled'] = (bool)$preferences['sms_enabled'];
        
        // 獲取可用的通知模板資訊
        $templates = getAvailableTemplates();
        
        Response::success([
            'preferences' => $preferences,
            'available_templates' => $templates
        ]);
        
    } catch (Exception $e) {
        Logger::logError('get_notification_preferences_failed', ['user_id' => $userId], $e);
        Response::error('QUERY_FAILED', '查詢通知偏好失敗');
    }
}

/**
 * 更新使用者通知偏好
 */
function handleUpdatePreferences($userId) {
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            Response::error('INVALID_JSON', '無效的 JSON 資料');
            exit;
        }
        
        // 直接建立資料庫連接
        $envLoader = EnvLoader::getInstance();
        $dbConfig = $envLoader->getDatabaseConfig();
        
        $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']};charset=utf8mb4";
        $db = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]);
        
        // 驗證輸入資料
        $validatedData = validatePreferencesData($input);
        if (!$validatedData['valid']) {
            Response::error('VALIDATION_FAILED', $validatedData['message']);
            exit;
        }
        
        // 檢查使用者偏好是否存在
        $existingSql = "SELECT id FROM user_notification_preferences WHERE user_id = ?";
        $existingStmt = $db->prepare($existingSql);
        $existingStmt->execute([$userId]);
        $exists = $existingStmt->fetch();
        
        if ($exists) {
            // 更新現有偏好
            $updateSql = "
                UPDATE user_notification_preferences 
                SET push_enabled = ?, in_app_enabled = ?, email_enabled = ?, sms_enabled = ?,
                    quiet_hours_start = ?, quiet_hours_end = ?, quiet_days = ?,
                    task_preferences = ?, chat_preferences = ?, support_preferences = ?, admin_preferences = ?,
                    updated_at = NOW()
                WHERE user_id = ?
            ";
            
            $updateStmt = $db->prepare($updateSql);
            $success = $updateStmt->execute([
                $input['push_enabled'] ?? true,
                $input['in_app_enabled'] ?? true,
                $input['email_enabled'] ?? true,
                $input['sms_enabled'] ?? false,
                $input['quiet_hours_start'] ?? null,
                $input['quiet_hours_end'] ?? null,
                json_encode($input['quiet_days'] ?? []),
                json_encode($input['task_preferences'] ?? []),
                json_encode($input['chat_preferences'] ?? []),
                json_encode($input['support_preferences'] ?? []),
                json_encode($input['admin_preferences'] ?? []),
                $userId
            ]);
            
        } else {
            // 建立新偏好
            $insertSql = "
                INSERT INTO user_notification_preferences 
                (user_id, push_enabled, in_app_enabled, email_enabled, sms_enabled,
                 quiet_hours_start, quiet_hours_end, quiet_days,
                 task_preferences, chat_preferences, support_preferences, admin_preferences)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ";
            
            $insertStmt = $db->prepare($insertSql);
            $success = $insertStmt->execute([
                $userId,
                $input['push_enabled'] ?? true,
                $input['in_app_enabled'] ?? true,
                $input['email_enabled'] ?? true,
                $input['sms_enabled'] ?? false,
                $input['quiet_hours_start'] ?? null,
                $input['quiet_hours_end'] ?? null,
                json_encode($input['quiet_days'] ?? []),
                json_encode($input['task_preferences'] ?? []),
                json_encode($input['chat_preferences'] ?? []),
                json_encode($input['support_preferences'] ?? []),
                json_encode($input['admin_preferences'] ?? [])
            ]);
        }
        
        if ($success) {
            Logger::logBusiness('notification_preferences_updated', $userId, [
                'updated_fields' => array_keys($input)
            ]);
            
            Response::success(['message' => '通知偏好更新成功']);
        } else {
            Response::error('UPDATE_FAILED', '更新通知偏好失敗');
        }
        
    } catch (Exception $e) {
        Logger::logError('update_notification_preferences_failed', ['user_id' => $userId], $e);
        Response::error('UPDATE_FAILED', '更新通知偏好失敗');
    }
}

/**
 * 建立預設通知偏好
 */
function createDefaultPreferences($userId) {
    try {
        // 直接建立資料庫連接
        $envLoader = EnvLoader::getInstance();
        $dbConfig = $envLoader->getDatabaseConfig();
        
        $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']};charset=utf8mb4";
        $db = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]);
        
        $defaultPreferences = [
            'user_id' => $userId,
            'push_enabled' => true,
            'in_app_enabled' => true,
            'email_enabled' => true,
            'sms_enabled' => false,
            'quiet_hours_start' => null,
            'quiet_hours_end' => null,
            'quiet_days' => json_encode([]),
            'task_preferences' => json_encode([
                'created' => ['push' => true, 'in_app' => true, 'email' => false],
                'accepted' => ['push' => true, 'in_app' => true, 'email' => false],
                'completed' => ['push' => true, 'in_app' => true, 'email' => true],
                'cancelled' => ['push' => true, 'in_app' => true, 'email' => false],
                'dispute_created' => ['push' => true, 'in_app' => true, 'email' => true]
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
                'system_alert' => ['push' => true, 'in_app' => true, 'email' => true],
                'user_report' => ['push' => true, 'in_app' => true, 'email' => true]
            ])
        ];
        
        $sql = "
            INSERT INTO user_notification_preferences 
            (user_id, push_enabled, in_app_enabled, email_enabled, sms_enabled,
             quiet_hours_start, quiet_hours_end, quiet_days,
             task_preferences, chat_preferences, support_preferences, admin_preferences)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([
            $userId,
            $defaultPreferences['push_enabled'],
            $defaultPreferences['in_app_enabled'],
            $defaultPreferences['email_enabled'],
            $defaultPreferences['sms_enabled'],
            $defaultPreferences['quiet_hours_start'],
            $defaultPreferences['quiet_hours_end'],
            $defaultPreferences['quiet_days'],
            $defaultPreferences['task_preferences'],
            $defaultPreferences['chat_preferences'],
            $defaultPreferences['support_preferences'],
            $defaultPreferences['admin_preferences']
        ]);
        
        Logger::logBusiness('default_notification_preferences_created', $userId);
        
        return $defaultPreferences;
        
    } catch (Exception $e) {
        Logger::logError('create_default_preferences_failed', ['user_id' => $userId], $e);
        throw $e;
    }
}

/**
 * 獲取可用的通知模板
 */
function getAvailableTemplates() {
    try {
        // 直接建立資料庫連接
        $envLoader = EnvLoader::getInstance();
        $dbConfig = $envLoader->getDatabaseConfig();
        
        $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['dbname']};charset=utf8mb4";
        $db = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]);
        
        $sql = "
            SELECT template_key, name, description, supports_push, supports_in_app, supports_email, supports_sms
            FROM notification_templates 
            WHERE is_active = 1
            ORDER BY template_key
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute();
        $templates = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 按事件類型分組
        $groupedTemplates = [
            'task' => [],
            'chat' => [],
            'support' => [],
            'admin' => []
        ];
        
        foreach ($templates as $template) {
            $template['supports_push'] = (bool)$template['supports_push'];
            $template['supports_in_app'] = (bool)$template['supports_in_app'];
            $template['supports_email'] = (bool)$template['supports_email'];
            $template['supports_sms'] = (bool)$template['supports_sms'];
            
            // 根據模板鍵值判斷分類
            if (strpos($template['template_key'], 'task_') === 0) {
                $groupedTemplates['task'][] = $template;
            } elseif (strpos($template['template_key'], 'chat_') === 0) {
                $groupedTemplates['chat'][] = $template;
            } elseif (strpos($template['template_key'], 'support_') === 0) {
                $groupedTemplates['support'][] = $template;
            } elseif (strpos($template['template_key'], 'admin_') === 0) {
                $groupedTemplates['admin'][] = $template;
            }
        }
        
        return $groupedTemplates;
        
    } catch (Exception $e) {
        Logger::logError('get_available_templates_failed', [], $e);
        return [
            'task' => [],
            'chat' => [],
            'support' => [],
            'admin' => []
        ];
    }
}

/**
 * 驗證偏好設定資料
 */
function validatePreferencesData($data) {
    // 驗證布林值欄位
    $booleanFields = ['push_enabled', 'in_app_enabled', 'email_enabled', 'sms_enabled'];
    foreach ($booleanFields as $field) {
        if (isset($data[$field]) && !is_bool($data[$field])) {
            return [
                'valid' => false,
                'message' => "$field 必須是布林值"
            ];
        }
    }
    
    // 驗證時間格式
    $timeFields = ['quiet_hours_start', 'quiet_hours_end'];
    foreach ($timeFields as $field) {
        if (isset($data[$field]) && $data[$field] !== null) {
            if (!preg_match('/^([01]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/', $data[$field])) {
                return [
                    'valid' => false,
                    'message' => "$field 時間格式不正確，應為 HH:MM:SS"
                ];
            }
        }
    }
    
    // 驗證靜音日期
    if (isset($data['quiet_days'])) {
        if (!is_array($data['quiet_days'])) {
            return [
                'valid' => false,
                'message' => 'quiet_days 必須是陣列'
            ];
        }
        
        foreach ($data['quiet_days'] as $day) {
            if (!is_int($day) || $day < 1 || $day > 7) {
                return [
                    'valid' => false,
                    'message' => 'quiet_days 中的日期必須是 1-7 的整數'
                ];
            }
        }
    }
    
    // 驗證偏好設定結構
    $preferenceFields = ['task_preferences', 'chat_preferences', 'support_preferences', 'admin_preferences'];
    foreach ($preferenceFields as $field) {
        if (isset($data[$field])) {
            if (!is_array($data[$field])) {
                return [
                    'valid' => false,
                    'message' => "$field 必須是物件"
                ];
            }
            
            // 驗證每個事件的偏好設定
            foreach ($data[$field] as $event => $preferences) {
                if (!is_array($preferences)) {
                    return [
                        'valid' => false,
                        'message' => "$field.$event 必須是物件"
                    ];
                }
                
                $validTypes = ['push', 'in_app', 'email', 'sms'];
                foreach ($preferences as $type => $enabled) {
                    if (!in_array($type, $validTypes)) {
                        return [
                            'valid' => false,
                            'message' => "$field.$event.$type 不是有效的通知類型"
                        ];
                    }
                    
                    if (!is_bool($enabled)) {
                        return [
                            'valid' => false,
                            'message' => "$field.$event.$type 必須是布林值"
                        ];
                    }
                }
            }
        }
    }
    
    return ['valid' => true];
}
