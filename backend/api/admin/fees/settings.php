<?php
/**
 * GET/PUT /api/admin/fees/settings.php
 * 管理員手續費設定管理API
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';

Response::setCorsHeaders();

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    
    // TODO: 添加管理員權限檢查
    // if (!isAdmin($tokenData['user_id'])) {
    //     Response::error('Insufficient permissions', 403);
    // }
    
    $db = Database::getInstance();
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        handleGetSettings($db);
    } elseif ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        handleUpdateSettings($db, $tokenData['user_id']);
    } else {
        Response::error('Method not allowed', 405);
    }
    
} catch (Exception $e) {
    error_log("Admin fees settings error: " . $e->getMessage());
    Response::error('Failed to process request: ' . $e->getMessage(), 500);
}

/**
 * 處理獲取手續費設定
 */
function handleGetSettings($db) {
    $includeHistory = $_GET['include_history'] === 'true';
    
    // 獲取當前生效的設定
    $currentQuery = "
        SELECT id, rate, description, is_active, updated_by, created_at, updated_at
        FROM task_completion_points_fee_settings 
        WHERE is_active = 1 
        ORDER BY updated_at DESC 
        LIMIT 1
    ";
    
    $currentSettings = $db->fetch($currentQuery);
    
    $result = [
        'current_settings' => $currentSettings ? [
            'id' => (int)$currentSettings['id'],
            'rate' => (float)$currentSettings['rate'],
            'rate_percentage' => number_format((float)$currentSettings['rate'] * 100, 2) . '%',
            'description' => $currentSettings['description'],
            'is_active' => (bool)$currentSettings['is_active'],
            'updated_by' => $currentSettings['updated_by'],
            'created_at' => $currentSettings['created_at'],
            'updated_at' => $currentSettings['updated_at']
        ] : null
    ];
    
    // 如果需要歷史記錄
    if ($includeHistory) {
        $historyQuery = "
            SELECT id, rate, description, is_active, updated_by, created_at, updated_at
            FROM task_completion_points_fee_settings 
            ORDER BY updated_at DESC 
            LIMIT 20
        ";
        
        $historyResults = $db->fetchAll($historyQuery);
        
        $result['history'] = array_map(function($setting) {
            return [
                'id' => (int)$setting['id'],
                'rate' => (float)$setting['rate'],
                'rate_percentage' => number_format((float)$setting['rate'] * 100, 2) . '%',
                'description' => $setting['description'],
                'is_active' => (bool)$setting['is_active'],
                'updated_by' => $setting['updated_by'],
                'created_at' => $setting['created_at'],
                'updated_at' => $setting['updated_at']
            ];
        }, $historyResults);
    }
    
    Response::success($result, 'Fee settings retrieved successfully');
}

/**
 * 處理更新手續費設定
 */
function handleUpdateSettings($db, $adminUserId) {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $rate = $input['rate'] ?? null;
    $description = $input['description'] ?? '';
    $effectiveDate = $input['effective_date'] ?? null;
    
    // 驗證輸入
    $errors = [];
    if (!is_numeric($rate) || $rate < 0 || $rate > 1) {
        $errors['rate'] = 'Rate must be a decimal between 0 and 1';
    }
    if (empty($description)) {
        $errors['description'] = 'Description is required';
    }
    
    if (!empty($errors)) {
        Response::validationError($errors);
    }
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
        // 停用所有現有設定
        $deactivateQuery = "UPDATE task_completion_points_fee_settings SET is_active = 0";
        $db->execute($deactivateQuery);
        
        // 插入新設定
        $insertQuery = "
            INSERT INTO task_completion_points_fee_settings (
                rate, description, is_active, updated_by, created_at, updated_at
            ) VALUES (?, ?, 1, ?, NOW(), NOW())
        ";
        
        $db->execute($insertQuery, [$rate, $description, $adminUserId]);
        $settingsId = $db->lastInsertId();
        
        // 提交交易
        $db->commit();
        
        Response::success([
            'settings_id' => (int)$settingsId,
            'rate' => (float)$rate,
            'rate_percentage' => number_format($rate * 100, 2) . '%',
            'description' => $description,
            'updated_by' => $adminUserId,
            'effective_at' => date('Y-m-d H:i:s'),
            'is_active' => true
        ], 'Fee settings updated successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}
?>
