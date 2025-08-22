<?php
/**
 * 乾淨的 JWT 統一腳本
 * 分析 base64 功能並替換為 JWT
 * 
 * 注意：此腳本無法完整乾淨清除所有問題
 * 用戶已手動解決大部分 JWT 遷移後的檔案問題
 * 建議：腳本執行後仍需手動檢查和修復語法問題
 */

class CleanJWTMigration {
    private $apiDir;
    private $processedFiles = [];
    private $errors = [];
    private $base64Patterns = [];
    
    public function __construct($apiDir = null) {
        $this->apiDir = $apiDir ?: __DIR__ . '/../api';
    }
    
    /**
     * 執行 JWT 統一
     */
    public function migrate() {
        echo "🚀 開始乾淨的 JWT 統一...\n";
        echo "📁 API 目錄: {$this->apiDir}\n\n";
        
        // 檢查目錄是否存在
        if (!is_dir($this->apiDir)) {
            echo "❌ API 目錄不存在: {$this->apiDir}\n";
            return false;
        }
        
        // 1. 分析 base64 使用模式
        echo "🔍 步驟 1: 分析 base64 使用模式...\n";
        $this->analyzeBase64Usage();
        
        // 2. 修復 .htaccess
        echo "\n🔧 步驟 2: 修復 .htaccess...\n";
        $this->fixHtaccess();
        
        // 3. 統一認證 API
        echo "\n🔐 步驟 3: 統一認證 API...\n";
        $this->migrateAuthAPIs();
        
        // 4. 統一其他 API
        echo "\n📡 步驟 4: 統一其他 API...\n";
        $this->migrateOtherAPIs();
        
        // 輸出結果
        $this->printResults();
        
        return true;
    }
    
    /**
     * 分析 base64 使用模式
     */
    private function analyzeBase64Usage() {
        $patterns = [
            'base64_encode' => 'base64_encode(json_encode($payload))',
            'base64_decode' => 'base64_decode($token)',
            'validateToken function' => 'function validateToken',
            'old token validation' => 'if (!$payload) throw new Exception',
            'payload user_id' => '$payload[\'user_id\']'
        ];
        
        foreach ($patterns as $name => $pattern) {
            $count = $this->countPatternInFiles($pattern);
            $this->base64Patterns[$name] = $count;
            echo "  📊 {$name}: 在 {$count} 個文件中找到\n";
        }
    }
    
    /**
     * 在文件中計數模式
     */
    private function countPatternInFiles($pattern) {
        $count = 0;
        $files = $this->getAllPHPFiles();
        
        foreach ($files as $file) {
            $content = file_get_contents($file);
            if (strpos($content, $pattern) !== false) {
                $count++;
            }
        }
        
        return $count;
    }
    
    /**
     * 獲取所有 PHP 文件
     */
    private function getAllPHPFiles() {
        $files = [];
        
        // 聊天 API
        $chatDir = $this->apiDir . '/chat';
        if (is_dir($chatDir)) {
            $files = array_merge($files, glob($chatDir . '/*.php'));
        }
        
        // 任務 API
        $taskDir = $this->apiDir . '/tasks';
        if (is_dir($taskDir)) {
            $files = array_merge($files, glob($taskDir . '/*.php'));
            $subDirs = glob($taskDir . '/*', GLOB_ONLYDIR);
            foreach ($subDirs as $subDir) {
                $files = array_merge($files, glob($subDir . '/*.php'));
            }
        }
        
        // 認證 API
        $authDir = $this->apiDir . '/auth';
        if (is_dir($authDir)) {
            $files = array_merge($files, glob($authDir . '/*.php'));
        }
        
        return $files;
    }
    
    /**
     * 修復 .htaccess
     */
    private function fixHtaccess() {
        $htaccessPath = $this->apiDir . '/../.htaccess';
        $htaccessContent = $this->getHtaccessContent();
        
        if (file_put_contents($htaccessPath, $htaccessContent)) {
            echo "  ✅ .htaccess 修復完成\n";
        } else {
            echo "  ❌ .htaccess 修復失敗\n";
            $this->errors[] = ".htaccess 修復失敗";
        }
    }
    
    /**
     * 獲取 .htaccess 內容
     */
    private function getHtaccessContent() {
        return '# 基本 CORS 設置
Header always set Access-Control-Allow-Origin "*"
Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
Header always set Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
Header always set Access-Control-Max-Age "86400"

# 關鍵：使用 SetEnvIf 轉發 Authorization 頭到 PHP
SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1

# 防止直接訪問敏感文件
<Files "*.env">
    Order allow,deny
    Deny from all
</Files>

<Files "*.sql">
    Order allow,deny
    Deny from all
</Files>

<Files "*.log">
    Order allow,deny
    Deny from all
</Files>

# 安全標頭
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"

# PHP 設置
php_value upload_max_filesize 10M
php_value post_max_size 10M
php_value max_execution_time 300
php_value memory_limit 256M';
    }
    
