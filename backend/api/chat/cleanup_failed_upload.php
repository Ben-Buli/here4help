<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * 清理失敗的圖片上傳檔案
 * 
 * POST /api/chat/cleanup_failed_upload.php
 * Body: { "file_path": "uploads/chat/att_xxx.jpg" }
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  // Auth
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    throw new Exception('Authorization header required');
  }
  $user_id = TokenValidator::validateAuthHeader($auth_header);
  if (!$user_id) { throw new Exception('Invalid or expired token'); }
  $user_id = (int)$user_id;

  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  $file_path = trim((string)($input['file_path'] ?? ''));
  
  if (empty($file_path)) {
    Response::validationError(['file_path' => 'required']);
  }

  // 安全檢查：只允許清理 backend/uploads/chat/ 或 uploads/chat/ 目錄下的檔案
  if (!preg_match('/^(backend\/)?uploads\/chat\/att_[a-f0-9]+\.[a-z]+$/i', $file_path)) {
    Response::error('Invalid file path format', 400);
  }

  // 構建完整的檔案路徑
  $fullPath = dirname(__DIR__, 2) . '/' . $file_path;
  
  // 檢查檔案是否存在並刪除
  $deleted = false;
  if (file_exists($fullPath)) {
    if (unlink($fullPath)) {
      $deleted = true;
      error_log("Cleaned up failed upload: $fullPath by user $user_id");
    } else {
      throw new Exception('Failed to delete file');
    }
  }

  Response::success([
    'file_path' => $file_path,
    'deleted' => $deleted,
    'existed' => file_exists($fullPath) || $deleted,
  ], $deleted ? 'File deleted successfully' : 'File not found (may already be deleted)');

} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>
