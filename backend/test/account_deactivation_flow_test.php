<?php
/**
 * 簡易端對端測試：帳號停用/恢復流程
 * 使用方式：php backend/test/account_deactivation_flow_test.php
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/JWTManager.php';

function http_request($method, $url, $token = null, $body = null) {
    $headers = [
        'Content-Type: application/json',
        'Accept: application/json',
    ];
    if ($token) {
        $headers[] = 'Authorization: Bearer ' . $token;
    }

    $options = [
        'http' => [
            'method' => $method,
            'header' => implode("\r\n", $headers),
            'ignore_errors' => true, // 讓非 200 也能讀取 body
        ],
    ];

    if ($body !== null) {
        $options['http']['content'] = is_string($body) ? $body : json_encode($body);
    }

    $context = stream_context_create($options);
    $resp = @file_get_contents($url, false, $context);

    // 解析狀態碼
    $status = 0;
    if (isset($http_response_header) && is_array($http_response_header)) {
        foreach ($http_response_header as $h) {
            if (preg_match('#^HTTP/\S+\s+(\d{3})#', $h, $m)) {
                $status = (int)$m[1];
                break;
            }
        }
    }

    return [$status, $resp, null];
}

function print_section($title) {
    echo "\n=== $title ===\n";
}

try {
    $db = Database::getInstance();
    // 找一個狀態為 active 的使用者用於測試
    $user = $db->fetch("SELECT id, email, permission, status FROM users WHERE status = 'active' LIMIT 1");
    if (!$user) {
        throw new Exception('找不到可用的 active 使用者');
    }
    $userId = (int)$user['id'];

    // 產生測試用 token
    $token = JWTManager::generateToken(['user_id' => $userId, 'email' => $user['email'], 'name' => 'TestUser']);

    $apiBase = 'http://localhost:8888/here4help/backend/api/account';

    // 1) 先檢查 risky-actions
    print_section('Risky Actions Check');
    [$s1, $b1] = http_request('GET', $apiBase . '/risky-actions-check.php?token=' . urlencode($token), $token);
    echo "Status: $s1\nBody: $b1\n";

    // 2) 嘗試停用（若有 active 任務，應回 400 並帶錯誤訊息）
    print_section('Deactivate');
    [$s2, $b2] = http_request('POST', $apiBase . '/deactivate.php?token=' . urlencode($token), $token);
    echo "Status: $s2\nBody: $b2\n";

    // 3) 測試 reactivate
    print_section('Reactivate');
    [$s3, $b3] = http_request('POST', $apiBase . '/reactivate.php?token=' . urlencode($token), $token);
    echo "Status: $s3\nBody: $b3\n";

    echo "\n測試完成。請核對狀態碼與 JSON 是否符合預期。\n";
} catch (Exception $ex) {
    echo "測試失敗: " . $ex->getMessage() . "\n";
}