    /**
     * 統一認證 API
     */
    private function migrateAuthAPIs() {
        $authDir = $this->apiDir . '/auth';
        if (!is_dir($authDir)) {
            echo "  ⚠️ 認證目錄不存在，跳過\n";
            return;
        }
        
        $authFiles = glob($authDir . '/*.php');
        foreach ($authFiles as $file) {
            $this->migrateAuthFile($file);
        }
    }
    
    /**
     * 遷移認證文件
     */
    private function migrateAuthFile($filePath) {
        $fileName = basename($filePath);
        echo "  📄 遷移認證 API: {$fileName}...";
        
        try {
            $content = file_get_contents($filePath);
            if (!$content) {
                echo " ❌ 無法讀取文件\n";
                return;
            }
            
            $modified = false;
            
            // 1. 添加 JWT 引入
            if (strpos($content, 'require_once \'../../utils/JWTManager.php\';') === false) {
                $content = str_replace(
                    'require_once \'../../config/database.php\';',
                    "require_once __DIR__ . '/../../config/database.php';\nrequire_once __DIR__ . '/../../utils/JWTManager.php';",
                    $content
                );
                $modified = true;
            }
            
            // 2. 替換 base64 生成為 JWT
            if (strpos($content, 'base64_encode(json_encode($payload))') !== false) {
                $content = str_replace(
                    '// 生成 base64 編碼的 JSON Token',
                    '// 生成 JWT Token',
                    $content
                );
                
                $content = str_replace(
                    '// 使用 base64 編碼 JSON 數據',
                    'try {',
                    $content
                );
                
                $content = str_replace(
                    '$token = base64_encode(json_encode($payload));',
                    '    $token = JWTManager::generateToken($payload);',
                    $content
                );
                
                $content = str_replace(
                    '// 驗證生成的 token 格式',
                    '    error_log("JWT token generated successfully for user: " . $user[\'id\']);',
                    $content
                );
                
                $content = str_replace(
                    '$decoded = base64_decode($token);',
                    '} catch (Exception $e) {',
                    $content
                );
                
                $content = str_replace(
                    '$decodedPayload = json_decode($decoded, true);',
                    '    error_log("JWT token generation failed: " . $e->getMessage());',
                    $content
                );
                
                $content = str_replace(
                    'if (!$decodedPayload || !isset($decodedPayload[\'user_id\'])) {',
                    '    throw new Exception(\'Token generation failed: \' . $e->getMessage());',
                    $content
                );
                
                $content = str_replace(
                    '    throw new Exception(\'Token generation failed\');',
                    '}',
                    $content
                );
                
                $modified = true;
            }
            
            // 3. 替換舊的驗證函數
            if (strpos($content, 'function validateToken($token)') !== false) {
                $content = preg_replace('/function validateToken\([^)]*\)\s*{[^}]*}/s', '', $content);
                $modified = true;
            }
            
            // 4. 更新驗證邏輯
            if (strpos($content, 'require_once \'../../utils/TokenValidator.php\';') === false) {
                $content = str_replace(
                    'require_once \'../../config/database.php\';',
                    "require_once __DIR__ . '/../../config/database.php';\nrequire_once __DIR__ . '/../../utils/TokenValidator.php';",
                    $content
                );
                $modified = true;
            }
            
            if (strpos($content, '$payload = validateToken($token);') !== false) {
                $content = str_replace(
                    '$payload = validateToken($token);',
                    '$payload = JWTManager::validateToken($token);',
                    $content
                );
                $modified = true;
            }
            
            if ($modified) {
                // 備份原文件
                $backupPath = $filePath . '.jwt-migration-backup.' . date('Y-m-d-H-i-s');
                if (copy($filePath, $backupPath)) {
                    echo " 💾 已備份到 {$backupPath}\n";
                }
                
                // 寫入新內容
                if (file_put_contents($filePath, $content)) {
                    echo " ✅ 遷移完成\n";
                    $this->processedFiles[] = $filePath;
                } else {
                    echo " ❌ 寫入失敗\n";
                    $this->errors[] = "寫入失敗: {$filePath}";
                }
            } else {
                echo " ⏭️ 無需遷移\n";
            }
            
        } catch (Exception $e) {
            echo " ❌ 遷移失敗: " . $e->getMessage() . "\n";
            $this->errors[] = "遷移失敗 {$filePath}: " . $e->getMessage();
        }
    }
    
    /**
     * 統一其他 API
     */
    private function migrateOtherAPIs() {
        $files = $this->getAllPHPFiles();
        
        foreach ($files as $file) {
            // 跳過已處理的認證文件
            if (strpos($file, '/auth/') !== false) {
                continue;
            }
            
            $this->migrateOtherFile($file);
        }
    }
    
