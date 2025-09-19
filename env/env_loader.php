<?php
/**
 * 統一環境配置載入器 (已廢棄)
 * 此檔案已整合到 backend/config/env_loader.php
 * 請使用 backend/config/env_loader.php 替代
 * 
 * @deprecated 請使用 backend/config/env_loader.php
 */

// 防止類別重複宣告
if (!class_exists('EnvLoader')) {
    // 重新導向到 Backend 載入器
    require_once __DIR__ . '/../backend/config/env_loader.php';
    return;
}

// 如果類別已存在，則不重新定義
if (class_exists('EnvLoader')) {
    return;
}

class EnvLoader {
    private static $loaded = false;
    private static $env = [];
    
    /**
     * 載入環境配置
     * @param string $environment 環境名稱 (production, development, staging)
     */
    public static function load($environment = 'production') {
        if (self::$loaded) {
            return;
        }
        
        $envFile = __DIR__ . "/../env/{$environment}.env";
        
        if (!file_exists($envFile)) {
            throw new Exception("Environment file not found: {$envFile}");
        }
        
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        
        foreach ($lines as $line) {
            // 跳過註解
            if (strpos(trim($line), '#') === 0) {
                continue;
            }
            
            // 解析 KEY=VALUE
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                $key = trim($key);
                $value = trim($value);
                
                // 移除引號
                if ((substr($value, 0, 1) === '"' && substr($value, -1) === '"') ||
                    (substr($value, 0, 1) === "'" && substr($value, -1) === "'")) {
                    $value = substr($value, 1, -1);
                }
                
                self::$env[$key] = $value;
                
                // 設定到 $_ENV 和 putenv
                $_ENV[$key] = $value;
                putenv("{$key}={$value}");
            }
        }
        
        self::$loaded = true;
    }
    
    /**
     * 取得環境變數值
     * @param string $key 變數名稱
     * @param mixed $default 預設值
     * @return mixed
     */
    public static function get($key, $default = null) {
        if (!self::$loaded) {
            self::load();
        }
        
        return isset(self::$env[$key]) ? self::$env[$key] : $default;
    }
    
    /**
     * 取得所有環境變數
     * @return array
     */
    public static function all() {
        if (!self::$loaded) {
            self::load();
        }
        
        return self::$env;
    }
    
    /**
     * 檢查環境變數是否存在
     * @param string $key 變數名稱
     * @return bool
     */
    public static function has($key) {
        if (!self::$loaded) {
            self::load();
        }
        
        return isset(self::$env[$key]);
    }
}

// 自動載入生產環境配置
EnvLoader::load('production');
