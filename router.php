<?php
/**
 * PHP Built-in Server Router
 * 處理開發環境的路由請求
 */

// 檢查是否為靜態檔案
$request_uri = $_SERVER['REQUEST_URI'];
$file_path = __DIR__ . parse_url($request_uri, PHP_URL_PATH);

// 如果是實際存在的檔案，直接返回
if (is_file($file_path)) {
    return false;
}

// 處理 CORS 預檢請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
    header('HTTP/1.1 200 OK');
    exit();
}

// 設置 CORS 標頭
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');

// 解析請求路徑
$path = parse_url($request_uri, PHP_URL_PATH);

// 移除前綴路徑 /here4help 如果存在
if (strpos($path, '/here4help') === 0) {
    $path = substr($path, 10); // 移除 '/here4help'
}

// 管理後臺 Laravel API & Sanctum
if (
    strpos($path, '/api/admin') === 0 ||
    strpos($path, '/sanctum') === 0 ||
    strpos($path, '/admintest') === 0
) {
    $_SERVER['SCRIPT_FILENAME'] = __DIR__ . '/admin/index.php';
    require $_SERVER['SCRIPT_FILENAME'];
    exit();
}

// 管理後臺靜態資源
if (strpos($path, '/admin/assets/') === 0) {
    $assetPath = __DIR__ . '/admin/public' . $path;
    if (file_exists($assetPath)) {
        header('Content-Type: ' . mime_content_type($assetPath));
        readfile($assetPath);
        exit();
    }
}

if (preg_match('#^/admin/.*\.(ico|png|jpg|jpeg|svg|json|webmanifest)$#i', $path)) {
    $staticPath = __DIR__ . '/admin/public' . $path;
    if (file_exists($staticPath)) {
        header('Content-Type: ' . mime_content_type($staticPath));
        readfile($staticPath);
        exit();
    }
}

// Admin API 路由處理
if (preg_match('/^\/backend\/api\/admin\/users\/(\d+)\/(verification|referral-info|intro-referral-info|review)$/', $path, $matches)) {
    $userId = $matches[1];
    $action = $matches[2];
    
    // 設置環境變數以供 PHP 檔案使用
    $_SERVER['REQUEST_URI'] = "/backend/api/admin/users/$userId/$action";
    
    // 根據動作映射到對應的 PHP 檔案
    $filePath = __DIR__ . "/backend/api/admin/users/$action.php";
    
    if (file_exists($filePath)) {
        include $filePath;
        exit();
    }
}

// 其他 API 路由處理
if (strpos($path, '/backend/api/') === 0) {
    $apiPath = substr($path, 12); // 移除 '/backend/api'
    $filePath = __DIR__ . "/backend/api/$apiPath.php";
    
    if (file_exists($filePath)) {
        include $filePath;
        exit();
    }
}

// 處理上傳文件路由
if (strpos($path, '/uploads/') === 0) {
    // 將 /uploads/ 路徑轉換為實際的檔案路徑
    $uploadPath = __DIR__ . '/backend' . $path;
    if (file_exists($uploadPath)) {
        // 設置適當的 MIME 類型
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $uploadPath);
        finfo_close($finfo);
        
        header("Content-Type: $mimeType");
        readfile($uploadPath);
        exit();
    }
}

// 處理後端上傳文件路由（向後兼容）
if (strpos($path, '/backend/uploads/') === 0) {
    $uploadPath = __DIR__ . $path;
    if (file_exists($uploadPath)) {
        // 設置適當的 MIME 類型
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $uploadPath);
        finfo_close($finfo);
        
        header("Content-Type: $mimeType");
        readfile($uploadPath);
        exit();
    }
}

// 管理後台路由 (Vue SPA)
if (strpos($path, '/admin') === 0) {
    $adminIndex = __DIR__ . '/admin/public/index.html';
    if (!file_exists($adminIndex)) {
        // 後備：開發環境尚未 build 時，讀取 frontend/dist
        $adminIndex = __DIR__ . '/admin/frontend/dist/index.html';
    }
    if (file_exists($adminIndex)) {
        include $adminIndex;
        exit();
    }
}

// Flutter Web 應用路由 (預設)
$webIndexPath = __DIR__ . '/web/index.html';
if (file_exists($webIndexPath)) {
    include $webIndexPath;
    exit();
}

// 如果沒有匹配的路由，返回 404
http_response_code(404);
echo json_encode(['error' => 'Not Found', 'path' => $path]);
?>
