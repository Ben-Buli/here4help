#!/bin/bash

# Here4Help v1.2.4 推送準備腳本
# 確保所有檔案變更都被正確追蹤

echo "=== Here4Help v1.2.4 推送準備 ==="
echo

# 1. 檢查當前 Git 狀態
echo "📋 當前 Git 狀態："
git status --short
echo

# 2. 處理所有刪除的檔案
echo "🗑️ 處理刪除的檔案..."
git add -u
echo "✅ 刪除檔案已標記"
echo

# 3. 添加所有新檔案和目錄
echo "📁 添加新檔案結構..."
git add docs/
git add tests/
git add .gitignore
git add pubspec.yaml
git add push_v1.2.3.sh
git add push_v1.2.4.sh
git add prepare_push_v1.2.4.sh
echo "✅ 新檔案已添加"
echo

# 4. 確保所有變更都被追蹤
echo "✅ 確保所有變更被追蹤..."
git add -A
echo "✅ 所有變更已追蹤"
echo

# 5. 檢查最終狀態
echo "📊 最終 Git 狀態："
git status --short
echo

# 6. 顯示即將提交的變更
echo "📋 即將提交的變更摘要："
echo "刪除的檔案："
git diff --cached --name-only --diff-filter=D | wc -l | xargs echo "  -"
echo "新增的檔案："
git diff --cached --name-only --diff-filter=A | wc -l | xargs echo "  +"
echo "修改的檔案："
git diff --cached --name-only --diff-filter=M | wc -l | xargs echo "  ~"
echo

# 7. 提供推送指令
echo "🚀 準備完成！執行以下指令推送："
echo "   ./push_v1.2.4.sh"
echo
echo "或者手動執行："
echo "   git commit -m 'v1.2.4: 專案結構清理優化完成'"
echo "   git tag -a 'v1.2.4' -m 'v1.2.4: 專案結構清理優化'"
echo "   git push origin main --tags"