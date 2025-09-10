<?php
/**
 * 推薦碼生成工具類
 */
class ReferralCodeGenerator
{
    /**
     * 生成唯一的推薦碼
     * 
     * @param Database $db 資料庫實例
     * @param int $userId 用戶ID
     * @param int $length 推薦碼長度 (預設12位)
     * @param int $maxAttempts 最大嘗試次數
     * @return string 生成的推薦碼
     * @throws Exception 如果無法生成唯一推薦碼
     */
    public static function generate($db, $userId, $length = 12, $maxAttempts = 50)
    {
        if ($length > 20) {
            $length = 20; // 限制最大長度
        }
        
        $attempt = 0;
        
        do {
            $attempt++;
            
            // 生成推薦碼：字母數字組合，避免容易混淆的字符
            $characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            $referralCode = '';
            
            for ($i = 0; $i < $length; $i++) {
                $referralCode .= $characters[random_int(0, strlen($characters) - 1)];
            }
            
            // 檢查推薦碼是否已存在
            $existing = $db->fetch("SELECT id FROM users WHERE referral_code = ?", [$referralCode]);
            
            if (!$existing) {
                return $referralCode;
            }
            
        } while ($attempt < $maxAttempts);
        
        // 如果無法生成唯一推薦碼，使用用戶ID作為後綴
        $fallbackCode = 'REF' . str_pad($userId, 6, '0', STR_PAD_LEFT);
        
        // 再次檢查後備推薦碼是否唯一
        $existing = $db->fetch("SELECT id FROM users WHERE referral_code = ?", [$fallbackCode]);
        if ($existing) {
            // 如果後備碼也存在，加上時間戳
            $fallbackCode = 'REF' . $userId . substr(time(), -4);
        }
        
        return $fallbackCode;
    }
    
    /**
     * 為用戶生成並更新推薦碼
     * 
     * @param Database $db 資料庫實例
     * @param int $userId 用戶ID
     * @return string 生成的推薦碼
     */
    public static function generateAndUpdate($db, $userId)
    {
        $referralCode = self::generate($db, $userId);
        
        // 更新用戶的推薦碼
        $db->query("UPDATE users SET referral_code = ? WHERE id = ?", [$referralCode, $userId]);
        
        return $referralCode;
    }
}
?>
