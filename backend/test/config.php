<?php
/**
 * 測試配置管理器
 * 統一管理所有測試文件的環境配置
 */

require_once __DIR__ . '/../config/env_loader.php';

class TestConfig {
    private static $config = null;
    
    /**
     * 載入測試配置
     */
    public static function load() {
        if (self::$config !== null) {
            return self::$config;
        }
        
        // 載入環境配置
        EnvLoader::load();
        
        // 獲取測試配置
        self::$config = [
            'api_base_url' => EnvLoader::get('API_BASE_URL', 'http://localhost:8888/here4help/backend'),
            'api_prefix' => EnvLoader::get('API_PREFIX', '/here4help/backend/api'),
            'socket_url' => EnvLoader::get('SOCKET_URL', 'https://hero4help.demofhs.com/socket'),
            'image_base_url' => EnvLoader::get('IMAGE_BASE_URL', 'http://localhost:8888/here4help'),
            'app_url' => EnvLoader::get('APP_URL', 'http://localhost:8888/here4help'),
            'jwt_secret' => EnvLoader::get('JWT_SECRET', 'test-secret'),
            'db_host' => EnvLoader::get('DB_HOST', 'localhost'),
            'db_port' => EnvLoader::get('DB_PORT', '8889'),
            'db_name' => EnvLoader::get('DB_NAME', 'here4help'),
            'db_username' => EnvLoader::get('DB_USERNAME', 'root'),
            'db_password' => EnvLoader::get('DB_PASSWORD', 'root'),
        ];
        
        return self::$config;
    }
    
    /**
     * 獲取 API 基礎 URL
     */
    public static function getApiBaseUrl() {
        $config = self::load();
        return $config['api_base_url'];
    }
    
    /**
     * 獲取 API 前綴
     */
    public static function getApiPrefix() {
        $config = self::load();
        return $config['api_prefix'];
    }
    
    /**
     * 獲取完整的 API URL
     */
    public static function getApiUrl($endpoint) {
        $baseUrl = self::getApiBaseUrl();
        $prefix = self::getApiPrefix();
        
        // 確保 endpoint 以 / 開頭
        if (!$endpoint || !str_starts_with($endpoint, '/')) {
            $endpoint = '/' . $endpoint;
        }
        
        return $baseUrl . $prefix . $endpoint;
    }
    
    /**
     * 獲取 Socket URL
     */
    public static function getSocketUrl() {
        $config = self::load();
        return $config['socket_url'];
    }
    
    /**
     * 獲取圖片基礎 URL
     */
    public static function getImageBaseUrl() {
        $config = self::load();
        return $config['image_base_url'];
    }
    
    /**
     * 獲取應用 URL
     */
    public static function getAppUrl() {
        $config = self::load();
        return $config['app_url'];
    }
    
    /**
     * 獲取 JWT 密鑰
     */
    public static function getJwtSecret() {
        $config = self::load();
        return $config['jwt_secret'];
    }
    
    /**
     * 獲取資料庫配置
     */
    public static function getDatabaseConfig() {
        $config = self::load();
        return [
            'host' => $config['db_host'],
            'port' => $config['db_port'],
            'dbname' => $config['db_name'],
            'username' => $config['db_username'],
            'password' => $config['db_password'],
        ];
    }
    
    /**
     * 獲取所有配置
     */
    public static function getAll() {
        return self::load();
    }
    
    /**
     * 打印測試配置（用於調試）
     */
    public static function printConfig() {
        $config = self::load();
        echo "🧪 測試配置:\n";
        echo "  API Base URL: " . $config['api_base_url'] . "\n";
        echo "  API Prefix: " . $config['api_prefix'] . "\n";
        echo "  Socket URL: " . $config['socket_url'] . "\n";
        echo "  Image Base URL: " . $config['image_base_url'] . "\n";
        echo "  App URL: " . $config['app_url'] . "\n";
        echo "  DB Host: " . $config['db_host'] . ":" . $config['db_port'] . "\n";
        echo "  DB Name: " . $config['db_name'] . "\n";
    }
}

// 自動載入配置
TestConfig::load();
?>
