<?php
/**
 * 測試用環境配置檔案
 * 用於測試 JWT 和資料庫連線
 */

// 設定測試環境變數
putenv('JWT_SECRET=here4help_jwt_secret_key_2025_production_secure_random_string_64_chars');
putenv('JWT_EXPIRY=604800');

// 資料庫配置
putenv('DB_HOST=localhost');
putenv('DB_PORT=3306');
putenv('DB_NAME=hero4helpdemofhs_hero4help');
putenv('DB_USERNAME=root');
putenv('DB_PASSWORD=root');
putenv('DB_CHARSET=utf8mb4');

// 應用配置
putenv('APP_ENV=development');
putenv('APP_DEBUG=true');
putenv('APP_URL=http://localhost:8888/here4help');

echo "✅ 測試環境變數已載入\n";
echo "🔑 JWT_SECRET: " . getenv('JWT_SECRET') . "\n";
echo "🌐 APP_URL: " . getenv('APP_URL') . "\n";
echo "🗄️ DB_HOST: " . getenv('DB_HOST') . "\n";
?>

