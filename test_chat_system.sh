#!/bin/bash

# Here4Help 聊天系統測試腳本
# 用於快速測試聊天系統的各個組件

echo "=== Here4Help 聊天系統測試 ==="
echo "時間: $(date)"
echo ""

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 測試結果計數
PASSED=0
FAILED=0

# 測試函數
test_step() {
    local step_name="$1"
    local command="$2"
    local expected_output="$3"
    
    echo -e "${BLUE}測試: $step_name${NC}"
    echo "執行: $command"
    
    if eval "$command" > /tmp/test_output 2>&1; then
        if [ -n "$expected_output" ]; then
            if grep -q "$expected_output" /tmp/test_output; then
                echo -e "${GREEN}✅ 通過${NC}"
                ((PASSED++))
            else
                echo -e "${RED}❌ 失敗 - 輸出不符合預期${NC}"
                echo "預期包含: $expected_output"
                echo "實際輸出:"
                cat /tmp/test_output
                ((FAILED++))
            fi
        else
            echo -e "${GREEN}✅ 通過${NC}"
            ((PASSED++))
        fi
    else
        echo -e "${RED}❌ 失敗${NC}"
        echo "錯誤輸出:"
        cat /tmp/test_output
        ((FAILED++))
    fi
    echo ""
}

# 1. 檢查資料庫連線
echo "=== 1. 資料庫連線測試 ==="
test_step "資料庫連線" "cd backend/database && php test_connection.php" "資料庫連線成功"

# 2. 檢查資料庫結構
echo "=== 2. 資料庫結構測試 ==="
test_step "資料庫結構驗證" "cd backend/database && php quick_validate.php" "快速驗證完成"

# 3. 檢查 Socket.IO 服務
echo "=== 3. Socket.IO 服務測試 ==="
test_step "Socket.IO 健康檢查" "curl -s http://localhost:3001/health" "ok"

# 4. 檢查 PHP API 服務
echo "=== 4. PHP API 服務測試 ==="
test_step "PHP API 基礎連線" "curl -s -I http://localhost:8888/here4help/backend/api/chat/get_rooms.php" "HTTP"

# 5. 檢查 Node.js 依賴
echo "=== 5. Node.js 依賴檢查 ==="
test_step "Socket 依賴檢查" "cd backend/socket && npm list --depth=0" "mysql2"

# 6. 檢查 Flutter 配置
echo "=== 6. Flutter 配置檢查 ==="
test_step "Flutter 依賴檢查" "flutter pub get" "Resolving dependencies"

# 7. 檢查必要的檔案
echo "=== 7. 檔案完整性檢查 ==="
test_step "ChatService 檔案" "test -f lib/chat/services/chat_service.dart" ""
test_step "Socket 服務檔案" "test -f backend/socket/server.js" ""
test_step "API 端點檔案" "test -f backend/api/chat/get_messages.php" ""
test_step "API 端點檔案" "test -f backend/api/chat/get_rooms.php" ""

# 8. 檢查端口使用情況
echo "=== 8. 端口使用檢查 ==="
test_step "端口 3001 檢查" "lsof -i :3001 > /dev/null 2>&1" ""
test_step "端口 8888 檢查" "lsof -i :8888 > /dev/null 2>&1" ""

# 9. 檢查資料庫表格
echo "=== 9. 資料庫表格檢查 ==="
test_step "聊天表格檢查" "cd backend/database && php -r \"require 'test_connection.php'; \$db = Database::getInstance(); \$result = \$db->fetch('SELECT COUNT(*) as count FROM chat_rooms'); echo \$result['count'] >= 0 ? 'OK' : 'FAIL'; \"" "OK"

# 總結
echo "=== 測試總結 ==="
echo -e "${GREEN}通過: $PASSED${NC}"
echo -e "${RED}失敗: $FAILED${NC}"
echo "總計: $((PASSED + FAILED))"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 所有測試通過！聊天系統準備就緒。${NC}"
    echo ""
    echo "下一步："
    echo "1. 啟動 Flutter 應用: flutter run"
    echo "2. 登入測試帳戶"
    echo "3. 測試聊天功能"
else
    echo -e "${RED}⚠️  發現 $FAILED 個問題，請檢查上述錯誤。${NC}"
    echo ""
    echo "常見解決方案："
    echo "1. 啟動 Socket.IO 服務: cd backend/socket && npm start"
    echo "2. 啟動 PHP 服務"
    echo "3. 檢查資料庫連線"
    echo "4. 確認端口未被佔用"
fi

# 清理臨時檔案
rm -f /tmp/test_output

echo ""
echo "測試完成時間: $(date)" 