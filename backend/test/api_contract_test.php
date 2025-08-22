<?php
/**
 * API 合約測試腳本
 * 驗證統一回應格式、錯誤碼和分頁系統
 */

require_once __DIR__ . '/../utils/ErrorCodes.php';
require_once __DIR__ . '/../utils/TraceId.php';
require_once __DIR__ . '/../utils/Pagination.php';
require_once __DIR__ . '/../utils/Response.php';

echo "🔧 Here4Help API 合約測試\n";
echo "=======================\n\n";

// 1. 測試錯誤碼系統
echo "1. 測試錯誤碼系統\n";
echo "---------------\n";

$testCodes = [
    ErrorCodes::SUCCESS,
    ErrorCodes::UNAUTHORIZED,
    ErrorCodes::USER_NOT_FOUND,
    ErrorCodes::RATE_LIMIT_EXCEEDED,
    ErrorCodes::VALIDATION_FAILED
];

foreach ($testCodes as $code) {
    $message = ErrorCodes::getMessage($code);
    $httpCode = ErrorCodes::getHttpCode($code);
    $category = ErrorCodes::getCodeCategory($code);
    
    echo "✅ $code: $message (HTTP: $httpCode, 類別: $category)\n";
}

echo "\n";

// 2. 測試 TraceId 生成
echo "2. 測試 TraceId 生成\n";
echo "-----------------\n";

for ($i = 1; $i <= 3; $i++) {
    $traceId = TraceId::generate();
    $parsed = TraceId::parse($traceId);
    
    echo "✅ TraceId $i: $traceId\n";
    if ($parsed && isset($parsed['datetime'])) {
        echo "   時間: {$parsed['datetime']}, 進程: {$parsed['process_id']}\n";
    }
}

// 測試外部 TraceId
$externalTraceId = 'ABC123DEF456';
TraceId::set($externalTraceId);
$current = TraceId::current();
echo "✅ 外部 TraceId: $current\n";

echo "\n";

// 3. 測試分頁系統
echo "3. 測試分頁系統\n";
echo "-------------\n";

// 模擬請求參數
$_GET = ['page' => '2', 'per_page' => '10'];

$pagination = Pagination::fromRequest();
$pagination->setTotal(95);

echo "✅ 分頁參數:\n";
echo "   當前頁: {$pagination->getPage()}\n";
echo "   每頁數量: {$pagination->getPerPage()}\n";
echo "   總記錄數: {$pagination->getTotal()}\n";
echo "   總頁數: {$pagination->getTotalPages()}\n";
echo "   偏移量: {$pagination->getOffset()}\n";
echo "   有下一頁: " . ($pagination->hasNextPage() ? '是' : '否') . "\n";
echo "   有上一頁: " . ($pagination->hasPreviousPage() ? '是' : '否') . "\n";

echo "\n✅ 分頁資訊陣列:\n";
print_r($pagination->toArray());

echo "\n✅ SQL LIMIT: {$pagination->getSqlLimit()}\n";
echo "✅ 分頁描述: {$pagination->getDescription()}\n";

echo "\n";

// 4. 測試分頁驗證
echo "4. 測試分頁驗證\n";
echo "-------------\n";

$validationTests = [
    ['page' => 1, 'per_page' => 20],
    ['page' => 0, 'per_page' => 10],
    ['page' => 5, 'per_page' => 150],
    ['page' => -1, 'per_page' => -5]
];

foreach ($validationTests as $i => $params) {
    $errors = Pagination::validateParams($params['page'], $params['per_page']);
    $status = empty($errors) ? '✅' : '❌';
    echo "$status 測試 " . ($i + 1) . ": page={$params['page']}, per_page={$params['per_page']}\n";
    if (!empty($errors)) {
        foreach ($errors as $field => $error) {
            echo "   錯誤: $field - $error\n";
        }
    }
}

echo "\n";

// 5. 測試回應格式（模擬）
echo "5. 測試回應格式\n";
echo "-------------\n";

// 由於 Response 類別會 exit，我們只能模擬其邏輯
function simulateResponse($success, $code, $message, $data = null) {
    $traceId = TraceId::current();
    
    $response = [
        'success' => $success,
        'code' => $code,
        'message' => $message,
        'data' => $data,
        'traceId' => $traceId,
        'timestamp' => date('c'),
        'server_time' => time()
    ];
    
    return array_filter($response, function($value) {
        return $value !== null;
    });
}

// 成功回應
$successResponse = simulateResponse(true, ErrorCodes::SUCCESS, 'Operation completed', ['id' => 123]);
echo "✅ 成功回應格式:\n";
print_r($successResponse);

// 錯誤回應
$errorResponse = simulateResponse(false, ErrorCodes::USER_NOT_FOUND, ErrorCodes::getMessage(ErrorCodes::USER_NOT_FOUND));
echo "\n✅ 錯誤回應格式:\n";
print_r($errorResponse);

echo "\n";

// 6. 測試分頁資料包裝
echo "6. 測試分頁資料包裝\n";
echo "-----------------\n";

$mockItems = [
    ['id' => 1, 'name' => 'Item 1'],
    ['id' => 2, 'name' => 'Item 2'],
    ['id' => 3, 'name' => 'Item 3']
];

$paginatedData = Pagination::paginate($mockItems, 25, $pagination);
echo "✅ 完整分頁包裝:\n";
print_r($paginatedData);

$simplePaginatedData = Pagination::paginateSimple($mockItems, 25, $pagination);
echo "\n✅ 簡化分頁包裝:\n";
print_r($simplePaginatedData);

echo "\n";

// 7. 測試分頁連結生成
echo "7. 測試分頁連結\n";
echo "-------------\n";

$links = $pagination->generateLinks('/api/tasks', ['category' => 'work', 'status' => 'active']);
echo "✅ 分頁連結:\n";
foreach ($links as $rel => $url) {
    echo "   $rel: $url\n";
}

echo "\n🎉 API 合約測試完成！\n";

// 8. 測試統計
echo "\n8. 測試統計\n";
echo "----------\n";

echo "📊 系統統計:\n";
echo "   錯誤碼總數: " . count(ErrorCodes::getAllCodes()) . " 個\n";
echo "   分頁預設每頁: " . Pagination::DEFAULT_PER_PAGE . " 項\n";
echo "   分頁最大每頁: " . Pagination::MAX_PER_PAGE . " 項\n";
echo "   TraceId 格式: 20 字元十六進制\n";
echo "   回應格式欄位: success, code, message, data, traceId, timestamp, server_time\n";
?>

