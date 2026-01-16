<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
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
        Response::validationError([
            'version_id' => 'Invalid payload',
        ]);
    }

    $versionId = isset($input['version_id']) ? (int)$input['version_id'] : 0;
    if ($versionId <= 0) {
        Response::validationError([
            'version_id' => 'Version ID is required',
        ]);
    }

    $terms = TermsManager::getTermsById($versionId);
    if (!$terms) {
        Response::validationError([
            'version_id' => 'Specified terms version does not exist',
        ]);
    }

    if ((int)$terms['is_active'] !== 1) {
        Response::validationError([
            'version_id' => 'Only active terms can be accepted',
        ]);
    }

    $meta = [
        'ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
        'device_info' => isset($input['device_info']) ? trim((string)$input['device_info']) : null,
        'user_agent' => $headers['User-Agent'] ?? $headers['user-agent'] ?? ($input['user_agent'] ?? null),
        'platform' => isset($input['platform']) ? trim((string)$input['platform']) : null,
    ];

    $acceptance = TermsManager::recordAcceptance(
        (int)$payload['user_id'],
        $versionId,
        $meta
    );

    Response::success([
        'acceptance' => [
            'id' => (int)$acceptance['id'],
            'user_id' => (int)$acceptance['user_id'],
            'accepted_version_id' => (int)$acceptance['accepted_version_id'],
            'accepted_at' => $acceptance['accepted_at'],
            'ip_address' => $acceptance['ip_address'],
            'device_info' => $acceptance['device_info'],
            'user_agent' => $acceptance['user_agent'],
            'platform' => $acceptance['platform'],
        ],
        'terms' => [
            'id' => (int)$terms['id'],
            'version' => $terms['version'],
            'title' => $terms['title'],
        ],
    ], 'Terms accepted');
} catch (Exception $e) {
    error_log('app_terms_accept failed: ' . $e->getMessage());
    Response::serverError('Failed to record acceptance. Please try again later.');
}
