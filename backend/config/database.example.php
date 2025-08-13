<?php
/**
 * 資料庫連線配置
 * 使用環境變數管理敏感資訊
 */

require_once __DIR__ . '/env_loader.php';

class Database {
    private static $instance = null;
    private $connection;
    
    // 資料庫配置陣列
    private $config = [
        'development' => [
            'host' => 'localhost',
            'port' => '8889',
            'dbname' => 'here4help',
            'username' => 'root',
            'password' => 'root',
            'charset' => 'utf8mb4'
        ],
        'production' => [
            'host' => 'localhost',
            'port' => '3306',
            'dbname' => 'here4help_prod',
            'username' => 'prod_user',
            'password' => 'prod_password',
            'charset' => 'utf8mb4'
        ]
    ];
    
    private function __construct() {
        $this->connect();
    }
    
    private function connect() {
        try {
            // 判斷環境（可以透過環境變數或域名判斷）
            $environment = $this->getEnvironment();
            
            // 嘗試使用環境變數，如果失敗則使用預設配置
            if (class_exists('EnvLoader')) {
                try {
                    // 載入環境變數
                    EnvLoader::load();
                    $config = EnvLoader::getDatabaseConfig();
                    
                    // 驗證必要配置
                    if (!empty($config['dbname']) && !empty($config['username'])) {
                        // 使用環境變數配置
                        if (EnvLoader::isDevelopment() && file_exists('/Applications/MAMP/tmp/mysql/mysql.sock')) {
                            $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname={$config['dbname']};charset={$config['charset']}";
                        } else {
                            $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['dbname']};charset={$config['charset']}";
                        }
                        
                        $this->connection = new PDO($dsn, $config['username'], $config['password'], [
                            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                            PDO::ATTR_EMULATE_PREPARES => false,
                        ]);
                        return; // 成功連接，直接返回
                    }
                } catch (Exception $e) {
                    error_log("Failed to use environment config: " . $e->getMessage());
                }
            }
            
            // 環境變數配置失敗，使用預設配置
            $config = $this->config[$environment];
            
            // 對於 MAMP 開發環境，使用 socket 連接
            if ($environment === 'development' && file_exists('/Applications/MAMP/tmp/mysql/mysql.sock')) {
                $dsn = "mysql:unix_socket=/Applications/MAMP/tmp/mysql/mysql.sock;dbname={$config['dbname']};charset={$config['charset']}";
            } else {
                $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['dbname']};charset={$config['charset']}";
            }
            
            $this->connection = new PDO($dsn, $config['username'], $config['password'], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]);
            
        } catch (PDOException $e) {
            throw new Exception("Database connection failed: " . $e->getMessage());
        }
    }
    
    private function getEnvironment() {
        // 可以透過多種方式判斷環境
        if (isset($_SERVER['HTTP_HOST'])) {
            if ($_SERVER['HTTP_HOST'] === 'localhost:8888' || $_SERVER['HTTP_HOST'] === '127.0.0.1:8888') {
                return 'development';
            }
        }
        
        // 檢查環境變數
        if (isset($_ENV['APP_ENV'])) {
            return $_ENV['APP_ENV'];
        }
        
        // 預設為開發環境
        return 'development';
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    public function getConnection() {
        return $this->connection;
    }
    
    public function query($sql, $params = []) {
        try {
            $stmt = $this->connection->prepare($sql);
            $stmt->execute($params);
            return $stmt;
        } catch (PDOException $e) {
            throw new Exception("Query failed: " . $e->getMessage());
        }
    }
    
    public function fetchAll($sql, $params = []) {
        return $this->query($sql, $params)->fetchAll();
    }
    
    public function fetch($sql, $params = []) {
        return $this->query($sql, $params)->fetch();
    }
    
    public function lastInsertId() {
        return $this->connection->lastInsertId();
    }
    
    public function beginTransaction() {
        return $this->connection->beginTransaction();
    }
    
    public function commit() {
        return $this->connection->commit();
    }
    
    public function rollback() {
        return $this->connection->rollback();
    }
}