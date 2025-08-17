<?php
/**
 * JWT 遷移腳本
 * 用於批量更新 API 文件，從舊版 base64 token 遷移到 JWT
 * 
 * @author Here4Help Team
 * @version 1.0.0
 * @since 2025-01-11
 */

class JWTMigration {
    private $apiDir;
    private $processedFiles = [];
    private $errors = [];
    
    public function __construct($apiDir = null) {
        $this->apiDir = $apiDir ?: __DIR__ . '/../api';
    }
    
    /**
     * 執行遷移
     */
    public function migrate() {
        echo "🚀 開始 JWT 遷移...\n";
        echo "📁 API 目錄: {$this->apiDir}\n\n";
        
        // 檢查目錄是否存在
        if (!is_dir($this->apiDir)) {
            echo "❌ API 目錄不存在: {$this->apiDir}\n";
            return false;
        }
        
        // 遷移聊天 API
        $this->migrateChatAPIs();
        
        // 遷移任務 API
        $this->migrateTaskAPIs();
        
        // 遷移其他 API
        $this->migrateOtherAPIs();
        
        // 輸出結果
        $this->printResults();
        
        return true;
    }
    
    /**
     * 遷移聊天 API
     */
    private function migrateChatAPIs() {
        echo "💬 遷移聊天 API...\n";
        
        $chatDir = $this->apiDir . '/chat';
        if (!is_dir($chatDir)) {
            echo "⚠️ 聊天目錄不存在，跳過\n";
            return;
        }
        
        $chatFiles = glob($chatDir . '/*.php');
        foreach ($chatFiles as $file) {
            $this->migrateFile($file, 'chat');
        }
    }
    
    /**
     * 遷移任務 API
     */
    private function migrateTaskAPIs() {
        echo "📝 遷移任務 API...\n";
        
        $taskDir = $this->apiDir . '/tasks';
        if (!is_dir($taskDir)) {
            echo "⚠️ 任務目錄不存在，跳過\n";
            return;
        }
        
        $taskFiles = glob($taskDir . '/*.php');
        foreach ($taskFiles as $file) {
            $this->migrateFile($file, 'task');
        }
        
        // 檢查子目錄
        $subDirs = glob($taskDir . '/*', GLOB_ONLYDIR);
        foreach ($subDirs as $subDir) {
            $subFiles = glob($subDir . '/*.php');
            foreach ($subFiles as $file) {
                $this->migrateFile($file, 'task');
            }
        }
    }
    
    /**
     * 遷移其他 API
     */
    private function migrateOtherAPIs() {
        echo "🔧 遷移其他 API...\n";
        
        $otherDirs = ['referral', 'points', 'universities', 'languages'];
        foreach ($otherDirs as $dir) {
            $fullDir = $this->apiDir . '/' . $dir;
            if (is_dir($fullDir)) {
                $files = glob($fullDir . '/*.php');
                foreach ($files as $file) {
                    $this->migrateFile($file, $dir);
                }
            }
        }
    }
    
    /**
     * 遷移單個文件
     */
    private function migrateFile($filePath, $category) {
        $fileName = basename($filePath);
        echo "  📄 處理 {$category}/{$fileName}...";
        
        try {
            $content = file_get_contents($filePath);
            if (!$content) {
                echo " ❌ 無法讀取文件\n";
                $this->errors[] = "無法讀取文件: {$filePath}";
                return;
            }
            
            $originalContent = $content;
            $modified = false;
            
            // 檢查是否需要遷移
            if (strpos($content, 'function validateToken') !== false || 
                strpos($content, 'base64_decode') !== false) {
                
                // 添加 TokenValidator 引入
                if (strpos($content, 'require_once') !== false) {
                    $content = $this->addTokenValidatorImport($content);
                } else {
                    $content = $this->addTokenValidatorImportAtTop($content);
                }
                
                // 替換 validateToken 函數調用
                $content = $this->replaceValidateTokenCalls($content);
                
                // 替換 base64_decode 調用
                $content = $this->replaceBase64DecodeCalls($content);
                
                $modified = true;
            }
            
            if ($modified) {
                // 備份原文件
                $backupPath = $filePath . '.backup.' . date('Y-m-d-H-i-s');
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
            echo " ❌ 處理失敗: " . $e->getMessage() . "\n";
            $this->errors[] = "處理失敗 {$filePath}: " . $e->getMessage();
        }
    }
    
    /**
     * 添加 TokenValidator 引入
     */
    private function addTokenValidatorImport($content) {
        $importLine = "require_once '../../utils/TokenValidator.php';";
        
        // 檢查是否已經引入
        if (strpos($content, 'TokenValidator.php') !== false) {
            return $content;
        }
        
        // 在最後一個 require_once 後添加
        $lines = explode("\n", $content);
        $lastRequireIndex = -1;
        
        for ($i = 0; $i < count($lines); $i++) {
            if (strpos($lines[$i], 'require_once') !== false) {
                $lastRequireIndex = $i;
            }
        }
        
        if ($lastRequireIndex >= 0) {
            array_splice($lines, $lastRequireIndex + 1, 0, $importLine);
            return implode("\n", $lines);
        }
        
        return $content;
    }
    
    /**
     * 在文件頂部添加 TokenValidator 引入
     */
    private function addTokenValidatorImportAtTop($content) {
        $importLine = "require_once '../../utils/TokenValidator.php';";
        return $importLine . "\n" . $content;
    }
    
    /**
     * 替換 validateToken 函數調用
     */
    private function replaceValidateTokenCalls($content) {
        // 替換 validateToken($token) 為 TokenValidator::validateToken($token)
        $content = preg_replace(
            '/validateToken\s*\(\s*\$([^)]+)\s*\)/',
            'TokenValidator::validateToken($$1)',
            $content
        );
        
        // 替換 validateToken($m[1]) 為 TokenValidator::validateToken($m[1])
        $content = preg_replace(
            '/validateToken\s*\(\s*\$m\[1\]\s*\)/',
            'TokenValidator::validateToken($m[1])',
            $content
        );
        
        return $content;
    }
    
    /**
     * 替換 base64_decode 調用
     */
    private function replaceBase64DecodeCalls($content) {
        // 替換 base64_decode($token) 為 TokenValidator::validateToken($token)
        $content = preg_replace(
            '/base64_decode\s*\(\s*\$([^)]+)\s*\)/',
            'TokenValidator::validateToken($$1)',
            $content
        );
        
        return $content;
    }
    
    /**
     * 輸出結果
     */
    private function printResults() {
        echo "\n🎉 遷移完成！\n";
        echo "📊 統計信息:\n";
        echo "  ✅ 成功處理: " . count($this->processedFiles) . " 個文件\n";
        echo "  ❌ 錯誤數量: " . count($this->errors) . " 個\n";
        
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
        echo "  1. 檢查備份文件 (.backup.*)\n";
        echo "  2. 測試遷移後的 API\n";
        echo "  3. 確認 JWT_SECRET 已設定\n";
        echo "  4. 運行 test_jwt.php 驗證功能\n";
    }
}

// 執行遷移
if (php_sapi_name() === 'cli') {
    $migration = new JWTMigration();
    $migration->migrate();
} else {
    echo "此腳本需要在命令行中執行\n";
    echo "使用方法: php migrate_to_jwt.php\n";
}
?>
