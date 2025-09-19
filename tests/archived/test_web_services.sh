#!/bin/bash

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Here4Help 網頁服務測試 ===${NC}"
echo "時間: $(date)"
echo ""

# 測試函數
test_service() {
    local name="$1"
    local command="$2"
    local expected="$3"
    
    echo -e "${YELLOW}測試: $name${NC}"
    echo "執行: $command"
    
    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✅ 通過${NC}"
        return 0
    else
        echo -e "${RED}❌ 失敗${NC}"
        return 1
    fi
}

# 測試計數
passed=0
failed=0

echo "=== 1. 服務端口檢查 ==="
test_service "Flutter 網頁服務 (8080)" "lsof -i :8080" "dart" && ((passed++)) || ((failed++))
test_service "Socket.IO 服務 (3001)" "lsof -i :3001" "node" && ((passed++)) || ((failed++))
test_service "PHP 服務 (8888)" "lsof -i :8888" "httpd" && ((passed++)) || ((failed++))

echo ""
echo "=== 2. 服務健康檢查 ==="
test_service "Flutter 網頁" "curl -s -I http://localhost:8080" "HTTP" && ((passed++)) || ((failed++))
test_service "Socket.IO 健康檢查" "curl -s http://localhost:3001/health" "ok" && ((passed++)) || ((failed++))
test_service "PHP API 基礎連線" "curl -s -I http://localhost:8888/here4help/backend/api/chat/get_rooms.php" "HTTP" && ((passed++)) || ((failed++))

echo ""
echo "=== 3. 資料庫連線檢查 ==="
if cd backend/database && php test_connection.php > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 資料庫連線正常${NC}"
    ((passed++))
else
    echo -e "${RED}❌ 資料庫連線失敗${NC}"
    ((failed++))
fi

echo ""
echo "=== 4. 檔案完整性檢查 ==="
if test -f lib/chat/services/chat_service.dart; then
    echo -e "${GREEN}✅ ChatService 檔案存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ ChatService 檔案不存在${NC}"
    ((failed++))
fi

if test -f backend/socket/server.js; then
    echo -e "${GREEN}✅ Socket 服務檔案存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ Socket 服務檔案不存在${NC}"
    ((failed++))
fi

if test -f backend/api/chat/get_messages.php; then
    echo -e "${GREEN}✅ API 端點檔案存在${NC}"
    ((passed++))
else
    echo -e "${RED}❌ API 端點檔案不存在${NC}"
    ((failed++))
fi

echo ""
echo "=== 測試總結 ==="
echo -e "${GREEN}通過: $passed${NC}"
echo -e "${RED}失敗: $failed${NC}"
echo "總計: $((passed + failed))"

if [ $failed -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 所有服務正常！可以開始測試聊天系統了。${NC}"
    echo ""
    echo -e "${BLUE}下一步：${NC}"
    echo "1. 開啟瀏覽器訪問: http://localhost:8080"
    echo "2. 登入您的帳號"
    echo "3. 點擊底部導航的「聊天」選項"
    echo "4. 開始測試聊天功能"
    echo ""
    echo -e "${YELLOW}詳細測試指南請參考: docs/flutter-web-testing-guide.md${NC}"
else
    echo ""
    echo -e "${RED}⚠️  發現 $failed 個問題，請檢查上述錯誤。${NC}"
    echo ""
    echo "常見解決方案："
    echo "1. 啟動 Socket.IO 服務: cd backend/socket && npm start"
    echo "2. 啟動 Flutter 網頁: flutter run -d chrome --web-port=8080"
    echo "3. 檢查資料庫連線"
    echo "4. 確認端口未被佔用"
fi

echo ""
echo "測試完成時間: $(date)" 