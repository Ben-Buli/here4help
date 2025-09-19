#!/bin/bash

# =============================================================================
# Here4Help CPanel 部署測試腳本
# 測試 Backend、Admin、Flutter Web 部署是否成功
# =============================================================================

# 設定顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 設定測試 URL
BASE_URL="https://hero4help.demofhs.com"
BACKEND_URL="${BASE_URL}/backend"
ADMIN_URL="${BASE_URL}/admin"
FRONTEND_URL="${BASE_URL}/frontend"

echo -e "${BLUE}🚀 Here4Help CPanel 部署測試開始${NC}"
echo "=================================================="

# 測試函數
test_endpoint() {
    local url=$1
    local expected_status=$2
    local description=$3
    
    echo -n "測試 ${description}: "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✅ 成功 (HTTP $response)${NC}"
        return 0
    else
        echo -e "${RED}❌ 失敗 (HTTP $response, 預期 $expected_status)${NC}"
        return 1
    fi
}

test_content() {
    local url=$1
    local expected_content=$2
    local description=$3
    
    echo -n "測試 ${description}: "
    
    content=$(curl -s "$url")
    
    if echo "$content" | grep -q "$expected_content"; then
        echo -e "${GREEN}✅ 成功${NC}"
        return 0
    else
        echo -e "${RED}❌ 失敗 (未找到預期內容)${NC}"
        return 1
    fi
}

# 測試計數器
total_tests=0
passed_tests=0

# =============================================================================
# Backend API 測試
# =============================================================================
echo -e "\n${YELLOW}📡 Backend API 測試${NC}"
echo "----------------------------------------"

# 測試 API 健康檢查
test_endpoint "${BACKEND_URL}/api/ping.php" "200" "API 健康檢查"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試簡單功能
test_endpoint "${BACKEND_URL}/api/test_simple.php" "200" "簡單功能測試"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試 API 回應內容
test_content "${BACKEND_URL}/api/ping.php" "pong" "API 回應內容"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# =============================================================================
# Admin 後台測試
# =============================================================================
echo -e "\n${YELLOW}👨‍💼 Admin 後台測試${NC}"
echo "----------------------------------------"

# 測試管理後台
test_endpoint "${ADMIN_URL}" "200" "管理後台首頁"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試管理後台內容
test_content "${ADMIN_URL}" "Here4Help" "管理後台內容"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# =============================================================================
# Flutter Web 測試
# =============================================================================
echo -e "\n${YELLOW}🌐 Flutter Web 測試${NC}"
echo "----------------------------------------"

# 測試 Flutter Web 主頁
test_endpoint "${FRONTEND_URL}/" "200" "Flutter Web 主頁"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試 JavaScript 檔案
test_endpoint "${FRONTEND_URL}/flutter_bootstrap.js" "200" "Flutter 啟動程式"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試主程式檔案
test_endpoint "${FRONTEND_URL}/main.dart.js" "200" "Flutter 主程式"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試環境配置
test_endpoint "${FRONTEND_URL}/assets/env.json" "200" "環境配置檔案"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試環境配置內容
test_content "${FRONTEND_URL}/assets/env.json" "API_BASE_URL" "環境配置內容"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# 測試 manifest.json
test_endpoint "${FRONTEND_URL}/manifest.json" "200" "Web 應用清單"
((total_tests++))
if [ $? -eq 0 ]; then ((passed_tests++)); fi

# =============================================================================
# 路由測試
# =============================================================================
echo -e "\n${YELLOW}🛣️ 路由測試${NC}"
echo "----------------------------------------"

# 測試根路徑重定向
echo -n "測試根路徑重定向: "
redirect_response=$(curl -s -o /dev/null -w "%{http_code}" -L "${BASE_URL}/")
if [ "$redirect_response" = "200" ]; then
    echo -e "${GREEN}✅ 成功${NC}"
    ((passed_tests++))
else
    echo -e "${RED}❌ 失敗 (HTTP $redirect_response)${NC}"
fi
((total_tests++))

# =============================================================================
# SSL 測試
# =============================================================================
echo -e "\n${YELLOW}🔒 SSL 測試${NC}"
echo "----------------------------------------"

# 測試 HTTPS 強制重定向
echo -n "測試 HTTPS 強制重定向: "
http_url="http://hero4help.demofhs.com"
https_redirect=$(curl -s -o /dev/null -w "%{http_code}" -L "$http_url")
if [ "$https_redirect" = "200" ]; then
    echo -e "${GREEN}✅ 成功${NC}"
    ((passed_tests++))
else
    echo -e "${RED}❌ 失敗 (HTTP $https_redirect)${NC}"
fi
((total_tests++))

# =============================================================================
# 測試結果總結
# =============================================================================
echo -e "\n${BLUE}📊 測試結果總結${NC}"
echo "=================================================="
echo -e "總測試數: ${BLUE}$total_tests${NC}"
echo -e "通過測試: ${GREEN}$passed_tests${NC}"
echo -e "失敗測試: ${RED}$((total_tests - passed_tests))${NC}"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "\n${GREEN}🎉 所有測試通過！部署成功！${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️ 部分測試失敗，請檢查部署配置${NC}"
    exit 1
fi
