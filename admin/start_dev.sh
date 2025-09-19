#!/bin/bash

# =============================================================================
# Here4Help Admin 開發環境啟動腳本
# 修正 PHP 8.4 相容性問題
# =============================================================================

echo "=== Here4Help Admin 開發環境啟動 ==="
echo "啟動時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 檢查 PHP 版本
echo "1. 檢查 PHP 版本..."
php_version=$(php -v | head -n 1)
echo "   $php_version"

# 檢查 Laravel 版本
echo ""
echo "2. 檢查 Laravel 版本..."
if [ -f "artisan" ]; then
    laravel_version=$(php artisan --version)
    echo "   $laravel_version"
else
    echo "   ❌ 找不到 artisan 檔案"
    exit 1
fi

# 檢查環境配置
echo ""
echo "3. 檢查環境配置..."
if [ -f ".env" ]; then
    echo "   ✅ .env 檔案存在"
else
    echo "   ⚠️ .env 檔案不存在，複製 .env.example"
    cp .env.example .env
fi

# 生成應用程式金鑰
echo ""
echo "4. 生成應用程式金鑰..."
php artisan key:generate --force

# 清除快取
echo ""
echo "5. 清除快取..."
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# 檢查資料庫連線
echo ""
echo "6. 檢查資料庫連線..."
php artisan migrate:status > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ 資料庫連線正常"
else
    echo "   ⚠️ 資料庫連線有問題，請檢查 .env 設定"
fi

# 啟動開發伺服器
echo ""
echo "7. 啟動開發伺服器..."
echo "   Laravel 伺服器: http://localhost:8000"
echo "   Frontend 開發伺服器: http://localhost:5173"
echo ""

# 使用修正的 concurrently 命令
npx concurrently \
  --kill-others \
  --prefix-colors "blue,green,red,yellow" \
  --names "laravel,queue,frontend" \
  "php artisan serve --host=0.0.0.0 --port=8000" \
  "php artisan queue:work --tries=1" \
  "cd frontend && npm run dev"
