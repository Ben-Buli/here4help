#!/bin/bash
# fix_hardcoded_localhost.sh - 批量修復硬編程的 localhost 和 URL

echo "🔧 批量修復硬編程的 localhost 和 URL..."
echo "=================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 修復計數器
FIXED_COUNT=0

echo -e "${BLUE}1. 修復 Flutter 測試文件中的硬編程 URL...${NC}"

# 修復 Flutter 測試文件
for file in lib/test/*.dart; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "test_config.dart" ]; then
        echo "  修復: $file"
        
        # 替換硬編程的 localhost URL
        sed -i '' 's|http://localhost:8888/here4help/backend/uploads/avatars/|TestConfig.getImageUrl("/backend/uploads/avatars/")|g' "$file"
        sed -i '' 's|http://localhost:8888/here4help/backend/uploads/avatars/|TestConfig.getImageUrl("/backend/uploads/avatars/")|g' "$file"
        
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo -e "${BLUE}2. 修復後端 API 文件中的硬編程 URL...${NC}"

# 修復後端 API 文件中的硬編程 Socket URL
API_FILES=(
    "backend/api/support/create_issue.php"
    "backend/api/support/events.php"
    "backend/api/support/resolve.php"
    "backend/api/support/events_close.php"
    "backend/api/chat/send_message.php"
    "backend/socket/notification_handler.php"
)

for file in "${API_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  修復: $file"
        
        # 替換硬編程的 Socket URL
        sed -i '' 's|http://localhost:3001|EnvLoader::get("SOCKET_SERVER_URL", "http://localhost:3001")|g' "$file"
        
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo -e "${BLUE}3. 修復後端測試文件中的硬編程 URL...${NC}"

# 修復後端測試文件
for file in backend/test/*.php; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "config.php" ]; then
        echo "  修復: $file"
        
        # 替換硬編程的 API URL
        sed -i '' 's|http://localhost:8888/here4help/backend/api|TestConfig::getApiUrl("")|g' "$file"
        sed -i '' 's|http://localhost:8888/here4help/backend/api/|TestConfig::getApiUrl("/")|g' "$file"
        
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo -e "${BLUE}4. 修復 Admin 配置中的硬編程 URL...${NC}"

# 修復 Admin 配置
ADMIN_FILES=(
    "admin/frontend/vite.config.ts"
    "admin/frontend/src/config/api.ts"
    "admin/frontend/src/config/env.ts"
    "admin/frontend/src/config/app.ts"
)

for file in "${ADMIN_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  修復: $file"
        
        # 替換硬編程的 localhost URL
        sed -i '' 's|http://localhost:8888/here4help/backend|import.meta.env.VITE_API_BASE_URL \|\| "http://localhost:8888/here4help/backend"|g' "$file"
        sed -i '' 's|http://localhost:3001|import.meta.env.VITE_SOCKET_URL \|\| "http://localhost:3001"|g' "$file"
        sed -i '' 's|http://localhost:8000|import.meta.env.VITE_ADMIN_API_URL \|\| "http://localhost:8000"|g' "$file"
        
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo -e "${BLUE}5. 修復 Admin PHP 文件中的硬編程 URL...${NC}"

# 修復 Admin PHP 文件
ADMIN_PHP_FILES=(
    "admin/app/Http/Controllers/Admin/SupportController.php"
)

for file in "${ADMIN_PHP_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  修復: $file"
        
        # 替換硬編程的 Socket URL
        sed -i '' 's|http://localhost:3001|env("SOCKET_SERVER_URL", "http://localhost:3001")|g' "$file"
        
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo ""
echo "=================================="
echo -e "${GREEN}✅ 修復完成！${NC}"
echo "=================================="
echo -e "${BLUE}修復統計：${NC}"
echo "  - 修復文件數量: $FIXED_COUNT"
echo "  - Flutter 測試文件: 已修復"
echo "  - 後端 API 文件: 已修復"
echo "  - 後端測試文件: 已修復"
echo "  - Admin 配置: 已修復"
echo ""
echo -e "${BLUE}📋 修復內容：${NC}"
echo "  - 硬編程的 localhost URL → 環境變數"
echo "  - 硬編程的 Socket URL → 環境變數"
echo "  - 硬編程的 API URL → 環境變數"
echo ""
echo -e "${BLUE}🚀 後續步驟：${NC}"
echo "  1. 檢查修復結果: grep -r 'localhost' lib/ backend/ admin/ | grep -v '.env'"
echo "  2. 測試功能: flutter run --dart-define=ENVIRONMENT=development"
echo "  3. 驗證部署: 確保所有環境變數正確配置"
echo ""
echo -e "${YELLOW}⚠️ 注意：${NC}"
echo "  - 部分文件可能需要手動調整"
echo "  - 請檢查修復後的代碼語法"
echo "  - 確保環境變數在部署環境中正確配置"
