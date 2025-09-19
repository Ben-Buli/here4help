<?php
/**
 * 本機開發環境測試檔案
 * 測試 MAMP 環境下的資料庫連線
 */

echo "=== Here4Help 本機開發環境測試 ===\n";
echo "測試時間: " . date('Y-m-d H:i:s') . "\n\n";

// 1. 檢查 MAMP 環境
echo "1. 檢查 MAMP 環境...\n";
if (file_exists('/Applications/MAMP/tmp/mysql/mysql.sock')) {
    echo "✅ MAMP MySQL Socket 存在\n";
} else {
    echo "❌ MAMP MySQL Socket 不存在\n";
    exit(1);
}

// 2. 測試開發環境配置載入
echo "\n2. 測試開發環境配置載入...\n";
try {
    // 強制載入開發環境配置
    require_once 'backend/config/env_loader.php';
    
    // 手動設定開發環境變數
    putenv('APP_ENVIRONMENT=development');
    putenv('DB_HOST=localhost');
    putenv('DB_PORT=8889');
    putenv('DB_NAME=hero4helpdemofhs_hero4help');
    putenv('DB_USERNAME=root');
    putenv('DB_PASSWORD=root');
    
    echo "✅ 開發環境配置載入成功\n";
    echo "   - APP_ENVIRONMENT: " . getenv('APP_ENVIRONMENT') . "\n";
    echo "   - DB_HOST: " . getenv('DB_HOST') . "\n";
    echo "   - DB_PORT: " . getenv('DB_PORT') . "\n";
    echo "   - DB_NAME: " . getenv('DB_NAME') . "\n";
    echo "   - DB_USERNAME: " . getenv('DB_USERNAME') . "\n";
    
} catch (Exception $e) {
    echo "❌ 開發環境配置載入失敗: " . $e->getMessage() . "\n";
    exit(1);
}

// 3. 測試 MAMP 資料庫連線
echo "\n3. 測試 MAMP 資料庫連線...\n";
try {
    // 使用 MAMP 設定直接連線
    $host = 'localhost';
    $port = '8889';
    $dbname = 'hero4helpdemofhs_hero4help';
    $username = 'root';
    $password = 'root';
    
    echo "連線參數:\n";
    echo "  Host: $host\n";
    echo "  Port: $port\n";
    echo "  Database: $dbname\n";
    echo "  Username: $username\n";
    echo "  Password: " . ($password ? '已設定' : '未設定') . "\n";
    
    // 嘗試連線
    $dsn = "mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "✅ MAMP 資料庫連線成功！\n";
    
    // 測試基本查詢
    $result = $pdo->query("SELECT COUNT(*) as count FROM users")->fetch();
    echo "✅ 用戶表查詢成功，用戶數量: " . $result['count'] . "\n";
    
} catch (PDOException $e) {
    echo "❌ MAMP 資料庫連線失敗: " . $e->getMessage() . "\n";
    
    // 提供診斷資訊
    echo "\n=== 診斷資訊 ===\n";
    echo "錯誤代碼: " . $e->getCode() . "\n";
    echo "錯誤訊息: " . $e->getMessage() . "\n";
    
    // 檢查資料庫是否存在
    try {
        $dsn_no_db = "mysql:host=$host;port=$port;charset=utf8mb4";
        $pdo_no_db = new PDO($dsn_no_db, $username, $password);
        echo "✅ MySQL 服務連線正常\n";
        
        // 檢查資料庫是否存在
        $stmt = $pdo_no_db->query("SHOW DATABASES LIKE '$dbname'");
        if ($stmt->rowCount() > 0) {
            echo "✅ 資料庫 '$dbname' 存在\n";
        } else {
            echo "❌ 資料庫 '$dbname' 不存在\n";
            echo "可用資料庫:\n";
            $databases = $pdo_no_db->query("SHOW DATABASES")->fetchAll(PDO::FETCH_COLUMN);
            foreach ($databases as $db) {
                echo "  - $db\n";
            }
        }
        
    } catch (PDOException $e2) {
        echo "❌ MySQL 服務連線失敗: " . $e2->getMessage() . "\n";
    }
}

// 4. 測試 Backend 載入器
echo "\n4. 測試 Backend 載入器...\n";
try {
    // 重新載入 Backend 載入器
    require_once 'backend/config/env_loader.php';
    
    // 檢查環境變數
    echo "   - APP_ENVIRONMENT: " . EnvLoader::get('APP_ENVIRONMENT') . "\n";
    echo "   - DB_HOST: " . EnvLoader::get('DB_HOST') . "\n";
    echo "   - DB_PORT: " . EnvLoader::get('DB_PORT') . "\n";
    echo "   - DB_NAME: " . EnvLoader::get('DB_NAME') . "\n";
    echo "   - DB_USERNAME: " . EnvLoader::get('DB_USERNAME') . "\n";
    
} catch (Exception $e) {
    echo "❌ Backend 載入器測試失敗: " . $e->getMessage() . "\n";
}

// 5. 測試 API 端點
echo "\n5. 測試 API 端點...\n";
try {
    // 測試 ping 端點
    $pingUrl = 'http://localhost:8888/here4help/backend/api/ping.php';
    $context = stream_context_create([
        'http' => [
            'timeout' => 5,
            'method' => 'GET'
        ]
    ]);
    
    $response = @file_get_contents($pingUrl, false, $context);
    if ($response) {
        $data = json_decode($response, true);
        if ($data && isset($data['pong'])) {
            echo "✅ Ping API 端點正常: " . $response . "\n";
        } else {
            echo "⚠️ Ping API 端點回應異常: " . $response . "\n";
        }
    } else {
        echo "⚠️ Ping API 端點無法訪問\n";
        echo "請確認 MAMP 已啟動且 URL 正確: $pingUrl\n";
    }
    
} catch (Exception $e) {
    echo "⚠️ API 端點測試失敗: " . $e->getMessage() . "\n";
}

echo "\n=== 測試完成 ===\n";
echo "📋 建議:\n";
echo "1. 如果資料庫連線失敗，請檢查 MAMP 是否正常啟動\n";
echo "2. 如果資料庫不存在，請在 MAMP 中建立資料庫\n";
echo "3. 如果 API 端點無法訪問，請檢查 MAMP 設定\n";
echo "4. 建議使用開發環境配置而非生產環境配置\n";
?>
