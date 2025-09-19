#!/bin/bash

# Here4Help cPanel 部署腳本
# 用於第一次部署到 cPanel public_html 目錄

set -e  # 遇到錯誤時停止執行

echo "🚀 開始 Here4Help cPanel 部署..."

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查是否在 public_html 目錄
if [[ ! "$PWD" == *"public_html"* ]]; then
    echo -e "${RED}❌ 錯誤: 請在 public_html 目錄中執行此腳本${NC}"
    exit 1
fi

echo -e "${BLUE}📁 當前目錄: $PWD${NC}"

# =============================================================================
# 1. 檢查 PHP 版本
# =============================================================================
echo -e "${YELLOW}🔍 檢查 PHP 版本...${NC}"
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
echo -e "${GREEN}✅ PHP 版本: $PHP_VERSION${NC}"

if [[ $(echo "$PHP_VERSION < 7.4" | bc -l) -eq 1 ]]; then
    echo -e "${RED}❌ 錯誤: 需要 PHP 7.4 或更高版本${NC}"
    exit 1
fi

# =============================================================================
# 2. 檢查 Composer
# =============================================================================
echo -e "${YELLOW}🔍 檢查 Composer...${NC}"
if ! command -v composer &> /dev/null; then
    echo -e "${YELLOW}⚠️  Composer 未安裝，正在安裝...${NC}"
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

COMPOSER_VERSION=$(composer --version | cut -d " " -f 3)
echo -e "${GREEN}✅ Composer 版本: $COMPOSER_VERSION${NC}"

# =============================================================================
# 3. 檢查 Node.js 和 npm
# =============================================================================
echo -e "${YELLOW}🔍 檢查 Node.js 和 npm...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠️  Node.js 未安裝，請聯繫主機提供商安裝 Node.js${NC}"
else
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✅ Node.js 版本: $NODE_VERSION${NC}"
    echo -e "${GREEN}✅ npm 版本: $NPM_VERSION${NC}"
fi

# =============================================================================
# 4. 設置目錄權限
# =============================================================================
echo -e "${YELLOW}🔧 設置目錄權限...${NC}"

# 設置基本權限
chmod 755 .
chmod 644 .htaccess

# 設置 admin 目錄權限
if [ -d "admin" ]; then
    chmod -R 755 admin/
    chmod -R 777 admin/storage/
    chmod -R 777 admin/bootstrap/cache/
    echo -e "${GREEN}✅ Admin 目錄權限設置完成${NC}"
fi

# 設置 backend 目錄權限
if [ -d "backend" ]; then
    chmod -R 755 backend/
    chmod -R 777 backend/storage/
    chmod -R 777 backend/uploads/
    chmod -R 777 backend/cache/
    echo -e "${GREEN}✅ Backend 目錄權限設置完成${NC}"
fi

# 設置 web 目錄權限
if [ -d "web" ]; then
    chmod -R 755 web/
    echo -e "${GREEN}✅ Web 目錄權限設置完成${NC}"
fi

# =============================================================================
# 5. 安裝 Admin (Laravel) 依賴
# =============================================================================
if [ -d "admin" ] && [ -f "admin/composer.json" ]; then
    echo -e "${YELLOW}📦 安裝 Admin (Laravel) 依賴...${NC}"
    cd admin
    
    # 安裝 Composer 依賴
    composer install --no-dev --optimize-autoloader
    
    # 生成應用程式金鑰
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo -e "${GREEN}✅ 複製 .env.example 到 .env${NC}"
        fi
    fi
    
    # 生成 Laravel 金鑰
    php artisan key:generate --force
    
    # 清除快取
    php artisan config:clear
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear
    
    # 優化 Laravel
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    
    cd ..
    echo -e "${GREEN}✅ Admin 依賴安裝完成${NC}"
fi

