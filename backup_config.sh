#!/bin/bash
# Here4Help 配置檔案備份腳本
# 用於備份所有重要的配置檔案

# 設定備份目錄
BACKUP_DIR="config_backup_$(date +%Y%m%d_%H%M%S)"

echo "=== Here4Help 配置檔案備份 ==="
echo "備份時間: $(date)"
echo "備份目錄: $BACKUP_DIR"
echo ""

# 建立備份目錄
mkdir -p "$BACKUP_DIR"

# 備份根目錄 .htaccess
echo "1. 備份根目錄 .htaccess..."
if [ -f ".htaccess" ]; then
    cp .htaccess "$BACKUP_DIR/.htaccess.backup"
    echo "✅ .htaccess 備份完成 ($(wc -l < .htaccess) 行)"
else
    echo "⚠️ .htaccess 不存在，跳過"
fi

# 備份 production.env
echo "2. 備份 production.env..."
if [ -f "env/production.env" ]; then
    cp env/production.env "$BACKUP_DIR/production.env.backup"
    echo "✅ production.env 備份完成 ($(wc -l < env/production.env) 行)"
else
    echo "⚠️ env/production.env 不存在，跳過"
fi

# 備份 backend/.htaccess
echo "3. 備份 backend/.htaccess..."
if [ -f "backend/.htaccess" ]; then
    cp backend/.htaccess "$BACKUP_DIR/backend.htaccess.backup"
    echo "✅ backend/.htaccess 備份完成 ($(wc -l < backend/.htaccess) 行)"
else
    echo "⚠️ backend/.htaccess 不存在，跳過"
fi

# 備份 admin/public/.htaccess
echo "4. 備份 admin/public/.htaccess..."
if [ -f "admin/public/.htaccess" ]; then
    cp admin/public/.htaccess "$BACKUP_DIR/admin.public.htaccess.backup"
    echo "✅ admin/public/.htaccess 備份完成 ($(wc -l < admin/public/.htaccess) 行)"
else
    echo "⚠️ admin/public/.htaccess 不存在，跳過"
fi

# 備份其他 .htaccess 檔案
echo "5. 備份其他 .htaccess 檔案..."
for file in .htaccess_cpanel_main .htaccess_fixed .htaccess_cpanel; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/${file}.backup"
        echo "✅ $file 備份完成"
    fi
done

# 備份環境配置檔案
echo "6. 備份環境配置檔案..."
for env_file in env/development.env env/staging.env env/production.env; do
    if [ -f "$env_file" ]; then
        filename=$(basename "$env_file")
        cp "$env_file" "$BACKUP_DIR/${filename}.backup"
        echo "✅ $env_file 備份完成"
    fi
done

# 建立備份清單
echo "7. 建立備份清單..."
ls -la "$BACKUP_DIR" > "$BACKUP_DIR/backup_list.txt"

# 建立備份說明檔案
echo "8. 建立備份說明檔案..."
cat > "$BACKUP_DIR/README.md" << EOF
# Here4Help 配置檔案備份

## 備份時間
$(date)

## 備份內容
- .htaccess.backup - 根目錄主要 .htaccess 配置
- production.env.backup - 生產環境配置
- backend.htaccess.backup - Backend API .htaccess 配置
- admin.public.htaccess.backup - Admin 後台 .htaccess 配置
- development.env.backup - 開發環境配置
- staging.env.backup - 測試環境配置

## 還原方法
\`\`\`bash
# 還原根目錄 .htaccess
cp .htaccess.backup ../../.htaccess

# 還原 production.env
cp production.env.backup ../../env/production.env

# 還原 backend .htaccess
cp backend.htaccess.backup ../../backend/.htaccess

# 還原 admin .htaccess
cp admin.public.htaccess.backup ../../admin/public/.htaccess
\`\`\`

## 注意事項
- 此備份在配置衝突修正前建立
- 如需還原，請確認備份檔案的完整性
- 建議在還原前再次備份當前配置
EOF

echo "✅ 備份說明檔案建立完成"

# 顯示備份結果
echo ""
echo "=== 備份完成 ==="
echo "備份目錄: $BACKUP_DIR"
echo "備份內容:"
ls -la "$BACKUP_DIR"

echo ""
echo "=== 備份驗證 ==="
echo "檢查備份檔案完整性..."
if [ -f "$BACKUP_DIR/.htaccess.backup" ]; then
    echo "1. 根目錄 .htaccess: $(wc -l < "$BACKUP_DIR/.htaccess.backup") 行"
fi
if [ -f "$BACKUP_DIR/production.env.backup" ]; then
    echo "2. production.env: $(wc -l < "$BACKUP_DIR/production.env.backup") 行"
fi
if [ -f "$BACKUP_DIR/backend.htaccess.backup" ]; then
    echo "3. backend .htaccess: $(wc -l < "$BACKUP_DIR/backend.htaccess.backup") 行"
fi
if [ -f "$BACKUP_DIR/admin.public.htaccess.backup" ]; then
    echo "4. admin .htaccess: $(wc -l < "$BACKUP_DIR/admin.public.htaccess.backup") 行"
fi

echo "✅ 備份完成！"
echo "備份目錄: $BACKUP_DIR"
echo "如需還原，請參考 $BACKUP_DIR/README.md"
