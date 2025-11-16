<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

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
    $terms = TermsManager::getActiveTerms(true);

    if (!$terms) {
        Response::success([
            'terms' => null,
        ], 'No terms found');
    }

    Response::success([
        'terms' => [
            'id' => (int)$terms['id'],
            'version' => $terms['version'],
            'title' => $terms['title'],
            'content' => $terms['content'],
            'is_active' => (int)$terms['is_active'] === 1,
            'created_by' => $terms['created_by'] ? (int)$terms['created_by'] : null,
            'created_at' => $terms['created_at'],
            'updated_at' => $terms['updated_at'],
        ],
    ]);
} catch (Exception $e) {
    Response::serverError('Failed to load active terms: ' . $e->getMessage());
}

