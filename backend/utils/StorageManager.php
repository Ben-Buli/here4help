<?php
/**
 * 儲存管理器
 * 支援本機儲存和 S3 儲存的切換
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/Logger.php';
require_once __DIR__ . '/../database/database_manager.php';

class StorageManager {
    
    const STORAGE_LOCAL = 'local';
    const STORAGE_S3 = 's3';
    
    private $config;
    private $storageType;
    
    public function __construct() {
        $this->loadConfig();
        $this->storageType = $this->config['storage_type'];
    }
    
    /**
     * 載入配置
     */
    private function loadConfig() {
        $this->config = [
            'storage_type' => $_ENV['STORAGE_TYPE'] ?? self::STORAGE_LOCAL,
            'local_path' => $_ENV['LOCAL_STORAGE_PATH'] ?? __DIR__ . '/../uploads',
            'local_url' => $_ENV['LOCAL_STORAGE_URL'] ?? '/backend/api/media/serve.php',
            
            // S3 配置
            's3_bucket' => $_ENV['S3_BUCKET'] ?? '',
            's3_region' => $_ENV['S3_REGION'] ?? 'us-east-1',
            's3_access_key' => $_ENV['S3_ACCESS_KEY'] ?? '',
            's3_secret_key' => $_ENV['S3_SECRET_KEY'] ?? '',
            's3_endpoint' => $_ENV['S3_ENDPOINT'] ?? '', // 用於 S3 相容服務
            's3_path_style' => $_ENV['S3_PATH_STYLE'] ?? false,
            
            // CDN 配置
            'cdn_url' => $_ENV['CDN_URL'] ?? '',
            
            // 清理配置
            'cleanup_enabled' => $_ENV['STORAGE_CLEANUP_ENABLED'] ?? true,
            'cleanup_days' => $_ENV['STORAGE_CLEANUP_DAYS'] ?? 30,
            'temp_cleanup_hours' => $_ENV['TEMP_CLEANUP_HOURS'] ?? 24,
        ];
    }
    
    /**
     * 儲存檔案
     */
    public function store($sourcePath, $destinationPath, $context = 'default') {
        switch ($this->storageType) {
            case self::STORAGE_S3:
                return $this->storeToS3($sourcePath, $destinationPath, $context);
            
            case self::STORAGE_LOCAL:
            default:
                return $this->storeToLocal($sourcePath, $destinationPath, $context);
        }
    }
    
    /**
     * 獲取檔案 URL
     */
    public function getUrl($filePath, $context = 'default') {
        switch ($this->storageType) {
            case self::STORAGE_S3:
                return $this->getS3Url($filePath, $context);
            
            case self::STORAGE_LOCAL:
            default:
                return $this->getLocalUrl($filePath, $context);
        }
    }
    
    /**
     * 刪除檔案
     */
    public function delete($filePath) {
        switch ($this->storageType) {
            case self::STORAGE_S3:
                return $this->deleteFromS3($filePath);
            
            case self::STORAGE_LOCAL:
            default:
                return $this->deleteFromLocal($filePath);
        }
    }
    
    /**
     * 檢查檔案是否存在
     */
    public function exists($filePath) {
        switch ($this->storageType) {
            case self::STORAGE_S3:
                return $this->existsInS3($filePath);
            
            case self::STORAGE_LOCAL:
            default:
                return $this->existsInLocal($filePath);
        }
    }
    
    /**
     * 本機儲存實作
     */
    private function storeToLocal($sourcePath, $destinationPath, $context) {
        try {
            $fullPath = $this->config['local_path'] . '/' . ltrim($destinationPath, '/');
            $directory = dirname($fullPath);
            
            // 創建目錄
            if (!is_dir($directory)) {
                if (!mkdir($directory, 0755, true)) {
                    throw new Exception("無法創建目錄: $directory");
                }
            }
            
            // 複製檔案
            if (!copy($sourcePath, $fullPath)) {
                throw new Exception("檔案複製失敗");
            }
            
            // 設定檔案權限
            chmod($fullPath, 0644);
            
            Logger::logBusiness('file_stored_local', null, [
                'source_path' => $sourcePath,
                'destination_path' => $destinationPath,
                'full_path' => $fullPath,
                'context' => $context,
                'file_size' => filesize($fullPath)
            ]);
            
            return [
                'success' => true,
                'path' => $destinationPath,
                'full_path' => $fullPath,
                'url' => $this->getLocalUrl($destinationPath, $context)
            ];
            
        } catch (Exception $e) {
            Logger::logError('Local storage failed', [
                'source_path' => $sourcePath,
                'destination_path' => $destinationPath,
                'error' => $e->getMessage()
            ], $e);
            
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }
    
    /**
     * S3 儲存實作
     */
    private function storeToS3($sourcePath, $destinationPath, $context) {
        try {
            if (!$this->validateS3Config()) {
                throw new Exception('S3 配置不完整');
            }
            
            // 準備 S3 請求
            $bucket = $this->config['s3_bucket'];
            $key = ltrim($destinationPath, '/');
            
            // 讀取檔案內容
            $fileContent = file_get_contents($sourcePath);
            if ($fileContent === false) {
                throw new Exception('無法讀取源檔案');
            }
            
            // 獲取檔案 MIME 類型
            $mimeType = $this->getMimeType($sourcePath);
            
            // 上傳到 S3
            $result = $this->uploadToS3($bucket, $key, $fileContent, $mimeType, $context);
            
            if (!$result['success']) {
                throw new Exception($result['error']);
            }
            
            Logger::logBusiness('file_stored_s3', null, [
                'source_path' => $sourcePath,
                'destination_path' => $destinationPath,
                'bucket' => $bucket,
                'key' => $key,
                'context' => $context,
                'file_size' => strlen($fileContent)
            ]);
            
            return [
                'success' => true,
                'path' => $destinationPath,
                'bucket' => $bucket,
                'key' => $key,
                'url' => $this->getS3Url($destinationPath, $context)
            ];
            
        } catch (Exception $e) {
            Logger::logError('S3 storage failed', [
                'source_path' => $sourcePath,
                'destination_path' => $destinationPath,
                'error' => $e->getMessage()
            ], $e);
            
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }
    
    /**
     * 本機檔案刪除
     */
    private function deleteFromLocal($filePath) {
        try {
            $fullPath = $this->config['local_path'] . '/' . ltrim($filePath, '/');
            
            if (file_exists($fullPath)) {
                if (unlink($fullPath)) {
                    Logger::logBusiness('file_deleted_local', null, [
                        'file_path' => $filePath,
                        'full_path' => $fullPath
                    ]);
                    return true;
                }
            }
            
            return false;
            
        } catch (Exception $e) {
            Logger::logError('Local file deletion failed', [
                'file_path' => $filePath,
                'error' => $e->getMessage()
            ], $e);
            return false;
        }
    }
    
    /**
     * S3 檔案刪除
     */
    private function deleteFromS3($filePath) {
        try {
            if (!$this->validateS3Config()) {
                throw new Exception('S3 配置不完整');
            }
            
            $bucket = $this->config['s3_bucket'];
            $key = ltrim($filePath, '/');
            
            $result = $this->deleteFromS3Bucket($bucket, $key);
            
            if ($result['success']) {
                Logger::logBusiness('file_deleted_s3', null, [
                    'file_path' => $filePath,
                    'bucket' => $bucket,
                    'key' => $key
                ]);
            }
            
            return $result['success'];
            
        } catch (Exception $e) {
            Logger::logError('S3 file deletion failed', [
                'file_path' => $filePath,
                'error' => $e->getMessage()
            ], $e);
            return false;
        }
    }
    
    /**
     * 本機檔案存在檢查
     */
    private function existsInLocal($filePath) {
        $fullPath = $this->config['local_path'] . '/' . ltrim($filePath, '/');
        return file_exists($fullPath);
    }
    
    /**
     * S3 檔案存在檢查
     */
    private function existsInS3($filePath) {
        try {
            if (!$this->validateS3Config()) {
                return false;
            }
            
            $bucket = $this->config['s3_bucket'];
            $key = ltrim($filePath, '/');
            
            return $this->checkS3ObjectExists($bucket, $key);
            
        } catch (Exception $e) {
            Logger::logError('S3 file existence check failed', [
                'file_path' => $filePath,
                'error' => $e->getMessage()
            ], $e);
            return false;
        }
    }
    
    /**
     * 獲取本機 URL
     */
    private function getLocalUrl($filePath, $context) {
        $baseUrl = $_ENV['APP_URL'] ?? 'http://localhost:8888/here4help';
        $fileName = basename($filePath);
        
        return $baseUrl . $this->config['local_url'] . "?file=" . urlencode($fileName) . "&context=" . urlencode($context);
    }
    
    /**
     * 獲取 S3 URL
     */
    private function getS3Url($filePath, $context) {
        // 如果有 CDN，使用 CDN URL
        if (!empty($this->config['cdn_url'])) {
            return rtrim($this->config['cdn_url'], '/') . '/' . ltrim($filePath, '/');
        }
        
        // 否則使用 S3 直接 URL
        $bucket = $this->config['s3_bucket'];
        $region = $this->config['s3_region'];
        $key = ltrim($filePath, '/');
        
        if (!empty($this->config['s3_endpoint'])) {
            // 自定義端點 (如 MinIO)
            return rtrim($this->config['s3_endpoint'], '/') . '/' . $bucket . '/' . $key;
        } else {
            // AWS S3
            return "https://{$bucket}.s3.{$region}.amazonaws.com/{$key}";
        }
    }
    
    /**
     * 清理過期檔案
     */
    public function cleanupExpiredFiles() {
        try {
            $cleanupDays = (int)$this->config['cleanup_days'];
            $tempCleanupHours = (int)$this->config['temp_cleanup_hours'];
            
            if (!$this->config['cleanup_enabled']) {
                Logger::logBusiness('cleanup_skipped', null, ['reason' => 'disabled']);
                return ['success' => true, 'message' => '清理功能已停用'];
            }
            
            $result = [
                'deleted_files' => 0,
                'freed_space' => 0,
                'temp_deleted' => 0,
                'errors' => []
            ];
            
            // 清理軟刪除的檔案
            $result = array_merge($result, $this->cleanupSoftDeletedFiles($cleanupDays));
            
            // 清理臨時檔案
            $result = array_merge($result, $this->cleanupTempFiles($tempCleanupHours));
            
            // 清理孤兒檔案 (資料庫中不存在但檔案系統中存在)
            $result = array_merge($result, $this->cleanupOrphanFiles());
            
            Logger::logBusiness('storage_cleanup_completed', null, $result);
            
            return [
                'success' => true,
                'result' => $result
            ];
            
        } catch (Exception $e) {
            Logger::logError('Storage cleanup failed', [], $e);
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }
    
    /**
     * 清理軟刪除的檔案
     */
    private function cleanupSoftDeletedFiles($days) {
        try {
            $db = Database::getInstance()->getConnection();
            
            // 查找需要清理的檔案
            $sql = "
                SELECT id, file_path, file_size 
                FROM media_files 
                WHERE deleted_at IS NOT NULL 
                AND deleted_at < DATE_SUB(NOW(), INTERVAL ? DAY)
                LIMIT 1000
            ";
            
            $stmt = $db->prepare($sql);
            $stmt->execute([$days]);
            $files = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            $deletedCount = 0;
            $freedSpace = 0;
            
            foreach ($files as $file) {
                // 刪除實際檔案
                if ($this->delete($file['file_path'])) {
                    $freedSpace += $file['file_size'];
                    $deletedCount++;
                    
                    // 從資料庫中永久刪除記錄
                    $deleteSql = "DELETE FROM media_files WHERE id = ?";
                    $deleteStmt = $db->prepare($deleteSql);
                    $deleteStmt->execute([$file['id']]);
                }
            }
            
            return [
                'deleted_files' => $deletedCount,
                'freed_space' => $freedSpace
            ];
            
        } catch (Exception $e) {
            Logger::logError('Soft deleted files cleanup failed', [], $e);
            return ['deleted_files' => 0, 'freed_space' => 0];
        }
    }
    
    /**
     * 清理臨時檔案
     */
    private function cleanupTempFiles($hours) {
        try {
            $tempDir = sys_get_temp_dir();
            $cutoffTime = time() - ($hours * 3600);
            $deletedCount = 0;
            
            // 清理系統臨時目錄中的上傳檔案
            $pattern = $tempDir . '/php*';
            $tempFiles = glob($pattern);
            
            foreach ($tempFiles as $file) {
                if (is_file($file) && filemtime($file) < $cutoffTime) {
                    if (unlink($file)) {
                        $deletedCount++;
                    }
                }
            }
            
            // 清理應用臨時目錄
            $appTempDir = $this->config['local_path'] . '/temp';
            if (is_dir($appTempDir)) {
                $appTempFiles = glob($appTempDir . '/*');
                
                foreach ($appTempFiles as $file) {
                    if (is_file($file) && filemtime($file) < $cutoffTime) {
                        if (unlink($file)) {
                            $deletedCount++;
                        }
                    }
                }
            }
            
            return ['temp_deleted' => $deletedCount];
            
        } catch (Exception $e) {
            Logger::logError('Temp files cleanup failed', [], $e);
            return ['temp_deleted' => 0];
        }
    }
    
    /**
     * 清理孤兒檔案
     */
    private function cleanupOrphanFiles() {
        // 這個功能比較複雜，需要遍歷檔案系統並與資料庫比對
        // 在生產環境中建議謹慎使用，可能會誤刪檔案
        
        return ['orphan_deleted' => 0];
    }
    
    /**
     * 輔助方法
     */
    private function validateS3Config() {
        return !empty($this->config['s3_bucket']) && 
               !empty($this->config['s3_access_key']) && 
               !empty($this->config['s3_secret_key']);
    }
    
    private function getMimeType($filePath) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $filePath);
        finfo_close($finfo);
        return $mimeType ?: 'application/octet-stream';
    }
    
    /**
     * 簡化的 S3 操作 (實際專案中建議使用 AWS SDK)
     */
    private function uploadToS3($bucket, $key, $content, $mimeType, $context) {
        // 這裡是簡化的實作，實際應使用 AWS SDK 或相容的 S3 客戶端
        // 由於沒有 AWS SDK，這裡返回模擬結果
        
        return [
            'success' => false,
            'error' => 'S3 SDK 未安裝，請使用本機儲存或安裝 AWS SDK'
        ];
    }
    
    private function deleteFromS3Bucket($bucket, $key) {
        // 簡化的實作
        return [
            'success' => false,
            'error' => 'S3 SDK 未安裝'
        ];
    }
    
    private function checkS3ObjectExists($bucket, $key) {
        // 簡化的實作
        return false;
    }
    
    /**
     * 獲取儲存統計
     */
    public function getStorageStats() {
        try {
            $stats = [
                'storage_type' => $this->storageType,
                'total_files' => 0,
                'total_size' => 0,
                'by_context' => []
            ];
            
            $db = Database::getInstance()->getConnection();
            
            // 總體統計
            $sql = "
                SELECT 
                    COUNT(*) as total_files,
                    SUM(file_size) as total_size
                FROM media_files 
                WHERE deleted_at IS NULL
            ";
            
            $stmt = $db->prepare($sql);
            $stmt->execute();
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $stats['total_files'] = (int)$result['total_files'];
            $stats['total_size'] = (int)$result['total_size'];
            
            // 按情境統計
            $contextSql = "
                SELECT 
                    context,
                    COUNT(*) as file_count,
                    SUM(file_size) as total_size,
                    AVG(file_size) as avg_size
                FROM media_files 
                WHERE deleted_at IS NULL
                GROUP BY context
            ";
            
            $contextStmt = $db->prepare($contextSql);
            $contextStmt->execute();
            $contextResults = $contextStmt->fetchAll(PDO::FETCH_ASSOC);
            
            foreach ($contextResults as $row) {
                $stats['by_context'][$row['context']] = [
                    'file_count' => (int)$row['file_count'],
                    'total_size' => (int)$row['total_size'],
                    'avg_size' => (float)$row['avg_size']
                ];
            }
            
            return $stats;
            
        } catch (Exception $e) {
            Logger::logError('Failed to get storage stats', [], $e);
            return null;
        }
    }
}
