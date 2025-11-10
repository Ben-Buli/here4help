<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * FAQ 列表 API
 * 
 * 功能：
 * - GET: 獲取 FAQ 列表（公開 API，無需認證）
 * - 支援篩選：category, language
 * - 支援分頁和排序
 * 
 * 路徑：GET /api/faqs/list.php
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
    $db = Database::getInstance()->getConnection();
    
    // 獲取查詢參數
    $category = $_GET['category'] ?? '';
    $language = $_GET['language'] ?? 'en'; // 預設為英語
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = min(100, max(1, (int)($_GET['per_page'] ?? 50)));
    $offset = ($page - 1) * $perPage;
    
    // 構建查詢條件
    $conditions = ['is_active = 1'];
    $params = [];
    
    if (!empty($category)) {
        $conditions[] = 'category = ?';
        $params[] = $category;
    }
    
    if (!empty($language)) {
        $conditions[] = 'language = ?';
        $params[] = $language;
    }
    
    $whereClause = implode(' AND ', $conditions);
    
    // 獲取總數
    $countSql = "SELECT COUNT(*) as total FROM faqs WHERE $whereClause";
    $countStmt = $db->prepare($countSql);
    $countStmt->execute($params);
    $total = (int)$countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 獲取 FAQ 列表
    $sql = "
        SELECT 
            id,
            question,
            answer,
            category,
            language,
            sort_order,
            is_active,
            created_at,
            updated_at
        FROM faqs
        WHERE $whereClause
        ORDER BY sort_order ASC, created_at DESC
        LIMIT ? OFFSET ?
    ";
    
    $stmt = $db->prepare($sql);
    $stmt->execute([...$params, $perPage, $offset]);
    $faqs = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    Response::success([
        'faqs' => $faqs,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'total_pages' => ceil($total / $perPage)
        ]
    ]);
    
} catch (PDOException $e) {
    // 資料庫錯誤
    error_log("FAQ List API Database Error: " . $e->getMessage());
    error_log("SQL Error Code: " . $e->getCode());
    Response::error('DATABASE_ERROR', 'Failed to fetch FAQs from database');
} catch (Exception $e) {
    // 其他錯誤
    error_log("FAQ List API Error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    Response::error('Internal server error', 500);
}

