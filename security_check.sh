#!/bin/bash
# security_check.sh - 檢查專案中的敏感資訊外洩風險

echo "🔍 檢查專案中的敏感資訊外洩風險..."
echo "=================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查結果計數器
RISK_COUNT=0
WARNING_COUNT=0

echo -e "${BLUE}1. 檢查硬編程的 Google Client ID...${NC}"
GOOGLE_CLIENT_IDS=$(grep -r "102744926949" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config" | wc -l)
if [ "$GOOGLE_CLIENT_IDS" -gt 0 ]; then
    echo -e "${RED}❌ 發現 $GOOGLE_CLIENT_IDS 處硬編程的 Google Client ID${NC}"
    grep -r "102744926949" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config"
    RISK_COUNT=$((RISK_COUNT + GOOGLE_CLIENT_IDS))
else
    echo -e "${GREEN}✅ 未發現硬編程的 Google Client ID${NC}"
fi

echo ""
echo -e "${BLUE}2. 檢查硬編程的 Facebook App ID...${NC}"
FACEBOOK_APP_IDS=$(grep -r "1037019294991326" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config" | wc -l)
if [ "$FACEBOOK_APP_IDS" -gt 0 ]; then
    echo -e "${RED}❌ 發現 $FACEBOOK_APP_IDS 處硬編程的 Facebook App ID${NC}"
    grep -r "1037019294991326" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config"
    RISK_COUNT=$((RISK_COUNT + FACEBOOK_APP_IDS))
else
    echo -e "${GREEN}✅ 未發現硬編程的 Facebook App ID${NC}"
fi

echo ""
echo -e "${BLUE}3. 檢查硬編程的 Apple Service ID...${NC}"
APPLE_SERVICE_IDS=$(grep -r "com.example.here4help.login" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config" | wc -l)
if [ "$APPLE_SERVICE_IDS" -gt 0 ]; then
    echo -e "${RED}❌ 發現 $APPLE_SERVICE_IDS 處硬編程的 Apple Service ID${NC}"
    grep -r "com.example.here4help.login" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config"
    RISK_COUNT=$((RISK_COUNT + APPLE_SERVICE_IDS))
else
    echo -e "${GREEN}✅ 未發現硬編程的 Apple Service ID${NC}"
fi

echo ""
echo -e "${BLUE}4. 檢查其他可能的敏感資訊...${NC}"

# 檢查 JWT 密鑰
JWT_SECRETS=$(grep -r "jwt.*secret" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config" | grep -v "JWT_SECRET" | wc -l)
if [ "$JWT_SECRETS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ 發現 $JWT_SECRETS 處可能的 JWT 密鑰引用${NC}"
    WARNING_COUNT=$((WARNING_COUNT + JWT_SECRETS))
else
    echo -e "${GREEN}✅ 未發現 JWT 密鑰外洩${NC}"
fi

# 檢查資料庫密碼
DB_PASSWORDS=$(grep -r "password.*root" lib/ backend/ admin/ 2>/dev/null | grep -v ".env" | grep -v "test_config" | wc -l)
if [ "$DB_PASSWORDS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ 發現 $DB_PASSWORDS 處可能的資料庫密碼${NC}"
    WARNING_COUNT=$((WARNING_COUNT + DB_PASSWORDS))
else
    echo -e "${GREEN}✅ 未發現資料庫密碼外洩${NC}"
fi

echo ""
echo -e "${BLUE}5. 檢查 .env 文件是否被正確排除...${NC}"

# 檢查 .gitignore
if grep -q "\.env" .gitignore; then
    echo -e "${GREEN}✅ .env 文件已加入 .gitignore${NC}"
else
    echo -e "${RED}❌ .env 文件未加入 .gitignore${NC}"
    RISK_COUNT=$((RISK_COUNT + 1))
fi

# 檢查是否有 .env 文件被追蹤
TRACKED_ENV=$(git ls-files | grep "\.env" | wc -l)
if [ "$TRACKED_ENV" -gt 0 ]; then
    echo -e "${RED}❌ 發現 $TRACKED_ENV 個 .env 文件被 Git 追蹤${NC}"
    git ls-files | grep "\.env"
    RISK_COUNT=$((RISK_COUNT + TRACKED_ENV))
else
    echo -e "${GREEN}✅ 沒有 .env 文件被 Git 追蹤${NC}"
fi

echo ""
echo "=================================="
echo -e "${BLUE}🔍 安全檢查結果${NC}"
echo "=================================="

if [ "$RISK_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ 未發現嚴重安全風險${NC}"
else
    echo -e "${RED}❌ 發現 $RISK_COUNT 處嚴重安全風險${NC}"
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ 發現 $WARNING_COUNT 處警告${NC}"
fi

echo ""
echo -e "${BLUE}📋 安全建議：${NC}"
echo "1. 所有敏感資訊必須使用環境變數"
echo "2. 確保 .env 文件不被 Git 追蹤"
echo "3. 定期檢查硬編程的敏感資訊"
echo "4. 使用此腳本定期進行安全檢查"
echo ""
echo -e "${BLUE}🚀 運行此腳本：${NC}"
echo "chmod +x security_check.sh"
echo "./security_check.sh"
