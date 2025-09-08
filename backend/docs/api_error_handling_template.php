<?php
/**
 * API 錯誤處理模板
 * 
 * 這個模板展示了如何正確處理 PHP API 中的錯誤，
 * 確保始終返回正確的 JSON 格式而不是 HTML 錯誤頁面
 */

// ============================================
// 1. 文件開頭：防止錯誤輸出干擾 JSON
// ============================================

// 開啟輸出緩衝，防止錯誤輸出干擾 JSON
ob_start();

// 設置錯誤處理：不顯示錯誤，只記錄到日誌
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// 引入必要的文件
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 清除任何之前的輸出（包括可能的錯誤輸出）
ob_clean();

// 設置響應頭
header('Content-Type: application/json');
Response::setCorsHeaders();

// ============================================
// 2. OPTIONS 請求處理
// ============================================
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// ============================================
// 3. 主要邏輯包裝在 try-catch 中
// ============================================
try {
    // 方法驗證
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::methodNotAllowed('Only POST method is allowed');
    }

    // JWT 認證（標準模式）
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::unauthorized($tokenValidation['message']);
    }
    
    $tokenData = $tokenValidation['payload'];
    $userId = $tokenData['user_id'];

    // 獲取和驗證輸入
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }

    // 驗證必要參數
    $requiredParam = $input['required_param'] ?? null;
    if (!$requiredParam) {
        Response::badRequest('required_param is required');
    }

    // 資料庫操作
    $db = Database::getInstance()->getConnection();
    $db->beginTransaction();
    
    try {
        // 執行資料庫操作
        $stmt = $db->prepare("SELECT * FROM some_table WHERE id = ?");
        $stmt->execute([$requiredParam]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$result) {
            Response::notFound('Resource not found');
        }
        
        // 更多業務邏輯...
        
        $db->commit();
        
        // 成功響應
        Response::success($result, 'Operation completed successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e; // 重新拋出，讓外層 catch 處理
    }

// ============================================
// 4. 完善的錯誤處理
// ============================================
} catch (PDOException $e) {
    // 清除輸出緩衝區的任何錯誤輸出
    ob_clean();
    error_log("Database error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    Response::serverError('Database error occurred');
    
} catch (Exception $e) {
    // 清除輸出緩衝區的任何錯誤輸出
    ob_clean();
    error_log("API error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    Response::serverError('An error occurred while processing request');
    
} catch (Throwable $e) {
    // 捕獲所有可能的錯誤，包括 Fatal Error
    ob_clean();
    error_log("Fatal error: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    Response::serverError('A critical error occurred');
}

// ============================================
// 5. 可選：全局錯誤處理器（在文件開頭設置）
// ============================================

/*
// 設置自定義錯誤處理器
set_error_handler(function($severity, $message, $file, $line) {
    // 記錄錯誤到日誌
    error_log("PHP Error: $message in $file on line $line");
    
    // 如果是致命錯誤，返回 JSON 錯誤響應
    if ($severity === E_ERROR || $severity === E_CORE_ERROR || $severity === E_COMPILE_ERROR) {
        ob_clean();
        Response::serverError('A system error occurred');
    }
});

// 設置異常處理器
set_exception_handler(function($exception) {
    ob_clean();
    error_log("Uncaught exception: " . $exception->getMessage());
    Response::serverError('An unexpected error occurred');
});

// 設置致命錯誤處理器
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_CORE_ERROR, E_COMPILE_ERROR, E_PARSE])) {
        ob_clean();
        error_log("Fatal error: " . $error['message']);
        Response::serverError('A fatal error occurred');
    }
});
*/

?>

<!-- 
使用說明：

1. 複製這個模板到新的 API 文件
2. 修改業務邏輯部分
3. 確保所有可能的錯誤都被捕獲
4. 測試各種錯誤情況

常見錯誤類型：
- 語法錯誤：會被 Throwable 捕獲
- 資料庫錯誤：會被 PDOException 捕獲  
- 業務邏輯錯誤：會被 Exception 捕獲
- 致命錯誤：需要 register_shutdown_function

最佳實踐：
- 始終使用 ob_start() 和 ob_clean()
- 設置 display_errors = 0
- 詳細記錄錯誤到日誌
- 使用統一的 Response 類
- 捕獲 Throwable 而不只是 Exception
-->
