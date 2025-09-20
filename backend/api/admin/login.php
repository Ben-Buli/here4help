<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

/**
 * 管理員登入 API
 * POST /api/admin/login
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';
    
    // 驗證輸入
    if (empty($email) || empty($password)) {
        Response::error('Email and password are required', 400);
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        Response::error('Invalid email format', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 查詢管理員用戶（從 admins 資料表）
    $stmt = $db->prepare("
        SELECT a.id, a.username, a.full_name, a.email, a.password, a.role_id, a.status, 
               a.created_at, a.updated_at, ar.name as role_name
        FROM admins a
        LEFT JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.email = ? AND a.status = 'active'
    ");
    $stmt->execute([$email]);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin) {
        Response::error('Invalid credentials or insufficient permissions', 401);
    }
    
    // 驗證密碼
    if (!password_verify($password, $admin['password'])) {
        Response::error('Invalid credentials', 401);
    }
    
    // 檢查帳號狀態
    if ($admin['status'] !== 'active') {
        Response::error('Account is disabled', 403);
    }
    
    // 更新最後登入時間
    $updateStmt = $db->prepare("UPDATE admins SET last_login = NOW(), updated_at = NOW() WHERE id = ?");
    $updateStmt->execute([$admin['id']]);
    
    // 生成 JWT token
    $tokenPayload = [
        'user_id' => $admin['id'],
        'admin_id' => $admin['id'], // 為了兼容現有 API
        'email' => $admin['email'],
        'role_id' => $admin['role_id'],
        'role_name' => $admin['role_name'],
        'type' => 'admin'
    ];
    
    $token = JWTManager::generateToken($tokenPayload);
    
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
            'permissions' => ['*'] // 管理員擁有所有權限
        ],
        'status' => $admin['status'],
        'last_login' => $admin['updated_at'],
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
        '*' // 超級權限
    ];
    
    Response::success([
        'admin' => $adminData,
        'token' => $token,
        'permissions' => $permissions
    ], 'Login successful');
    
} catch (Exception $e) {
    error_log("Admin login error: " . $e->getMessage());
    Response::error('Login failed: ' . $e->getMessage(), 500);
}
?>
