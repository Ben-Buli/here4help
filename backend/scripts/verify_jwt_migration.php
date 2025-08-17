<?php
/**
 * JWT 遷移驗證腳本
 * 檢查遷移後的結果
 * 
 * 注意：此腳本用於驗證 JWT 遷移結果
 * 用戶已手動解決大部分語法和遷移問題
 * 建議：腳本執行後仍需手動檢查和修復剩餘問題
 */

class JWTMigrationVerifier {
    private $apiDir;
    private $verifiedFiles = [];
    private $errors = [];
    
    public function __construct($apiDir = null) {
        $this->apiDir = $apiDir ?: __DIR__ . '/../api';
    }
    
    /**
     * 執行驗證
     */
    public function verify() {
        echo "🔍 開始驗證 JWT 遷移結果...\n";
        echo "📁 API 目錄: {$this->apiDir}\n\n";
        
        // 檢查目錄是否存在
        if (!is_dir($this->apiDir)) {
            echo "❌ API 目錄不存在: {$this->apiDir}\n";
            return false;
        }
        
        // 1. 檢查 .htaccess
        echo "🔧 步驟 1: 檢查 .htaccess...\n";
        $this->checkHtaccess();
        
        // 2. 檢查認證 API
        echo "\n🔐 步驟 2: 檢查認證 API...\n";
        $this->checkAuthAPIs();
        
        // 3. 檢查其他 API
        echo "\n📡 步驟 3: 檢查其他 API...\n";
        $this->checkOtherAPIs();
        
        // 4. 語法檢查
        echo "\n📝 步驟 4: 語法檢查...\n";
        $this->checkSyntax();
        
        // 輸出結果
        $this->printResults();
        
        return true;
    }
    
    /**
     * 檢查 .htaccess
     */
    private function checkHtaccess() {
        $htaccessPath = $this->apiDir . '/../.htaccess';
        
        if (!file_exists($htaccessPath)) {
            echo "  ❌ .htaccess 文件不存在\n";
            $this->errors[] = ".htaccess 文件不存在";
            return;
        }
        
        $content = file_get_contents($htaccessPath);
        
        $checks = [
            'SetEnvIf Authorization' => 'Authorization header 轉發',
            'Access-Control-Allow-Origin' => 'CORS 設置',
            'Access-Control-Allow-Headers' => 'CORS Headers',
            'HTTP_AUTHORIZATION' => 'HTTP_AUTHORIZATION 設置'
        ];
        
        foreach ($checks as $pattern => $description) {
            if (strpos($content, $pattern) !== false) {
                echo "  ✅ {$description}: 正確\n";
            } else {
                echo "  ❌ {$description}: 缺失\n";
                $this->errors[] = ".htaccess 缺少 {$description}";
            }
        }
    }
    
    /**
     * 檢查認證 API
     */
    private function checkAuthAPIs() {
        $authDir = $this->apiDir . '/auth';
        if (!is_dir($authDir)) {
            echo "  ⚠️ 認證目錄不存在，跳過\n";
            return;
        }
        
        $authFiles = glob($authDir . '/*.php');
        foreach ($authFiles as $file) {
            $this->checkAuthFile($file);
        }
    }
    
    /**
     * 檢查認證文件
     */
    private function checkAuthFile($filePath) {
        $fileName = basename($filePath);
        echo "  📄 檢查認證 API: {$fileName}...";
        
        try {
            $content = file_get_contents($filePath);
            if (!$content) {
                echo " ❌ 無法讀取文件\n";
                return;
            }
            
            $checks = [
                'require_once \'../../utils/JWTManager.php\';' => 'JWTManager 引入',
                'JWTManager::generateToken' => 'JWT Token 生成',
                'base64_encode' => 'Base64 編碼（應該不存在）',
                'base64_decode' => 'Base64 解碼（應該不存在）'
            ];
            
            $allPassed = true;
            foreach ($checks as $pattern => $description) {
                if (strpos($pattern, 'base64') !== false) {
                    // Base64 相關應該不存在
                    if (strpos($content, $pattern) !== false) {
                        echo " ❌ {$description}: 仍在使用\n";
                        $allPassed = false;
                    }
                } else {
                    // 其他應該存在
                    if (strpos($content, $pattern) === false) {
                        echo " ❌ {$description}: 缺失\n";
                        $allPassed = false;
                    }
                }
            }
            
            if ($allPassed) {
                echo " ✅ 檢查通過\n";
                $this->verifiedFiles[] = $filePath;
            } else {
                $this->errors[] = "認證文件檢查失敗: {$fileName}";
            }
            
        } catch (Exception $e) {
            echo " ❌ 檢查失敗: " . $e->getMessage() . "\n";
            $this->errors[] = "檢查失敗 {$fileName}: " . $e->getMessage();
        }
    }
    
