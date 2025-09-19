#!/bin/bash

# =============================================================================
# Here4Help Admin 簡化開發環境啟動腳本
# 適用於 Laravel 9.x + PHP 8.4
# =============================================================================

echo "=== Here4Help Admin 簡化開發環境啟動 ==="
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
    laravel_version=$(php artisan --version 2>/dev/null | head -n 1)
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
php artisan key:generate --force 2>/dev/null

# 清除快取
echo ""
echo "5. 清除快取..."
php artisan config:clear 2>/dev/null
php artisan cache:clear 2>/dev/null
php artisan route:clear 2>/dev/null
php artisan view:clear 2>/dev/null

# 啟動開發伺服器
echo ""
echo "6. 啟動開發伺服器..."
echo "   Laravel 伺服器: http://localhost:8000"
echo "   Frontend 開發伺服器: http://localhost:5173"
echo ""

# 使用簡化的 concurrently 命令
npx concurrently \
  --kill-others \
  --prefix-colors "blue,green,red" \
  --names "laravel,frontend" \
  "php artisan serve --host=0.0.0.0 --port=8000" \
  "cd frontend && npm run dev"
