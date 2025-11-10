<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * FAQ 查看 API
 * 
 * 功能：
 * - GET: 獲取單個 FAQ 詳情並記錄查看次數
 * 
 * 路徑：GET /api/faqs/view.php?id=1
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 僅允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $faqId = (int)($_GET['id'] ?? 0);
    
    if ($faqId <= 0) {
        Response::error('Invalid FAQ ID', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取 FAQ 詳情
    $sql = "SELECT * FROM faqs WHERE id = ? AND is_active = 1";
    $stmt = $db->prepare($sql);
    $stmt->execute([$faqId]);
    $faq = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$faq) {
        Response::error('FAQ not found', 404);
    }
    
    // 注意：如果資料表有 view_count 欄位，可以取消註解以下程式碼來記錄查看次數
    // $updateSql = "UPDATE faqs SET view_count = view_count + 1 WHERE id = ?";
    // $updateStmt = $db->prepare($updateSql);
    // $updateStmt->execute([$faqId]);
    // $faq['view_count'] = (int)$faq['view_count'] + 1;
    
    Response::success($faq);
    
} catch (Exception $e) {
    error_log("FAQ View API Error: " . $e->getMessage());
    Response::error('Internal server error', 500);
}

