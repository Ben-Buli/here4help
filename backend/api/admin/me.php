<?php
/**
 * 獲取當前管理員信息 API
 * GET /api/admin/me
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    $payload = $tokenData['payload'];
    $adminId = $payload['admin_id'] ?? $payload['user_id'] ?? null;
    
    if (!$adminId) {
        Response::error('Invalid token payload', 401);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 查詢管理員信息（從 admins 資料表）
    $stmt = $db->prepare("
        SELECT a.id, a.username, a.full_name, a.email, a.role_id, a.status, 
               a.created_at, a.updated_at, a.last_login, ar.name as role_name
        FROM admins a
        LEFT JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.id = ? AND a.status = 'active'
    ");
    $stmt->execute([$adminId]);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin) {
        Response::error('Admin not found or insufficient permissions', 403);
    }
    
    // 準備回應資料
    $adminData = [
        'id' => (int)$admin['id'],
        'username' => $admin['username'],
        'full_name' => $admin['full_name'],
        'email' => $admin['email'],
        'role' => [
            'id' => (int)$admin['role_id'],
            'name' => $admin['role_name'] ?? 'admin',
            'display_name' => ucfirst($admin['role_name'] ?? 'Administrator'),
            'permissions' => ['*']
        ],
        'status' => $admin['status'],
        'last_login' => $admin['last_login'],
        'role_id' => (int)$admin['role_id']
    ];
    
    // 管理員權限列表
    $permissions = [
        'users.list',
        'users.view',
        'users.edit',
        'users.delete',
        'tasks.list',
        'tasks.view',
        'tasks.edit',
        'disputes.list',
        'disputes.view',
        'disputes.resolve',
        'logs.view',
        'settings.manage',
        '*'
    ];
    
    Response::success([
        'admin' => $adminData,
        'permissions' => $permissions
    ], 'Admin information retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin me API error: " . $e->getMessage());
    Response::error('Failed to get admin information: ' . $e->getMessage(), 500);
}
?>