    /**
     * 檢查其他 API
     */
    private function checkOtherAPIs() {
        $files = $this->getAllPHPFiles();
        
        foreach ($files as $file) {
            // 跳過認證文件
            if (strpos($file, '/auth/') !== false) {
                continue;
            }
            
            $this->checkOtherFile($file);
        }
    }
    
    /**
     * 檢查其他文件
     */
    private function checkOtherFile($filePath) {
        $fileName = basename($filePath);
        $category = $this->getFileCategory($filePath);
        echo "  📄 檢查 {$category}: {$fileName}...";
        
        try {
            $content = file_get_contents($filePath);
            if (!$content) {
                echo " ❌ 無法讀取文件\n";
                return;
            }
            
            $checks = [
                'require_once \'../../utils/TokenValidator.php\';' => 'TokenValidator 引入',
                'TokenValidator::validateAuthHeader' => 'TokenValidator 使用',
                'function validateToken' => '舊驗證函數（應該不存在）',
                'base64_decode' => 'Base64 解碼（應該不存在）'
            ];
            
            $allPassed = true;
            foreach ($checks as $pattern => $description) {
                if (strpos($pattern, 'function validateToken') !== false || strpos($pattern, 'base64_decode') !== false) {
                    // 這些應該不存在
                    if (strpos($content, $pattern) !== false) {
                        echo " ❌ {$description}: 仍在使用\n";
                        $allPassed = false;
                    }
                } else {
                    // 這些應該存在
                    if (strpos($content, $pattern) === false) {
                        echo " ❌ {$description}: 缺失\n";
                        $allPassed = false;
                    }
                }
            }
            
            if ($allPassed) {
                echo " ✅ 檢查通過\n";
                $this->verifiedFiles[] = $filePath;
            } else {
                $this->errors[] = "其他文件檢查失敗: {$fileName}";
            }
            
        } catch (Exception $e) {
            echo " ❌ 檢查失敗: " . $e->getMessage() . "\n";
            $this->errors[] = "檢查失敗 {$fileName}: " . $e->getMessage();
        }
    }
    
    /**
     * 語法檢查
     */
    private function checkSyntax() {
        $files = $this->getAllPHPFiles();
        $syntaxErrors = 0;
        
        foreach ($files as $file) {
            $fileName = basename($file);
            echo "  📄 語法檢查: {$fileName}...";
            
            $output = [];
            $returnCode = 0;
            exec("php -l " . escapeshellarg($file) . " 2>&1", $output, $returnCode);
            
            if ($returnCode === 0) {
                echo " ✅ 語法正確\n";
            } else {
                echo " ❌ 語法錯誤\n";
                $syntaxErrors++;
                $this->errors[] = "語法錯誤: {$fileName}";
            }
        }
        
        if ($syntaxErrors === 0) {
            echo "  🎉 所有文件語法正確！\n";
        } else {
            echo "  ⚠️ 發現 {$syntaxErrors} 個語法錯誤\n";
        }
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
        echo "\n🎉 JWT 遷移驗證完成！\n";
        echo "📊 統計信息:\n";
        echo "  ✅ 驗證通過: " . count($this->verifiedFiles) . " 個文件\n";
        echo "  ❌ 錯誤數量: " . count($this->errors) . " 個\n";
        
        if (!empty($this->errors)) {
            echo "\n❌ 錯誤詳情:\n";
            foreach ($this->errors as $error) {
                echo "  - {$error}\n";
            }
            
            echo "\n🔧 建議:\n";
            echo "  1. 修復發現的問題\n";
            echo "  2. 重新運行驗證\n";
            echo "  3. 測試 JWT 功能\n";
        } else {
            echo "\n🎉 所有檢查通過！\n";
            echo "💡 JWT 遷移成功完成\n";
        }
    }
}

// 執行驗證
if (php_sapi_name() === 'cli') {
    $verifier = new JWTMigrationVerifier();
    $verifier->verify();
} else {
    echo "此腳本需要在命令行中執行\n";
    echo "使用方法: php verify_jwt_migration.php\n";
}
?>
