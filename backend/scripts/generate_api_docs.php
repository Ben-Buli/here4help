<?php
/**
 * API 文檔生成腳本
 * 生成 HTML 文檔和 Postman Collection
 */

require_once __DIR__ . '/../utils/ApiDocGenerator.php';

echo "🔧 Here4Help API 文檔生成器\n";
echo "==========================\n\n";

try {
    // 創建文檔生成器
    $generator = new ApiDocGenerator();
    
    // 生成 HTML 文檔
    echo "📄 生成 HTML 文檔...\n";
    $htmlFile = __DIR__ . '/../../docs/api/index.html';
    if ($generator->saveHtml($htmlFile)) {
        echo "✅ HTML 文檔已生成: $htmlFile\n";
    } else {
        echo "❌ HTML 文檔生成失敗\n";
    }
    
    // 生成 Postman Collection
    echo "\n📋 生成 Postman Collection...\n";
    $postmanFile = __DIR__ . '/../../docs/api/postman_collection.json';
    if ($generator->savePostmanCollection($postmanFile)) {
        echo "✅ Postman Collection 已生成: $postmanFile\n";
    } else {
        echo "❌ Postman Collection 生成失敗\n";
    }
    
    // 顯示文件大小
    echo "\n📊 生成的文件:\n";
    if (file_exists($htmlFile)) {
        $htmlSize = number_format(filesize($htmlFile) / 1024, 2);
        echo "   HTML 文檔: {$htmlSize} KB\n";
    }
    
    if (file_exists($postmanFile)) {
        $postmanSize = number_format(filesize($postmanFile) / 1024, 2);
        echo "   Postman Collection: {$postmanSize} KB\n";
    }
    
    echo "\n🎉 API 文檔生成完成！\n";
    echo "\n📖 查看文檔:\n";
    echo "   HTML: file://" . realpath($htmlFile) . "\n";
    echo "   Postman: 匯入 $postmanFile 到 Postman\n";
    
} catch (Exception $e) {
    echo "❌ 錯誤: " . $e->getMessage() . "\n";
    exit(1);
}
?>

