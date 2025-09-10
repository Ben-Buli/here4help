#!/bin/bash

# 管理員後台版本推送腳本
# 只推送管理員後台相關文件，排除測試文件、第三方登入、執行紀錄等

echo "🚀 開始推送管理員後台相關文件..."
echo ""

# 檢查當前 git 狀態
echo "📋 當前 git 狀態:"
git status --porcelain
echo ""

# 確認是否繼續
read -p "是否繼續推送管理員後台文件？(y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "❌ 取消推送"
    exit 0
fi

echo ""
echo "📁 添加管理員後台相關文件到暫存區..."

# 1. Laravel 後端控制器
echo "  ✅ Laravel 控制器..."
git add admin/app/Http/Controllers/Admin/DisputeController.php
git add admin/app/Http/Controllers/Admin/SupportController.php  
git add admin/app/Http/Controllers/Admin/UserController.php

# 2. Vue.js 前端文件
echo "  ✅ Vue.js 前端文件..."
git add admin/frontend/src/services/api.ts
git add admin/frontend/src/config/api.ts
git add admin/frontend/src/views/UsersView.vue
git add admin/frontend/src/views/TasksView.vue
git add admin/frontend/src/views/TaskDisputesView.vue
git add admin/frontend/src/views/SupportChatListView.vue
git add admin/frontend/src/views/IssuesView.vue
git add admin/frontend/src/views/UserTransactionsView.vue
git add admin/frontend/src/components/AppLayout.vue
git add admin/frontend/src/components/wallet/DepositApprovalPage.vue
git add admin/frontend/src/components/wallet/OfficialBankAccountPage.vue
git add admin/frontend/vite.config.ts
git add admin/frontend/ENV_README.md

# 3. 新增的 Vue 組件
echo "  ✅ 新增 Vue 組件..."
git add admin/frontend/src/components/DisputeChatRoomModal.vue
git add admin/frontend/src/components/DisputeReviewDialog.vue
git add admin/frontend/src/components/Icon.vue
git add admin/frontend/src/components/UserReviewModal.vue
git add admin/frontend/src/services/chat-permission-service.ts

# 4. 後端 API 文件
echo "  ✅ 後端 API 文件..."
git add backend/api/admin/login.php
git add backend/api/admin/logout.php
git add backend/api/admin/me.php
git add backend/api/admin/tasks.php
git add backend/api/admin/support-chat-rooms.php
git add backend/api/admin/dispute-chat-messages.php
git add backend/api/admin/referral-events.php
git add backend/api/admin/support/
git add backend/api/admin/users/referral-info.php
git add backend/api/admin/users/review.php
git add backend/api/admin/users/verification.php
git add backend/api/admin/users/point-transactions.php

# 5. 工具和配置文件
echo "  ✅ 工具和配置文件..."
git add backend/utils/ReferralCodeGenerator.php
git add backend/create_admin.php
git add router.php
git add backend/database/migrations/2025_09_10_000001_create_referral_events_table.sql

# 6. 文檔文件
echo "  ✅ 文檔文件..."
git add docs/ADMIN_API_ROUTING_SOLUTION.md
git add docs/ADMIN_FRONTEND_API_ISSUES_FIX.md
git add docs/ADMIN_FRONTEND_API_ROUTING_AUDIT.md
git add docs/ADMIN_LOGIN_CORRECT_SOLUTION.md
git add docs/ADMIN_LOGIN_SOLUTION.md
git add docs/API_ARCHITECTURE_RECOMMENDATION.md
git add docs/API_ENDPOINT_STANDARDS.md
git add docs/API_MIGRATION_GUIDE.md
git add docs/API_ROUTING_FIX_PLAN.md
git add docs/ARCHITECTURE_OPTIMIZATION_REPORT.md
git add docs/ENVIRONMENT_CONFIG_GUIDE.md
git add docs/LOGIN_API_FIX.md
git add docs/VUE_DATA_FLOW_ANALYSIS.md
git add ADMIN_PUSH_CHECKLIST.md

echo ""
echo "🔍 檢查暫存區文件..."
staged_files=$(git diff --cached --name-only)
echo "已暫存的文件:"
echo "$staged_files"
echo ""

# 檢查是否有敏感文件
echo "🛡️  檢查敏感文件..."
sensitive_check=$(echo "$staged_files" | grep -E "(test_|\.log|\.env|oauth|google|\.backup|\.bak)" || true)
if [[ -n "$sensitive_check" ]]; then
    echo "⚠️  警告：發現可能的敏感文件:"
    echo "$sensitive_check"
    echo ""
    read -p "是否繼續？(y/N): " continue_confirm
    if [[ $continue_confirm != [yY] ]]; then
        echo "❌ 取消推送"
        git reset
        exit 0
    fi
fi

echo "✅ 敏感文件檢查通過"
echo ""

# 提交
echo "💾 提交變更..."
commit_message="feat(admin): 完成管理員後台系統整合

- 統一 Vue 前端與 Laravel 後端 API 路由
- 修復用戶管理、任務管理、爭議處理功能  
- 優化客服聊天室與支援系統
- 建立完整的管理員權限控制
- 對齊前後端數據字段命名規範

影響範圍：
- admin/frontend/: Vue.js 管理員前端
- admin/app/Http/Controllers/Admin/: Laravel 控制器  
- backend/api/admin/: PHP 管理員 API"

git commit -m "$commit_message"

echo ""
echo "🎉 管理員後台文件推送完成！"
echo ""
echo "📋 推送摘要:"
echo "- 已提交 $(echo "$staged_files" | wc -l) 個文件"
echo "- 排除了測試文件、第三方登入配置、執行紀錄等敏感內容"
echo "- 僅包含管理員後台核心功能相關文件"
echo ""
echo "⚠️  注意事項:"
echo "1. 請確認生產環境的 .env 配置正確"
echo "2. 驗證管理員登入功能正常"
echo "3. 測試主要管理功能運作正常"
echo ""
echo "🔗 如需推送到遠程倉庫，請執行:"
echo "   git push "