# =============================================================================
# 6. 安裝 Backend Socket 依賴
# =============================================================================
if [ -d "backend/socket" ] && [ -f "backend/socket/package.json" ]; then
    echo -e "${YELLOW}📦 安裝 Backend Socket 依賴...${NC}"
    cd backend/socket
    
    # 安裝 npm 依賴
    npm install --production
    
    cd ../..
    echo -e "${GREEN}✅ Backend Socket 依賴安裝完成${NC}"
fi

# =============================================================================
# 7. 創建必要的目錄
# =============================================================================
echo -e "${YELLOW}📁 創建必要的目錄...${NC}"

# 創建上傳目錄
mkdir -p backend/uploads/avatars
mkdir -p backend/uploads/chat
mkdir -p backend/uploads/student_id_images
mkdir -p backend/uploads/support_chat
mkdir -p backend/uploads/test

# 創建日誌目錄
mkdir -p backend/storage/logs
mkdir -p backend/storage/jwt_blacklist
mkdir -p backend/storage/rate_limits
mkdir -p backend/storage/alerts

# 創建快取目錄
mkdir -p backend/cache

# 設置上傳目錄權限
chmod -R 777 backend/uploads/
chmod -R 777 backend/storage/
chmod -R 777 backend/cache/

echo -e "${GREEN}✅ 必要目錄創建完成${NC}"

# =============================================================================
# 8. 配置環境變數
# =============================================================================
echo -e "${YELLOW}⚙️  配置環境變數...${NC}"

# 檢查 backend 環境配置
if [ -f "backend/.env.example" ] && [ ! -f "backend/.env" ]; then
    cp backend/.env.example backend/.env
    echo -e "${GREEN}✅ 複製 backend/.env.example 到 backend/.env${NC}"
    echo -e "${YELLOW}⚠️  請手動編輯 backend/.env 檔案，設置正確的資料庫連接資訊${NC}"
fi

# 檢查 admin 環境配置
if [ -f "admin/.env.example" ] && [ ! -f "admin/.env" ]; then
    cp admin/.env.example admin/.env
    echo -e "${GREEN}✅ 複製 admin/.env.example 到 admin/.env${NC}"
    echo -e "${YELLOW}⚠️  請手動編輯 admin/.env 檔案，設置正確的資料庫連接資訊${NC}"
fi

# =============================================================================
# 9. 測試部署
# =============================================================================
echo -e "${YELLOW}🧪 測試部署...${NC}"

# 測試 PHP 檔案
if [ -f "backend/api/ping.php" ]; then
    echo -e "${BLUE}🔍 測試 Backend API...${NC}"
    # 這裡可以添加 API 測試
fi

# 測試 Admin 頁面
if [ -f "admin/index.html" ]; then
    echo -e "${BLUE}🔍 測試 Admin 頁面...${NC}"
    # 這裡可以添加 Admin 測試
fi

# 測試 Flutter Web
if [ -f "web/index.html" ]; then
    echo -e "${BLUE}🔍 測試 Flutter Web...${NC}"
    # 這裡可以添加 Web 測試
fi

# =============================================================================
# 10. 完成部署
# =============================================================================
echo -e "${GREEN}🎉 部署完成！${NC}"
echo -e "${BLUE}📋 後續步驟：${NC}"
echo -e "1. 編輯 backend/.env 檔案，設置資料庫連接資訊"
echo -e "2. 編輯 admin/.env 檔案，設置資料庫連接資訊"
echo -e "3. 執行資料庫遷移 (如果需要)"
echo -e "4. 測試所有功能"
echo -e "5. 設置 SSL 憑證 (如果使用 HTTPS)"

echo -e "${BLUE}🔗 測試連結：${NC}"
echo -e "- 主站: https://yourdomain.com/"
echo -e "- Admin: https://yourdomain.com/admin/"
echo -e "- API: https://yourdomain.com/backend/api/ping.php"

echo -e "${GREEN}✅ 部署腳本執行完成！${NC}"