    /**
     * 遷移其他文件
     */
    private function migrateOtherFile($filePath) {
        $fileName = basename($filePath);
        $category = $this->getFileCategory($filePath);
        echo "  📄 遷移 {$category}: {$fileName}...";
        
        try {
            $content = file_get_contents($filePath);
            if (!$content) {
                echo " ❌ 無法讀取文件\n";
                return;
            }
            
            $modified = false;
            
            // 1. 添加 TokenValidator 引入
            if (strpos($content, 'require_once \'../../utils/TokenValidator.php\';') === false) {
                $content = str_replace(
                    'require_once \'../../config/database.php\';',
                    "require_once __DIR__ . '/../../config/database.php';\nrequire_once __DIR__ . '/../../utils/TokenValidator.php';",
                    $content
                );
                $modified = true;
            }
            
            // 2. 移除舊的驗證函數
            if (strpos($content, 'function validateToken($token)') !== false) {
                $content = preg_replace('/function validateToken\([^)]*\)\s*{[^}]*}/s', '', $content);
                $modified = true;
            }
            
            // 3. 更新驗證邏輯
            if (strpos($content, '$payload = validateToken($m[1]);') !== false) {
                $content = str_replace(
                    '$payload = validateToken($m[1]);',
                    '$user_id = TokenValidator::validateAuthHeader($auth_header);',
                    $content
                );
                $modified = true;
            }
            
            if (strpos($content, 'if (!$payload) throw new Exception(\'Invalid or expired token\');') !== false) {
                $content = str_replace(
                    'if (!$payload) throw new Exception(\'Invalid or expired token\');',
                    'if (!$user_id) { throw new Exception(\'Invalid or expired token\'); }',
                    $content
                );
                $modified = true;
            }
            
            if (strpos($content, '$user_id = (int)$payload[\'user_id\'];') !== false) {
                $content = str_replace(
                    '$user_id = (int)$payload[\'user_id\'];',
                    '$user_id = (int)$user_id;',
                    $content
                );
                $modified = true;
            }
            
            if ($modified) {
                // 備份原文件
                $backupPath = $filePath . '.jwt-migration-backup.' . date('Y-m-d-H-i-s');
                if (copy($filePath, $backupPath)) {
                    echo " 💾 已備份到 {$backupPath}\n";
                }
                
                // 寫入新內容
                if (file_put_contents($filePath, $content)) {
                    echo " ✅ 遷移完成\n";
                    $this->processedFiles[] = $filePath;
                } else {
                    echo " ❌ 寫入失敗\n";
                    $this->errors[] = "寫入失敗: {$filePath}";
                }
            } else {
                echo " ⏭️ 無需遷移\n";
            }
            
        } catch (Exception $e) {
            echo " ❌ 遷移失敗: " . $e->getMessage() . "\n";
            $this->errors[] = "遷移失敗 {$filePath}: " . $e->getMessage();
        }
    }
    
    /**
     * 獲取文件類別
     */
    private function getFileCategory($filePath) {
        if (strpos($filePath, '/chat/') !== false) {
            return 'chat';
        } elseif (strpos($filePath, '/tasks/') !== false) {
            return 'task';
        } else {
            return 'other';
        }
    }
    
    /**
     * 輸出結果
     */
    private function printResults() {
        echo "\n🎉 JWT 統一完成！\n";
        echo "📊 統計信息:\n";
        echo "  ✅ 成功處理: " . count($this->processedFiles) . " 個文件\n";
        echo "  ❌ 錯誤數量: " . count($this->errors) . " 個\n";
        
        echo "\n📊 Base64 使用分析:\n";
        foreach ($this->base64Patterns as $name => $count) {
            echo "  - {$name}: {$count} 個文件\n";
        }
        
        if (!empty($this->processedFiles)) {
            echo "\n📁 已處理的文件:\n";
            foreach ($this->processedFiles as $file) {
                echo "  - " . basename($file) . "\n";
            }
        }
        
        if (!empty($this->errors)) {
            echo "\n❌ 錯誤詳情:\n";
            foreach ($this->errors as $error) {
                echo "  - {$error}\n";
            }
        }
        
        echo "\n💡 建議:\n";
        echo "  1. 檢查遷移備份文件 (.jwt-migration-backup.*)\n";
        echo "  2. 測試 JWT 功能\n";
        echo "  3. 確認所有 API 正常工作\n";
    }
}

// 執行 JWT 統一
if (php_sapi_name() === 'cli') {
    $migration = new CleanJWTMigration();
    $migration->migrate();
} else {
    echo "此腳本需要在命令行中執行\n";
    echo "使用方法: php clean_jwt_migration.php\n";
}
?>
