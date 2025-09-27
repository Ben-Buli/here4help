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
    
    // 先檢查 languages 表是否存在
    $tableExists = $db->fetch("SHOW TABLES LIKE 'languages'");
    
    if ($tableExists) {
        $sql = "SELECT id, code, name, native FROM languages ORDER BY name ASC";
        $languages = $db->fetchAll($sql);
    } else {
        // 如果表不存在，返回預設數據
        $languages = [
            ['code' => 'en', 'name' => 'English', 'native' => 'English'],
            ['code' => 'zh', 'name' => 'Chinese', 'native' => '中文'],
            ['code' => 'zh-tw', 'name' => 'Traditional Chinese', 'native' => '繁體中文'],
            ['code' => 'zh-cn', 'name' => 'Simplified Chinese', 'native' => '簡體中文'],
            ['code' => 'ja', 'name' => 'Japanese', 'native' => '日本語'],
            ['code' => 'ko', 'name' => 'Korean', 'native' => '한국어'],
            ['code' => 'th', 'name' => 'Thai', 'native' => 'ไทย'],
            ['code' => 'vi', 'name' => 'Vietnamese', 'native' => 'Tiếng Việt'],
            ['code' => 'id', 'name' => 'Indonesian', 'native' => 'Bahasa Indonesia'],
            ['code' => 'ms', 'name' => 'Malay', 'native' => 'Bahasa Melayu']
        ];
    }

    Response::success($languages, 'Languages retrieved successfully');

} catch (PDOException $e) {
    // 數據庫錯誤時返回預設數據
    $defaultLanguages = [
        ['code' => 'en', 'name' => 'English', 'native' => 'English'],
        ['code' => 'zh', 'name' => 'Chinese', 'native' => '中文'],
        ['code' => 'ja', 'name' => 'Japanese', 'native' => '日本語'],
        ['code' => 'ko', 'name' => 'Korean', 'native' => '한국어']
    ];
    Response::success($defaultLanguages, 'Languages retrieved from fallback data');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 