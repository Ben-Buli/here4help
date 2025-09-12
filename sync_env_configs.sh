#!/bin/bash
# sync_env_configs.sh - 同步所有環境配置文件

echo "🔄 同步環境配置文件..."

# 清理函數：移除行尾空格和等號前後的空格
clean_env_file() {
    local file=$1
    if [ -f "$file" ]; then
        echo "清理 $file..."
        # 移除行尾空格
        sed -i '' 's/[[:space:]]*$//' "$file"
        # 移除等號前後的空格
        sed -i '' 's/[[:space:]]*=[[:space:]]*/=/' "$file"
    fi
}

# 同步函數：從根目錄 .env 同步到 Web assets/env/
sync_to_web() {
    local env_name=$1
    local source_file=".env.$env_name"
    local target_file="assets/env/.env.$env_name"
    
    if [ -f "$source_file" ]; then
        echo "同步 $source_file 到 $target_file..."
        cp "$source_file" "$target_file"
        # 添加 Web 平台註解
        sed -i '' "1s/^/# Web $env_name Environment Configuration\n/" "$target_file"
    fi
}

# 清理所有環境配置文件
echo "🧹 清理配置文件格式..."
clean_env_file ".env.development"
clean_env_file ".env.staging"
clean_env_file ".env.production"
clean_env_file ".env.testflight"
clean_env_file ".env.android_emulator"
clean_env_file ".env.ios_simulator"

# 清理 Web 環境配置文件
clean_env_file "assets/env/.env"
clean_env_file "assets/env/.env.development"
clean_env_file "assets/env/.env.staging"
clean_env_file "assets/env/.env.production"

# 同步到 Web 環境
echo "🌐 同步到 Web 環境配置..."
sync_to_web "development"
sync_to_web "staging"
sync_to_web "production"

# 驗證配置
echo "✅ 驗證配置..."
echo "檢查 API_PREFIX 配置："
grep "API_PREFIX" .env.* assets/env/.env.* | grep -v "  " || echo "✅ 沒有發現多餘空格"

echo "檢查 OAuth 配置："
grep "GOOGLE_CLIENT_ID" .env.* assets/env/.env.* | grep -v "your_" || echo "✅ 沒有發現佔位符"

echo "🎉 環境配置同步完成！"
echo ""
echo "📋 可用的環境配置："
echo "  - Development: flutter run --dart-define=ENVIRONMENT=development"
echo "  - Staging: flutter run --dart-define=ENVIRONMENT=staging"
echo "  - Production: flutter run --dart-define=ENVIRONMENT=production"
echo "  - TestFlight: flutter run --dart-define=ENVIRONMENT=testflight"
echo "  - Android Emulator: flutter run --dart-define=ENVIRONMENT=android_emulator"
echo "  - iOS Simulator: flutter run --dart-define=ENVIRONMENT=ios_simulator"
