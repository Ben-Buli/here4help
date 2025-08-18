<?php
/**
 * 資料庫連線配置
 * 使用環境變數管理敏感資訊
 */

// Suppress Intelephense PDO type errors
/** @phpstan-ignore-next-line */
/** @psalm-suppress UndefinedClass */

require_once __DIR__ . '/env_loader.php';

class Database {
    private static $instance = null;
    /** @var PDO|null */
    private $connection;
    
    private function __construct() {
        $this->connect();
    }
    
    private function connect() {
        try {
            // 檢查 PDO 擴展是否可用
            if (!extension_loaded('pdo_mysql')) {
                throw new Exception("PDO MySQL extension is not loaded");
            }
            
            // 載入環境變數
            EnvLoader::load();
            
            // 從環境變數獲取資料庫配置
            $config = EnvLoader::getDatabaseConfig();
            
            // 驗證必要配置
            if (empty($config['dbname']) || empty($config['username'])) {
                throw new Exception("Database configuration is incomplete. Please check your .env file.");
            }
            
            // 對於 MAMP 開發環境，使用 socket 連接
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
            
        } catch (PDOException $e) {
            throw new Exception("Database connection failed: " . $e->getMessage());
        }
    }
    
    public static function getInstance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /** @return PDO|null */
    public function getConnection() {
        return $this->connection;
    }
    
    /**
     * @param string $sql
     * @param array $params
     * @return PDOStatement
     * @throws Exception
     */
    public function query($sql, $params = []) {
        try {
            $stmt = $this->connection->prepare($sql);
            $stmt->execute($params);
            return $stmt;
        } catch (PDOException $e) {
            throw new Exception("Query failed: " . $e->getMessage());
        }
    }
    
    /**
     * @param string $sql
     * @param array $params
     * @return array
     * @throws Exception
     */
    public function fetchAll($sql, $params = []) {
        return $this->query($sql, $params)->fetchAll();
    }
    
    /**
     * @param string $sql
     * @param array $params
     * @return array|false
     * @throws Exception
     */
    public function fetch($sql, $params = []) {
        return $this->query($sql, $params)->fetch();
    }
    
    /** @return string */
    public function lastInsertId() {
        return $this->connection->lastInsertId();
    }
    
    /** @return bool */
    public function beginTransaction() {
        return $this->connection->beginTransaction();
    }
    
    /** @return bool */
    public function commit() {
        return $this->connection->commit();
    }
    
    /** @return bool */
    public function rollback() {
        return $this->connection->rollback();
    }
} 