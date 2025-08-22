<?php
/** @var array<string,string> $_ENV */
/**
 * Environment Variables Loader
 * 載入 .env 檔案並提供環境變數管理功能
 */

class EnvLoader {

    private static $loaded = false;
    private static $vars = [];
    private static $instance = null;

    /**
     * 獲取單例實例
     */
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * 私有建構函數
     */
    private function __construct() {
        // 私有建構函數，防止外部實例化
    }

    /**
     * 載入 .env 檔案
     */
    public static function load($path = null) {
        if (self::$loaded) {
            return;
        }

        if ($path === null) {
            $path = __DIR__ . '/.env';
        }

        if (!file_exists($path)) {
            // 嘗試從專案根目錄載入
            $rootPath = dirname(dirname(__DIR__)) . '/.env';
            if (file_exists($rootPath)) {
                $path = $rootPath;
            } else {
                throw new Exception(".env file not found at: $path");
            }
        }

        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        
        foreach ($lines as $line) {
            // 跳過註解行
            if (strpos(trim($line), '#') === 0) {
                continue;
            }

            // 解析 KEY=VALUE 格式
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                $key = trim($key);
                $value = trim($value);

                // 移除引號
                if (preg_match('/^(["\'])(.*)\\1$/', $value, $matches)) {
                    $value = $matches[2];
                }

                // 設置環境變數
                if (isset($_ENV[$key])) {
                    return $_ENV[$key];
                }
                putenv("$key=$value");
                self::$vars[$key] = $value;
            }
        }

        self::$loaded = true;
    }

    /**
     * 獲取環境變數
     */
    public static function get($key, $default = null) {
        self::load();
        
        // 優先從 $_ENV 獲取
        if (isset($_ENV[$key])) {
            return $_ENV[$key];
        }

        // 從 getenv() 獲取
        $value = getenv($key);
        if ($value !== false) {
            return $value;
        }

        // 從內部存儲獲取
        if (isset(self::$vars[$key])) {
            return self::$vars[$key];
        }

        return $default;
    }

    /**
     * 獲取資料庫配置
     */
    public static function getDatabaseConfig($environment = null) {
        self::load();

        if ($environment === null) {
            $environment = self::get('APP_ENV', 'development');
        }

        if ($environment === 'production') {
            return [
                'host' => self::get('PROD_DB_HOST', 'localhost'),
                'port' => self::get('PROD_DB_PORT', '3306'),
                'dbname' => self::get('PROD_DB_NAME'),
                'username' => self::get('PROD_DB_USERNAME'),
                'password' => self::get('PROD_DB_PASSWORD'),
                'charset' => self::get('DB_CHARSET', 'utf8mb4')
            ];
        } else {
            return [
                'host' => self::get('DB_HOST', 'localhost'),
                'port' => self::get('DB_PORT', '8889'),
                'dbname' => self::get('DB_NAME'),
                'username' => self::get('DB_USERNAME'),
                'password' => self::get('DB_PASSWORD'),
                'charset' => self::get('DB_CHARSET', 'utf8mb4')
            ];
        }
    }

    /**
     * 檢查是否為開發環境
     */
    public static function isDevelopment() {
        return self::get('APP_ENV', 'development') === 'development';
    }

    /**
     * 檢查是否為生產環境
     */
    public static function isProduction() {
        return self::get('APP_ENV', 'development') === 'production';
    }

    /**
     * 獲取所有載入的環境變數
     */
    public static function getAllVars() {
        self::load();
        return self::$vars;
    }
}