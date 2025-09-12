#!/bin/bash
# organize_docs.sh - 智能文件分類和歸檔腳本

echo "📁 智能文件分類和歸檔系統"
echo "=========================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 創建分類目錄
echo -e "${BLUE}1. 創建分類目錄結構...${NC}"
mkdir -p archived/{completed-features,bug-fixes,deprecated-guides,old-reports,superseded-docs,current-active}

# 移動計數器
MOVED_COUNT=0
KEPT_COUNT=0

echo -e "${BLUE}2. 開始智能分類...${NC}"

# 分類規則
echo -e "${CYAN}📋 分類規則：${NC}"
echo "  ✅ 保留：當前活躍的重要文件"
echo "  📦 歸檔：已完成的功能、修復、舊報告"
echo "  🗑️ 棄用：過時或重複的指南"

# 1. 已完成的功能實現報告
echo -e "${YELLOW}📦 移動已完成的功能實現報告...${NC}"
COMPLETED_FEATURES=(
    "action_bar_implementation_summary.md"
    "avatar_cache_implementation_summary.md"
    "batch_loading_optimization_summary.md"
    "block_functionality_backend_integration.md"
    "block_user_socket_notification_implementation.md"
    "chat_image_socket_fix_summary.md"
    "completed_action_socket_integration.md"
    "image_tray_removal_summary.md"
    "login_loading_overlay_summary.md"
    "payment_dialog_data_source_fix.md"
    "payment_dialog_user_id_fix.md"
    "snackbar_notification_implementation.md"
    "socket_notification_implementation_summary.md"
    "socket_realtime_update_implementation.md"
    "support_action_bar_fixes_summary.md"
    "unread_status_optimization_guide.md"
    "wallet_system_completion_report.md"
    "wallet_system_progress_report.md"
    "任務創建頁面問題標籤佈局優化報告.md"
    "任務創建頁面錢包功能整合報告.md"
    "任務卡片Pin功能和篩選機制優化報告.md"
    "任務卡片刪除後本地狀態更新報告.md"
    "點數歷史頁面UI溢出修復報告.md"
)

for file in "${COMPLETED_FEATURES[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archived/completed-features/"
        echo "  ✅ 移動: $file → completed-features/"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    fi
done

# 2. Bug 修復報告
echo -e "${YELLOW}🐛 移動 Bug 修復報告...${NC}"
BUG_FIXES=(
    "action_bar_pay_error_fix.md"
    "android_debug_fix.md"
    "api_html_error_fix.md"
    "block_functionality_correction.md"
    "chat_image_socket_fix_final.md"
    "countdown_timer_consistency_fix.md"
    "LOGIN_API_FIX.md"
    "replaceUnreadByRoom_multiple_calls_fix.md"
    "socket_notification_fix.md"
    "task_history_404_fix.md"
    "task_history_page_fixes.md"
    "transfer_api_jwt_fix.md"
    "unblock_issue_diagnosis_and_fix.md"
    "wallet_api_fix_report.md"
    "移除default.png引用修復報告.md"
)

for file in "${BUG_FIXES[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archived/bug-fixes/"
        echo "  ✅ 移動: $file → bug-fixes/"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    fi
done

# 3. 過時的指南和配置
echo -e "${YELLOW}📚 移動過時的指南...${NC}"
DEPRECATED_GUIDES=(
    "ENVIRONMENT_CONFIG_GUIDE.md"
    "ENVIRONMENT_CONFIGURATION_GUIDE.md"
    "GOOGLE_AUTH_SETUP.md"
    "GOOGLE_OAUTH_FIX_GUIDE.md"
    "GOOGLE_OAUTH_SETUP_CHECKLIST.md"
    "JWT_MIGRATION_GUIDE.md"
    "SOCKET_NOTIFICATION_SETUP.md"
    "THIRD_PARTY_AUTH_CONFIG.md"
    "THIRD_PARTY_LOGIN_FLOW.md"
    "WEB_OAUTH_IMPLEMENTATION_GUIDE.md"
    "平台網路分流配置指南.md"
    "支付功能實現指南.md"
    "登入註冊模組檔案架構統整報告.md"
)

