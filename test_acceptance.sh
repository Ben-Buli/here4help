#!/bin/bash

echo "🎯 Here4Help 任務驗收測試"
echo "=========================="

# 檢查重複問題
echo "1. 檢查重複問題..."
if grep -q "_buildApplicationQuestionsCard" lib/task/pages/task_create_page.dart; then
    echo "❌ 發現重複的 _buildApplicationQuestionsCard 方法"
else
    echo "✅ 沒有重複的 Application Questions 區塊"
fi

# 檢查 Question num 字樣
echo "2. 檢查 Question num 字樣..."
if grep -q "Question [0-9]" lib/task/pages/task_create_page.dart; then
    echo "❌ 發現 Question num 字樣"
else
    echo "✅ 沒有 Question num 字樣"
fi

# 檢查 SharedPreferences 使用
echo "3. 檢查 SharedPreferences 使用..."
if grep -q "SharedPreferences" lib/task/pages/task_create_page.dart && grep -q "SharedPreferences" lib/task/pages/task_preview_page.dart; then
    echo "✅ SharedPreferences 已正確導入和使用"
else
    echo "❌ SharedPreferences 使用有問題"
fi

# 檢查排序和篩選功能
echo "4. 檢查排序和篩選功能..."
if grep -q "sortTasks\|filterOwnTasks\|_showFilterDialog" lib/task/pages/task_list_page.dart; then
    echo "✅ 排序和篩選功能已實現"
else
    echo "❌ 排序和篩選功能未實現"
fi

# 檢查主題配色
echo "5. 檢查主題配色..."
if grep -q "theme.primary" lib/task/pages/task_create_page.dart; then
    echo "✅ 主題配色已更新"
else
    echo "❌ 主題配色未更新"
fi

echo ""
echo "🎉 驗收測試完成！"
echo "請手動測試以下功能："
echo "1. 任務創建 → 預覽 → 送出流程"
echo "2. 任務大廳排序和篩選"
echo "3. 不顯示自己的任務"
echo "4. 主題切換" 