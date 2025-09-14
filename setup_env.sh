#!/bin/bash

# Here4Help 環境配置設置腳本
# 用於快速設置開發、測試和正式環境的 .env 文件

set -e  # 遇到錯誤立即退出

echo "🚀 Here4Help 環境配置設置工具"
echo "================================"
echo

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：列印彩色訊息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 函數：檢查文件是否存在
check_file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# 函數：備份現有配置文件
backup_file() {
    if check_file_exists "$1"; then
        cp "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "已備份現有配置文件: $1"
    fi
}

# 函數：設置 Flutter App 環境
setup_flutter_env() {
    print_info "設置 Flutter App 環境配置..."
    
    # 設置開發環境
    if ! check_file_exists ".env.development"; then
        print_info "建立 Flutter 開發環境配置..."
        cat > .env.development << 'EOF'
# Development Environment Configuration
APP_ENVIRONMENT=development
APP_DEBUG=true

# Local Development API Configuration
API_ORIGIN=http://127.0.0.1:8888
API_PREFIX=/here4help/backend/api  
API_BASE_URL=http://127.0.0.1:8888/here4help/backend
IMAGE_BASE_URL=http://127.0.0.1:8888/here4help

# Local Socket Configuration
SOCKET_URL=http://127.0.0.1:3001

# Development OAuth (請填入實際憑證)
GOOGLE_CLIENT_ID=
FACEBOOK_APP_ID=
APPLE_SERVICE_ID=com.example.here4help.login

# Development Redirect URIs
GOOGLE_REDIRECT_URI=http://127.0.0.1:8888/here4help/backend/api/auth/google-callback.php
FACEBOOK_REDIRECT_URI=http://127.0.0.1:8888/here4help/backend/api/auth/facebook-callback.php
APPLE_REDIRECT_URI=https://b4a869b2989d.ngrok-free.app/here4help/backend/api/auth/apple-callback.php
# APPLE_REDIRECT_URI=http://127.0.0.1:8888/here4help/backend/api/auth/apple-callback.php

# Feature Flags
FEATURE_THIRD_PARTY_AUTH=true
FEATURE_CHAT=true  
FEATURE_TASKS=true
FEATURE_PAYMENTS=false
EOF
        print_success "已建立 .env.development"
    else
        print_warning ".env.development 已存在，跳過建立"
    fi
}

# 函數：設置 Backend PHP 環境
setup_backend_env() {
    print_info "設置 Backend PHP 環境配置..."
    
    if ! check_file_exists "backend/.env"; then
        if check_file_exists "backend/config/env.example"; then
            print_info "從範本建立 Backend .env 文件..."
            cp backend/config/env.example backend/.env
            print_success "已建立 backend/.env"
            print_warning "請編輯 backend/.env 填入實際配置值"
        else
            print_error "找不到 Backend 環境範本文件"
        fi
    else
        print_warning "backend/.env 已存在，跳過建立"
    fi
}

# 函數：設置 Admin Laravel 環境
setup_admin_env() {
    print_info "設置 Admin Laravel 環境配置..."
    
    if ! check_file_exists "admin/.env"; then
        if check_file_exists "admin/env.example"; then
            print_info "從範本建立 Admin .env 文件..."
            cp admin/env.example admin/.env
            
            # 產生 Laravel APP_KEY
            if command -v php &> /dev/null; then
                print_info "產生 Laravel APP_KEY..."
                cd admin
                php artisan key:generate --no-interaction
                cd ..
                print_success "已產生 Laravel APP_KEY"
            else
                print_warning "未找到 PHP，請手動執行: cd admin && php artisan key:generate"
            fi
            
            print_success "已建立 admin/.env"
            print_warning "請編輯 admin/.env 填入實際配置值"
        else
            print_error "找不到 Admin 環境範本文件"
        fi
    else
        print_warning "admin/.env 已存在，跳過建立"
    fi
}

# 函數：檢查依賴
check_dependencies() {
    print_info "檢查系統依賴..."
    
    # 檢查 Flutter
    if command -v flutter &> /dev/null; then
        print_success "Flutter 已安裝"
    else
        print_error "Flutter 未安裝，請先安裝 Flutter SDK"
        exit 1
    fi
    
    # 檢查 PHP
    if command -v php &> /dev/null; then
        print_success "PHP 已安裝"
    else
        print_warning "PHP 未安裝，部分功能可能無法正常運作"
    fi
    
    echo
}

# 函數：顯示後續步驟
    show_next_steps() {
    echo
    print_info "設置完成！接下來的步驟："
    echo
    echo "1. 📝 編輯環境配置文件："
    echo "   - .env.development (Flutter App 開發環境)"
    echo "   - backend/.env (Backend API 配置)"
    echo "   - admin/.env (Admin 面板配置)"
    echo
    echo "2. 🔐 填入敏感資訊："
    echo "   - 資料庫連接資訊 (端口 8889)"
    echo "   - OAuth Client ID 和 Secret"
    echo "   - JWT Secret (建議至少32字元)"
    echo "   - Socket 服務器配置 (端口 3001)"
    echo
    echo "3. 🚀 啟動開發環境："
    echo "   - MAMP/XAMPP (Web: 8888, MySQL: 8889)"
    echo "   - Socket: cd backend/socket && node server.js (端口 3001)"
    echo "   - Admin: cd admin && php artisan serve --port=8000"
    echo "   - Flutter 開發選項："
    echo "     • 一般開發: flutter run --dart-define=ENVIRONMENT=development"
    echo "     • iOS 模擬器: flutter run -d iphone --dart-define=ENVIRONMENT=ios_simulator"
    echo "     • Android 模擬器: flutter run -d android --dart-define=ENVIRONMENT=android_emulator"
    echo "     • Web 開發: flutter run -d chrome --dart-define=ENVIRONMENT=development"
    echo
    echo "4. 🌐 網路配置注意事項："
    echo "   - Android 模擬器需要修改 env.android_emulator 中的 IP 地址"
    echo "   - 使用 ifconfig (macOS/Linux) 或 ipconfig (Windows) 查找本機 IP"
    echo
    echo "5. 📖 詳細說明請參考:"
    echo "   - ENV_CONFIGURATION_GUIDE.md (環境配置指南)"
    echo "   - MIGRATION_FROM_APP_ENV.md (從 JSON 遷移指南)"
    echo
    print_success "環境設置腳本執行完成！"
}

# 主執行流程
main() {
    # 檢查依賴
    check_dependencies
    
    # 檢查是否在專案根目錄
    if ! check_file_exists "pubspec.yaml"; then
        print_error "請在 Here4Help 專案根目錄執行此腳本"
        exit 1
    fi
    
    print_info "在專案根目錄: $(pwd)"
    echo
    
    # 詢問使用者要設置哪些環境
    echo "請選擇要設置的環境："
    echo "1) 全部設置 (推薦)"
    echo "2) 僅 Flutter App"
    echo "3) 僅 Backend PHP"  
    echo "4) 僅 Admin Laravel"
    echo "5) 取消"
    echo
    read -p "請輸入選擇 (1-5): " choice
    
    case $choice in
        1)
            setup_flutter_env
            setup_backend_env
            setup_admin_env
            ;;
        2)
            setup_flutter_env
            ;;
        3)
            setup_backend_env
            ;;
        4)
            setup_admin_env
            ;;
        5)
            print_info "取消設置"
            exit 0
            ;;
        *)
            print_error "無效的選擇"
            exit 1
            ;;
    esac
    
    show_next_steps
}

# 執行主函數
main "$@"