for file in "${DEPRECATED_GUIDES[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archived/deprecated-guides/"
        echo "  ✅ 移動: $file → deprecated-guides/"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    fi
done

# 4. 舊的分析報告
echo -e "${YELLOW}📊 移動舊的分析報告...${NC}"
OLD_REPORTS=(
    "action_bar_api_socket_analysis.md"
    "action_bar_socket_notification_analysis.md"
    "action_bar_system_messages_audit.md"
    "ADMIN_FRONTEND_API_ROUTING_AUDIT.md"
    "API_ARCHITECTURE_RECOMMENDATION.md"
    "ARCHITECTURE_OPTIMIZATION_REPORT.md"
    "chat_detail_status_bar_architecture_analysis.md"
    "chat_detail_status_bar_architecture_diagram.md"
    "chatlist_provider_optimization.md"
    "support_chat_image_analysis_report.md"
    "support_chat_image_format_unification.md"
    "VUE_DATA_FLOW_ANALYSIS.md"
    "評估報告"
)

for file in "${OLD_REPORTS[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        mv "$file" "archived/old-reports/"
        echo "  ✅ 移動: $file → old-reports/"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    fi
done

# 5. 被取代的文檔
echo -e "${YELLOW}🔄 移動被取代的文檔...${NC}"
SUPERSEDED_DOCS=(
    "ADMIN_LOGIN_SOLUTION.md"
    "API_MIGRATION_GUIDE.md"
    "API_ROUTING_FIX_PLAN.md"
    "CURSOR_TODO.md"
    "CURSOR_TODO_OPTIMIZED.md"
    "support_chat_refactor_plan.json"
    "support_chat_refactor_progress.md"
    "wallet_system_plan.json"
    "版本回溯要點.json"
    "任務爭議模組測試指南.md"
)

for file in "${SUPERSEDED_DOCS[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archived/superseded-docs/"
        echo "  ✅ 移動: $file → superseded-docs/"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    fi
done

# 6. 保留當前活躍的重要文件
echo -e "${GREEN}✅ 保留當前活躍的重要文件...${NC}"
CURRENT_ACTIVE=(
    "API_ENDPOINT_STANDARDS.md"
    "DATABASE_SCHEMA.md"
    "THEME_ARCHITECTURE_CURRENT.md"
    "THEME_CATEGORY_SYSTEM.md"
    "THEME_SYSTEM_ARCHITECTURE.md"
    "THEME_USAGE_GUIDE.md"
    "TODO_DASHBOARD.md"
    "TODO_INDEX.md"
    "TODO_INTEGRATED.md"
    "PLAN.md"
    "CLEANUP_SUMMARY_2025_08_17.md"
)

for file in "${CURRENT_ACTIVE[@]}"; do
    if [ -f "$file" ]; then
        echo "  📌 保留: $file"
        KEPT_COUNT=$((KEPT_COUNT + 1))
    fi
done

echo ""
echo "=========================="
echo -e "${GREEN}📊 分類完成統計${NC}"
echo "=========================="
echo -e "${BLUE}移動文件數量: ${MOVED_COUNT}${NC}"
echo -e "${GREEN}保留文件數量: ${KEPT_COUNT}${NC}"
echo ""
echo -e "${CYAN}📁 分類目錄：${NC}"
echo "  📦 completed-features/ - 已完成的功能實現"
echo "  🐛 bug-fixes/ - Bug 修復報告"
echo "  📚 deprecated-guides/ - 過時的指南"
echo "  📊 old-reports/ - 舊的分析報告"
echo "  🔄 superseded-docs/ - 被取代的文檔"
echo ""
echo -e "${YELLOW}⚠️ 注意事項：${NC}"
echo "  - 請檢查移動的文件是否正確"
echo "  - 如有需要可以手動調整分類"
echo "  - 建議定期清理歸檔文件"
echo ""
echo -e "${GREEN}🎉 文件整理完成！${NC}"
