<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

require_once __DIR__ . '/../../utils/TermsManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Method not allowed');
}

try {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    $token = null;

    if ($authHeader && preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $token = $matches[1];
    } elseif (isset($_GET['token'])) {
        $token = $_GET['token'];
    }

    if (!$token) {
        Response::error('Missing authorization token', 401);
    }

    $jwtManager = new JWTManager();
    $payload = $jwtManager->validateToken($token);

    if (!$payload || empty($payload['user_id'])) {
        Response::error('Invalid or expired token', 401);
    }

    $input = json_decode(file_get_contents('php://input'), true);
    if (!is_array($input)) {
        $input = [];
    }

    // 獲取當前活躍的條款版本
    $terms = TermsManager::getActiveTerms(true);
    if (!$terms) {
        Response::error('No active terms found', 404);
    }

    $versionId = (int)$terms['id'];

    $meta = [
        'device_info' => isset($input['device_info']) ? trim((string)$input['device_info']) : null,
        'platform' => isset($input['platform']) ? trim((string)$input['platform']) : null,
    ];

    // 記錄使用者拒絕條款
    TermsManager::recordRejection(
        (int)$payload['user_id'],
        $versionId,
        $meta
    );

    Response::success([
        'terms' => [
            'id' => (int)$terms['id'],
            'version' => $terms['version'],
            'title' => $terms['title'],
        ],
    ], 'Terms rejection recorded');
} catch (Exception $e) {
    error_log("Terms Reject API Error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    Response::serverError('Failed to record rejection: ' . $e->getMessage());
}

