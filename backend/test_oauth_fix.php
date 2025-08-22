<?php
/**
 * OAuth 修復測試腳本
 * 測試重複 Google 用戶 ID 的處理邏輯
 */

require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/utils/JWTManager.php';

try {
    $db = Database::getInstance();
    
    // 測試用的 Google 用戶 ID（已存在於資料庫中）
    $googleId = '114594374536341711078';
    $email = 'elies818@gmail.com';
    $name = 'Buli Yukan';
    $avatarUrl = 'https://lh3.googleusercontent.com/a/test.jpg';
    $accessToken = 'test_access_token_' . time();
    
    echo "🔍 測試 OAuth 修復邏輯\n";
    echo "Google ID: $googleId\n";
    echo "Email: $email\n";
    echo "Name: $name\n\n";
    
    // 1. 檢查是否已存在 user_identity
    echo "1️⃣ 檢查現有的 user_identity 記錄...\n";
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'google' AND ui.provider_user_id = ?",
        [$googleId]
    );
    
    $existingIdentity = $stmt->fetch();
    
    if ($existingIdentity) {
        echo "✅ 找到現有用戶，用戶 ID: {$existingIdentity['user_id']}\n";
        echo "   用戶名稱: {$existingIdentity['name']}\n";
        echo "   用戶 Email: {$existingIdentity['email']}\n";
        
        // 更新 access_token
        $db->query(
            "UPDATE user_identities SET 
             access_token = ?, 
             updated_at = NOW() 
             WHERE id = ?",
            [$accessToken, $existingIdentity['id']]
        );
        
        echo "✅ 成功更新 access_token\n";
        
        $user = $existingIdentity;
        $isNewUser = false;
    } else {
        echo "❌ 未找到現有用戶，檢查 email 是否已存在...\n";
        
        // 檢查 email 是否已存在於 users 表
        $stmt = $db->query(
            "SELECT * FROM users WHERE email = ?",
            [$email]
        );
        
        $existingUser = $stmt->fetch();
        
        if ($existingUser) {
            echo "✅ Email 已存在，檢查是否已綁定 Google 帳號，用戶 ID: {$existingUser['id']}\n";
            
            // 檢查是否已經有對應的 user_identity 記錄
            $stmt = $db->query(
                "SELECT * FROM user_identities WHERE user_id = ? AND provider = 'google' AND provider_user_id = ?",
                [$existingUser['id'], $googleId]
            );
            
            $existingIdentity = $stmt->fetch();
            
            if ($existingIdentity) {
                echo "✅ 已存在 user_identity 記錄，更新 access_token\n";
                
                // 更新現有的 user_identity 記錄
                $db->query(
                    "UPDATE user_identities SET 
                     access_token = ?, 
                     updated_at = NOW() 
                     WHERE id = ?",
                    [$accessToken, $existingIdentity['id']]
                );
                
                $user = $existingUser;
                $isNewUser = false;
                
                echo "✅ 成功更新現有 Google 帳號綁定\n";
            } else {
                echo "❌ 需要綁定 Google 帳號到現有用戶\n";
                
                // 這裡會嘗試插入新記錄，但應該會失敗
                try {
                    $db->query(
                        "INSERT INTO user_identities (
                            user_id, provider, provider_user_id, email, name, avatar_url, 
                            access_token, raw_profile, created_at, updated_at
                        ) VALUES (?, 'google', ?, ?, ?, ?, ?, ?, NOW(), NOW())",
                        [
                            $existingUser['id'], 
                            $googleId, 
                            $email, 
                            $name, 
                            $avatarUrl, 
                            $accessToken,
                            json_encode(['test' => 'data'])
                        ]
                    );
                    
                    echo "❌ 這應該會失敗（重複記錄）\n";
                } catch (Exception $e) {
                    echo "✅ 正確捕獲重複記錄錯誤: " . $e->getMessage() . "\n";
                }
            }
        } else {
            echo "❌ Email 不存在，這是一個新用戶\n";
        }
    }
    
    echo "\n🎯 測試完成\n";
    
} catch (Exception $e) {
    echo "❌ 測試失敗: " . $e->getMessage() . "\n";
}
?>
