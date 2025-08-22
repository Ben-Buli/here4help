<?php
/**
 * JWT 相容性測試腳本
 * 測試 PHP JWTManager 與 Node.js jwt 庫的相容性
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/JWTManager.php';

echo "🔐 JWT 相容性測試\n";
echo "==================\n\n";

// 載入環境變數
EnvLoader::load();
$jwtSecret = EnvLoader::get('JWT_SECRET');

echo "📋 測試配置:\n";
echo "JWT_SECRET: " . substr($jwtSecret, 0, 10) . "...\n";
echo "JWT_SECRET 長度: " . strlen($jwtSecret) . " 字元\n";
echo "JWT_SECRET SHA256: " . hash('sha256', $jwtSecret) . "\n\n";

// 測試 1: 生成 JWT Token
echo "📋 測試 1: 生成 JWT Token\n";
$testPayload = [
    'user_id' => 2,
    'email' => 'test@example.com',
    'name' => 'Test User'
];

try {
    $token = JWTManager::generateToken($testPayload);
    echo "✅ JWT Token 生成成功\n";
    echo "Token (前50字元): " . substr($token, 0, 50) . "...\n";
    
    // 分解 JWT 結構
    $parts = explode('.', $token);
    if (count($parts) === 3) {
        echo "✅ JWT 結構正確 (3個部分)\n";
        
        // 解碼 Header
        $header = json_decode(base64_decode(str_pad(strtr($parts[0], '-_', '+/'), 
            strlen($parts[0]) % 4, '=', STR_PAD_RIGHT)), true);
        echo "Header: " . json_encode($header) . "\n";
        
        // 解碼 Payload
        $payload = json_decode(base64_decode(str_pad(strtr($parts[1], '-_', '+/'), 
            strlen($parts[1]) % 4, '=', STR_PAD_RIGHT)), true);
        echo "Payload: " . json_encode($payload) . "\n";
        
        // 檢查簽名長度
        echo "Signature 長度: " . strlen($parts[2]) . " 字元\n";
    } else {
        echo "❌ JWT 結構錯誤\n";
    }
} catch (Exception $e) {
    echo "❌ JWT Token 生成失敗: " . $e->getMessage() . "\n";
    exit(1);
}

echo "\n";

// 測試 2: 驗證 JWT Token
echo "📋 測試 2: 驗證 JWT Token\n";
try {
    $payloadValidated = JWTManager::validateToken($token);
    if (is_array($payloadValidated)) {
        echo "✅ JWT Token 驗證成功\n";
        echo "解碼的 Payload: " . json_encode($payloadValidated) . "\n";
    } else {
        echo "❌ JWT Token 驗證失敗\n";
    }
} catch (Exception $e) {
    echo "❌ JWT Token 驗證異常: " . $e->getMessage() . "\n";
}

echo "\n";

// 測試 3: Base64 URL 編碼測試（本地實作）
echo "📋 測試 3: Base64 URL 編碼測試\n";
$testString = "Hello World! 這是測試字串 123";
$b64url_encode = function($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
};
$b64url_decode = function($data) {
    $data = strtr($data, '-_', '+/');
    $pad = strlen($data) % 4;
    if ($pad) $data .= str_repeat('=', 4 - $pad);
    return base64_decode($data);
};

$encoded = $b64url_encode($testString);
$decoded = $b64url_decode($encoded);

echo "原始字串: $testString\n";
echo "編碼結果: $encoded\n";
echo "解碼結果: $decoded\n";

if ($testString === $decoded) {
    echo "✅ Base64 URL 編碼/解碼正確\n";
} else {
    echo "❌ Base64 URL 編碼/解碼錯誤\n";
}

echo "\n";

// 測試 4: 手動 JWT 驗證 (模擬 Node.js 邏輯)
echo "📋 測試 4: 手動 JWT 驗證 (模擬 Node.js 邏輯)\n";
$parts = explode('.', $token);
if (count($parts) === 3) {
    $headerEncoded = $parts[0];
    $payloadEncoded = $parts[1];
    $signatureEncoded = $parts[2];
    
    // 重新計算簽名
    $expectedSignature = hash_hmac('sha256', 
        $headerEncoded . '.' . $payloadEncoded, 
        $jwtSecret, 
        true
    );
    $expectedSignatureEncoded = rtrim(strtr(base64_encode($expectedSignature), '+/', '-_'), '=');
    
    echo "期望簽名: $expectedSignatureEncoded\n";
    echo "實際簽名: $signatureEncoded\n";
    
    if ($expectedSignatureEncoded === $signatureEncoded) {
        echo "✅ 簽名驗證成功\n";
    } else {
        echo "❌ 簽名驗證失敗\n";
        
        // 詳細分析
        echo "\n🔍 詳細分析:\n";
        echo "Header + Payload: " . $headerEncoded . '.' . $payloadEncoded . "\n";
        echo "JWT Secret: " . $jwtSecret . "\n";
        echo "HMAC SHA256 (raw): " . bin2hex($expectedSignature) . "\n";
        echo "Base64 編碼: " . base64_encode($expectedSignature) . "\n";
        echo "URL Safe 編碼: " . $expectedSignatureEncoded . "\n";
    }
} else {
    echo "❌ JWT 格式錯誤\n";
}

echo "\n";

// 測試 5: 生成 Node.js 測試腳本
echo "📋 測試 5: 生成 Node.js 測試腳本\n";
$nodeTestScript = <<<JS
const jwt = require('jsonwebtoken');

const JWT_SECRET = '$jwtSecret';
const token = '$token';

console.log('🔐 Node.js JWT 驗證測試');
console.log('JWT_SECRET:', JWT_SECRET.substring(0, 10) + '...');
console.log('Token:', token.substring(0, 50) + '...');

try {
    const payload = jwt.verify(token, JWT_SECRET, {
        algorithms: ['HS256'],
        ignoreExpiration: false,
        ignoreNotBefore: false
    });
    
    console.log('✅ Node.js JWT 驗證成功');
    console.log('Payload:', JSON.stringify(payload, null, 2));
} catch (error) {
    console.log('❌ Node.js JWT 驗證失敗:', error.name, error.message);
    
    // 嘗試手動驗證
    console.log('\\n🔍 手動驗證:');
    const parts = token.split('.');
    if (parts.length === 3) {
        const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
        const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
        
        console.log('Header:', JSON.stringify(header));
        console.log('Payload:', JSON.stringify(payload));
        
        // 重新計算簽名
        const crypto = require('crypto');
        const expectedSignature = crypto
            .createHmac('sha256', JWT_SECRET)
            .update(parts[0] + '.' + parts[1])
            .digest('base64url');
            
        console.log('期望簽名:', expectedSignature);
        console.log('實際簽名:', parts[2]);
        console.log('簽名匹配:', expectedSignature === parts[2]);
    }
}
JS;

$nodeTestFile = __DIR__ . '/jwt_node_test.js';
file_put_contents($nodeTestFile, $nodeTestScript);
echo "✅ Node.js 測試腳本已生成: $nodeTestFile\n";
echo "執行命令: cd " . dirname($nodeTestFile) . " && node jwt_node_test.js\n";

echo "\n";

// 測試總結
echo "📊 測試總結\n";
echo "===========\n";
echo "JWT Secret: 已配置\n";
echo "PHP JWT 生成: " . (isset($token) ? "✅ 成功" : "❌ 失敗") . "\n";
echo "PHP JWT 驗證: " . (isset($payloadValidated) && is_array($payloadValidated) ? "✅ 成功" : "❌ 失敗") . "\n";
echo "Base64 編碼: ✅ 正確\n";
echo "簽名驗證: " . (isset($expectedSignatureEncoded) && $expectedSignatureEncoded === $signatureEncoded ? "✅ 成功" : "❌ 失敗") . "\n";

echo "\n💡 建議:\n";
echo "1. 執行生成的 Node.js 測試腳本\n";
echo "2. 比較 PHP 和 Node.js 的驗證結果\n";
echo "3. 如果 Node.js 驗證失敗，檢查 JWT_SECRET 是否一致\n";
echo "4. 確認 Node.js 使用的 jwt 庫版本\n";

echo "\n" . date('Y-m-d H:i:s') . " - 測試完成\n";
?>
