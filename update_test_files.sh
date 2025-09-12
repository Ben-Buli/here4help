#!/bin/bash
# update_test_files.sh - 批量更新測試文件以使用新的配置系統

echo "🔄 更新測試文件以使用新的配置系統..."

# 更新後端測試文件
echo "📁 更新後端測試文件..."

# 更新所有後端測試文件
for file in backend/test/*.php; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "config.php" ]; then
        echo "  更新: $file"
        
        # 檢查是否已經使用了 TestConfig
        if ! grep -q "TestConfig" "$file"; then
            # 添加 TestConfig 導入
            sed -i '' '1i\
<?php\
require_once __DIR__ . "/config.php";\
' "$file"
            
            # 替換硬編程的 URL
            sed -i '' 's|http://localhost:8888/here4help/backend/api|TestConfig::getApiUrl("")|g' "$file"
            sed -i '' 's|http://localhost:8888/here4help/backend|TestConfig::getApiBaseUrl()|g' "$file"
            sed -i '' 's|http://localhost:8888/here4help|TestConfig::getAppUrl()|g' "$file"
            sed -i '' 's|http://localhost:3001|TestConfig::getSocketUrl()|g' "$file"
        fi
    fi
done

# 更新 Flutter 測試文件
echo "📁 更新 Flutter 測試文件..."

# 更新所有 Flutter 測試文件
for file in lib/test/*.dart; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "test_config.dart" ]; then
        echo "  更新: $file"
        
        # 檢查是否已經導入了 TestConfig
        if ! grep -q "test_config.dart" "$file"; then
            # 添加 TestConfig 導入
            sed -i '' '1i\
import "test_config.dart";\
' "$file"
        fi
        
        # 替換硬編程的 URL
        sed -i '' 's|ws://localhost:3001|TestConfig.socketUrl|g' "$file"
        sed -i '' 's|http://localhost:8888/here4help/backend/api|TestConfig.getApiUrl("")|g' "$file"
        sed -i '' 's|http://localhost:8888/here4help/backend|TestConfig.apiBaseUrl|g' "$file"
        sed -i '' 's|http://localhost:8888/here4help|TestConfig.appUrl|g' "$file"
    fi
done

echo "✅ 測試文件更新完成！"
echo ""
echo "📋 更新摘要："
echo "  - 後端測試文件：使用 TestConfig 類"
echo "  - Flutter 測試文件：使用 TestConfig 類"
echo "  - 所有硬編程 URL 已替換為環境變數"
echo ""
echo "🧪 測試配置："
echo "  - API Base URL: http://localhost:8888/here4help/backend"
echo "  - Socket URL: ws://localhost:3001"
echo "  - Image Base URL: http://localhost:8888/here4help"
echo ""
echo "💡 使用說明："
echo "  - 後端測試：php backend/test/your_test.php"
echo "  - Flutter 測試：flutter test lib/test/your_test.dart"
