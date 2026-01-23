<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置


// CORS headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::methodNotAllowed('僅支援 GET 請求');
    }

    // 驗證 JWT token - 支持多源讀取（Authorization header 和查詢參數）
    $jwtManager = new JWTManager();
    $authHeader = getAuthorizationHeader();
    $token = null;

    if ($authHeader && strpos($authHeader, 'Bearer ') === 0) {
        $token = trim(substr($authHeader, 7));
    }

    // 如果 header 中沒有 token，嘗試從查詢參數讀取（MAMP 兼容性）
    if (!$token) {
        $token = $_GET['token'] ?? '';
    }

    if (!$token) {
        Response::unauthorized('Token is required');
    }

    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        Response::unauthorized('Invalid or expired token');
    }

    $userId = $payload['user_id'];

    // 建立資料庫連線
    $dbHost = EnvLoader::get('DB_HOST');
    if ($dbHost === 'localhost') { $dbHost = '127.0.0.1'; }
    $dbPort = EnvLoader::get('DB_PORT') ?: '3306';
    $dsn = "mysql:host={$dbHost};port={$dbPort};dbname=" . EnvLoader::get('DB_NAME') . ";charset=utf8mb4";

    $pdo = new PDO(
        $dsn,
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );

    $stmt = $pdo->prepare("SELECT permission, status, updated_at FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    if (!$user) {
        Response::notFound('User not found');
    }

    $permission = (int)($user['permission'] ?? 0);
    $status = $user['status'] ?? 'active';

    Response::success([
        'permission' => $permission,
        'status' => $status,
        'flags' => [
            'suspended' => in_array($permission, [-1, -3], true),
            'deleted' => in_array($permission, [-2, -4], true),
        ],
        'updated_at' => $user['updated_at'],
    ], 'User status retrieved successfully');
} catch (Exception $e) {
    Response::error(ErrorCodes::INTERNAL_SERVER_ERROR, 'Failed to retrieve user status');
}
