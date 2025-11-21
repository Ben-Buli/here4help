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

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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

    $userId = (int)$payload['user_id'];

    try {
        $terms = TermsManager::getActiveTerms(true);
    } catch (Exception $e) {
        error_log("Failed to get active terms: " . $e->getMessage());
        $terms = null;
    }

    try {
        $latestAcceptance = TermsManager::getLatestAcceptance($userId);
    } catch (Exception $e) {
        error_log("Failed to get latest acceptance for user {$userId}: " . $e->getMessage());
        $latestAcceptance = null;
    }

    $requiresAcceptance = false;
    if ($terms) {
        if (!empty($terms['requires_ack'])) {
            $requiresAcceptance = !$latestAcceptance ||
                ((int)$latestAcceptance['accepted_version_id'] !== (int)$terms['id']);
        } else {
            // 不需要重新確認時，只在使用者從未同意過任意版本時提示
            $requiresAcceptance = !$latestAcceptance;
        }
    }

    Response::success([
        'requires_acceptance' => $requiresAcceptance,
        'terms' => $terms ? [
            'id' => (int)$terms['id'],
            'version' => $terms['version'],
            'title' => $terms['title'],
            'content' => $terms['content'],
            'is_active' => (int)$terms['is_active'] === 1,
            'created_at' => $terms['created_at'],
            'updated_at' => $terms['updated_at'],
        ] : null,
        'latest_acceptance' => $latestAcceptance ? [
            'id' => (int)$latestAcceptance['id'],
            'accepted_version_id' => (int)$latestAcceptance['accepted_version_id'],
            'accepted_at' => $latestAcceptance['accepted_at'],
            'version' => $latestAcceptance['version'] ?? null,
            'title' => $latestAcceptance['title'] ?? null,
            'device_info' => $latestAcceptance['device_info'] ?? null,
            'platform' => $latestAcceptance['platform'] ?? null,
        ] : null,
    ]);
} catch (Exception $e) {
    error_log("Terms Status API Error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    Response::serverError('Failed to load terms status: ' . $e->getMessage());
}

