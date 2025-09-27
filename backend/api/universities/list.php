<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $db = Database::getInstance();
    
    // 先檢查 universities 表是否存在
    $tableExists = $db->fetch("SHOW TABLES LIKE 'universities'");
    
    if ($tableExists) {
        $sql = "SELECT id, zh_name, en_name, abbr FROM universities ORDER BY zh_name ASC";
        $universities = $db->fetchAll($sql);
    } else {
        // 如果表不存在，返回預設數據
        $universities = [
            ['abbr' => 'NTU', 'zh_name' => '國立台灣大學', 'en_name' => 'National Taiwan University'],
            ['abbr' => 'NCCU', 'zh_name' => '國立政治大學', 'en_name' => 'National Chengchi University'],
            ['abbr' => 'NTHU', 'zh_name' => '國立清華大學', 'en_name' => 'National Tsing Hua University'],
            ['abbr' => 'NCKU', 'zh_name' => '國立成功大學', 'en_name' => 'National Cheng Kung University'],
            ['abbr' => 'NYCU', 'zh_name' => '國立陽明交通大學', 'en_name' => 'National Yang Ming Chiao Tung University'],
            ['abbr' => 'NTNU', 'zh_name' => '國立師範大學', 'en_name' => 'National Taiwan Normal University'],
            ['abbr' => 'CYCU', 'zh_name' => '中原大學', 'en_name' => 'Chung Yuan Christian University'],
            ['abbr' => 'FJU', 'zh_name' => '輔仁大學', 'en_name' => 'Fu Jen Catholic University']
        ];
    }

    Response::success($universities, 'Universities retrieved successfully');

} catch (PDOException $e) {
    // 數據庫錯誤時返回預設數據
    $defaultUniversities = [
        ['abbr' => 'NTU', 'zh_name' => '國立台灣大學', 'en_name' => 'National Taiwan University'],
        ['abbr' => 'NCCU', 'zh_name' => '國立政治大學', 'en_name' => 'National Chengchi University'],
        ['abbr' => 'NTHU', 'zh_name' => '國立清華大學', 'en_name' => 'National Tsing Hua University'],
        ['abbr' => 'NCKU', 'zh_name' => '國立成功大學', 'en_name' => 'National Cheng Kung University']
    ];
    Response::success($defaultUniversities, 'Universities retrieved from fallback data');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 