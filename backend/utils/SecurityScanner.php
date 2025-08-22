<?php
/**
 * 安全掃描器
 * 檔案掃毒和惡意內容檢測
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/Logger.php';

class SecurityScanner {
    
    const SCAN_STATUS_PENDING = 'pending';
    const SCAN_STATUS_CLEAN = 'clean';
    const SCAN_STATUS_INFECTED = 'infected';
    const SCAN_STATUS_ERROR = 'error';
    const SCAN_STATUS_SUSPICIOUS = 'suspicious';
    
    private $config;
    private $scanners;
    
    public function __construct() {
        $this->loadConfig();
        $this->initializeScanners();
    }
    
    /**
     * 載入配置
     */
    private function loadConfig() {
        $this->config = [
            'enabled' => $_ENV['SECURITY_SCAN_ENABLED'] ?? true,
            'async_scan' => $_ENV['ASYNC_SCAN_ENABLED'] ?? false,
            'quarantine_path' => $_ENV['QUARANTINE_PATH'] ?? __DIR__ . '/../quarantine',
            
            // ClamAV 配置
            'clamav_enabled' => $_ENV['CLAMAV_ENABLED'] ?? false,
            'clamav_socket' => $_ENV['CLAMAV_SOCKET'] ?? '/var/run/clamav/clamd.ctl',
            'clamav_host' => $_ENV['CLAMAV_HOST'] ?? 'localhost',
            'clamav_port' => $_ENV['CLAMAV_PORT'] ?? 3310,
            
            // 內建掃描配置
            'builtin_scan' => $_ENV['BUILTIN_SCAN_ENABLED'] ?? true,
            'max_scan_size' => $_ENV['MAX_SCAN_SIZE'] ?? 50 * 1024 * 1024, // 50MB
            'scan_timeout' => $_ENV['SCAN_TIMEOUT'] ?? 30, // 30秒
            
            // 威脅情報配置
            'threat_db_enabled' => $_ENV['THREAT_DB_ENABLED'] ?? true,
            'hash_check_enabled' => $_ENV['HASH_CHECK_ENABLED'] ?? true,
        ];
    }
    
    /**
     * 初始化掃描器
     */
    private function initializeScanners() {
        $this->scanners = [];
        
        // 內建掃描器
        if ($this->config['builtin_scan']) {
            $this->scanners[] = 'builtin';
        }
        
        // ClamAV 掃描器
        if ($this->config['clamav_enabled']) {
            if ($this->testClamAVConnection()) {
                $this->scanners[] = 'clamav';
            } else {
                Logger::logError('ClamAV connection failed', [
                    'host' => $this->config['clamav_host'],
                    'port' => $this->config['clamav_port']
                ]);
            }
        }
        
        Logger::logBusiness('security_scanner_initialized', null, [
            'enabled_scanners' => $this->scanners,
            'config' => array_filter($this->config, function($key) {
                return !in_array($key, ['clamav_socket']); // 排除敏感配置
            }, ARRAY_FILTER_USE_KEY)
        ]);
    }
    
    /**
     * 掃描檔案
     */
    public function scanFile($filePath, $context = 'upload') {
        if (!$this->config['enabled']) {
            return [
                'status' => self::SCAN_STATUS_CLEAN,
                'message' => '掃描功能已停用',
                'details' => []
            ];
        }
        
        $startTime = microtime(true);
        
        try {
            // 基本檢查
            if (!file_exists($filePath)) {
                throw new Exception('檔案不存在');
            }
            
            $fileSize = filesize($filePath);
            if ($fileSize > $this->config['max_scan_size']) {
                return [
                    'status' => self::SCAN_STATUS_ERROR,
                    'message' => '檔案過大，無法掃描',
                    'details' => ['file_size' => $fileSize]
                ];
            }
            
            $scanResults = [];
            $overallStatus = self::SCAN_STATUS_CLEAN;
            
            // 執行各種掃描
            foreach ($this->scanners as $scanner) {
                $result = $this->runScanner($scanner, $filePath, $context);
                $scanResults[$scanner] = $result;
                
                // 更新整體狀態
                if ($result['status'] === self::SCAN_STATUS_INFECTED) {
                    $overallStatus = self::SCAN_STATUS_INFECTED;
                    break; // 發現威脅立即停止
                } elseif ($result['status'] === self::SCAN_STATUS_SUSPICIOUS && $overallStatus === self::SCAN_STATUS_CLEAN) {
                    $overallStatus = self::SCAN_STATUS_SUSPICIOUS;
                }
            }
            
            $duration = round(microtime(true) - $startTime, 3);
            
            // 處理掃描結果
            $finalResult = [
                'status' => $overallStatus,
                'message' => $this->getStatusMessage($overallStatus),
                'details' => [
                    'scanners_used' => $this->scanners,
                    'scan_results' => $scanResults,
                    'scan_duration' => $duration,
                    'file_size' => $fileSize,
                    'file_hash' => hash_file('sha256', $filePath)
                ]
            ];
            
            // 記錄掃描結果
            Logger::logBusiness('file_security_scan', null, [
                'file_path' => basename($filePath),
                'context' => $context,
                'status' => $overallStatus,
                'duration' => $duration,
                'scanners_count' => count($this->scanners)
            ]);
            
            // 如果發現威脅，進行隔離
            if ($overallStatus === self::SCAN_STATUS_INFECTED) {
                $this->quarantineFile($filePath, $finalResult);
            }
            
            return $finalResult;
            
        } catch (Exception $e) {
            Logger::logError('Security scan failed', [
                'file_path' => $filePath,
                'context' => $context,
                'error' => $e->getMessage()
            ], $e);
            
            return [
                'status' => self::SCAN_STATUS_ERROR,
                'message' => '掃描過程發生錯誤: ' . $e->getMessage(),
                'details' => []
            ];
        }
    }
    
    /**
     * 執行特定掃描器
     */
    private function runScanner($scanner, $filePath, $context) {
        switch ($scanner) {
            case 'builtin':
                return $this->runBuiltinScan($filePath, $context);
            
            case 'clamav':
                return $this->runClamAVScan($filePath, $context);
            
            default:
                return [
                    'status' => self::SCAN_STATUS_ERROR,
                    'message' => "未知的掃描器: $scanner"
                ];
        }
    }
    
    /**
     * 內建掃描器
     */
    private function runBuiltinScan($filePath, $context) {
        try {
            $threats = [];
            
            // 1. 檔案頭部檢查
            $headerCheck = $this->checkFileHeader($filePath);
            if (!$headerCheck['valid']) {
                $threats[] = $headerCheck['threat'];
            }
            
            // 2. 惡意內容模式匹配
            $contentCheck = $this->scanFileContent($filePath);
            if ($contentCheck['threats_found'] > 0) {
                $threats = array_merge($threats, $contentCheck['threats']);
            }
            
            // 3. 檔案名稱檢查
            $nameCheck = $this->checkFileName(basename($filePath));
            if (!$nameCheck['safe']) {
                $threats[] = $nameCheck['threat'];
            }
            
            // 4. 檔案雜湊檢查 (已知威脅資料庫)
            if ($this->config['hash_check_enabled']) {
                $hashCheck = $this->checkFileHash($filePath);
                if ($hashCheck['is_threat']) {
                    $threats[] = $hashCheck['threat'];
                }
            }
            
            // 判斷結果
            if (!empty($threats)) {
                $status = $this->containsHighRiskThreats($threats) ? 
                         self::SCAN_STATUS_INFECTED : 
                         self::SCAN_STATUS_SUSPICIOUS;
            } else {
                $status = self::SCAN_STATUS_CLEAN;
            }
            
            return [
                'status' => $status,
                'message' => $this->getBuiltinScanMessage($status, count($threats)),
                'threats' => $threats,
                'checks_performed' => ['header', 'content', 'filename', 'hash']
            ];
            
        } catch (Exception $e) {
            return [
                'status' => self::SCAN_STATUS_ERROR,
                'message' => '內建掃描失敗: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * ClamAV 掃描器
     */
    private function runClamAVScan($filePath, $context) {
        try {
            $result = $this->executeClamAVScan($filePath);
            
            if ($result['infected']) {
                return [
                    'status' => self::SCAN_STATUS_INFECTED,
                    'message' => 'ClamAV 檢測到威脅: ' . $result['virus_name'],
                    'virus_name' => $result['virus_name']
                ];
            } else {
                return [
                    'status' => self::SCAN_STATUS_CLEAN,
                    'message' => 'ClamAV 掃描通過'
                ];
            }
            
        } catch (Exception $e) {
            return [
                'status' => self::SCAN_STATUS_ERROR,
                'message' => 'ClamAV 掃描失敗: ' . $e->getMessage()
            ];
        }
    }
    
    /**
     * 檢查檔案頭部
     */
    private function checkFileHeader($filePath) {
        $handle = fopen($filePath, 'rb');
        if (!$handle) {
            return ['valid' => false, 'threat' => 'unable_to_read_file'];
        }
        
        $header = fread($handle, 512); // 讀取前 512 bytes
        fclose($handle);
        
        // 檢查可疑的檔案頭部
        $suspiciousHeaders = [
            'MZ' => 'executable_file', // Windows PE
            "\x7fELF" => 'elf_executable', // Linux ELF
            "\xca\xfe\xba\xbe" => 'java_class', // Java class
            "PK\x03\x04" => 'zip_archive', // ZIP (可能包含可執行檔)
        ];
        
        foreach ($suspiciousHeaders as $signature => $threat) {
            if (strpos($header, $signature) === 0) {
                // 對於某些格式，需要進一步檢查
                if ($threat === 'zip_archive') {
                    // ZIP 檔案需要檢查內容
                    return $this->checkZipContent($filePath);
                } else {
                    return ['valid' => false, 'threat' => $threat];
                }
            }
        }
        
        return ['valid' => true];
    }
    
    /**
     * 掃描檔案內容
     */
    private function scanFileContent($filePath) {
        $content = file_get_contents($filePath, false, null, 0, 1024 * 1024); // 讀取前 1MB
        $threats = [];
        
        // 惡意模式列表
        $maliciousPatterns = [
            // 腳本注入
            '/<script[^>]*>.*?<\/script>/is' => 'script_injection',
            '/javascript\s*:/i' => 'javascript_protocol',
            '/vbscript\s*:/i' => 'vbscript_protocol',
            
            // PHP 後門
            '/eval\s*\(/i' => 'php_eval',
            '/base64_decode\s*\(/i' => 'base64_decode',
            '/system\s*\(/i' => 'system_call',
            '/exec\s*\(/i' => 'exec_call',
            '/shell_exec\s*\(/i' => 'shell_exec',
            
            // SQL 注入
            '/union\s+select/i' => 'sql_injection',
            '/drop\s+table/i' => 'sql_drop',
            
            // XSS 攻擊
            '/on\w+\s*=/i' => 'event_handler',
            '/<iframe[^>]*>/i' => 'iframe_tag',
            '/<object[^>]*>/i' => 'object_tag',
            '/<embed[^>]*>/i' => 'embed_tag',
            
            // 可疑字串
            '/\x00/' => 'null_byte',
            '/\.\.\//' => 'path_traversal',
        ];
        
        foreach ($maliciousPatterns as $pattern => $threat) {
            if (preg_match($pattern, $content)) {
                $threats[] = $threat;
            }
        }
        
        return [
            'threats_found' => count($threats),
            'threats' => $threats
        ];
    }
    
    /**
     * 檢查檔案名稱
     */
    private function checkFileName($fileName) {
        // 危險的副檔名
        $dangerousExtensions = [
            'exe', 'bat', 'cmd', 'com', 'pif', 'scr', 'vbs', 'js', 'jar',
            'php', 'asp', 'jsp', 'pl', 'py', 'rb', 'sh', 'ps1'
        ];
        
        $extension = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        
        if (in_array($extension, $dangerousExtensions)) {
            return [
                'safe' => false,
                'threat' => 'dangerous_extension_' . $extension
            ];
        }
        
        // 檢查雙重副檔名
        if (preg_match('/\.(jpg|png|gif|pdf)\.(php|asp|jsp)$/i', $fileName)) {
            return [
                'safe' => false,
                'threat' => 'double_extension'
            ];
        }
        
        return ['safe' => true];
    }
    
    /**
     * 檢查檔案雜湊
     */
    private function checkFileHash($filePath) {
        $hash = hash_file('sha256', $filePath);
        
        // 這裡應該查詢威脅情報資料庫
        // 簡化實作：檢查已知的惡意檔案雜湊
        $knownThreats = $this->getKnownThreatHashes();
        
        if (in_array($hash, $knownThreats)) {
            return [
                'is_threat' => true,
                'threat' => 'known_malware_hash'
            ];
        }
        
        return ['is_threat' => false];
    }
    
    /**
     * 檢查 ZIP 檔案內容
     */
    private function checkZipContent($filePath) {
        // 簡化實作：檢查 ZIP 檔案是否包含可執行檔
        try {
            $zip = new ZipArchive();
            if ($zip->open($filePath) === TRUE) {
                for ($i = 0; $i < $zip->numFiles; $i++) {
                    $entry = $zip->getNameIndex($i);
                    $extension = strtolower(pathinfo($entry, PATHINFO_EXTENSION));
                    
                    if (in_array($extension, ['exe', 'bat', 'cmd', 'scr'])) {
                        $zip->close();
                        return ['valid' => false, 'threat' => 'zip_contains_executable'];
                    }
                }
                $zip->close();
            }
        } catch (Exception $e) {
            // ZIP 檔案可能損壞或不是有效的 ZIP
            return ['valid' => false, 'threat' => 'invalid_zip'];
        }
        
        return ['valid' => true];
    }
    
    /**
     * 隔離檔案
     */
    private function quarantineFile($filePath, $scanResult) {
        try {
            $quarantineDir = $this->config['quarantine_path'];
            
            if (!is_dir($quarantineDir)) {
                mkdir($quarantineDir, 0700, true);
            }
            
            $quarantineFile = $quarantineDir . '/' . basename($filePath) . '_' . time() . '.quarantine';
            
            if (rename($filePath, $quarantineFile)) {
                // 創建隔離資訊檔案
                $infoFile = $quarantineFile . '.info';
                $info = [
                    'original_path' => $filePath,
                    'quarantine_time' => date('Y-m-d H:i:s'),
                    'scan_result' => $scanResult,
                    'file_hash' => hash_file('sha256', $quarantineFile)
                ];
                
                file_put_contents($infoFile, json_encode($info, JSON_PRETTY_PRINT));
                
                Logger::logBusiness('file_quarantined', null, [
                    'original_path' => $filePath,
                    'quarantine_path' => $quarantineFile,
                    'threats' => $scanResult['details']['scan_results'] ?? []
                ]);
                
                return true;
            }
            
            return false;
            
        } catch (Exception $e) {
            Logger::logError('File quarantine failed', [
                'file_path' => $filePath,
                'error' => $e->getMessage()
            ], $e);
            return false;
        }
    }
    
    /**
     * 輔助方法
     */
    private function testClamAVConnection() {
        // 簡化的連接測試
        try {
            if (!empty($this->config['clamav_socket']) && file_exists($this->config['clamav_socket'])) {
                return true;
            }
            
            $connection = @fsockopen($this->config['clamav_host'], $this->config['clamav_port'], $errno, $errstr, 5);
            if ($connection) {
                fclose($connection);
                return true;
            }
            
            return false;
        } catch (Exception $e) {
            return false;
        }
    }
    
    private function executeClamAVScan($filePath) {
        // 簡化的 ClamAV 掃描實作
        // 實際環境中應使用 ClamAV 的 PHP 擴展或命令行工具
        
        return [
            'infected' => false,
            'virus_name' => null
        ];
    }
    
    private function containsHighRiskThreats($threats) {
        $highRiskThreats = [
            'executable_file', 'elf_executable', 'php_eval', 'system_call',
            'exec_call', 'shell_exec', 'known_malware_hash'
        ];
        
        foreach ($threats as $threat) {
            if (in_array($threat, $highRiskThreats)) {
                return true;
            }
        }
        
        return false;
    }
    
    private function getKnownThreatHashes() {
        // 這裡應該從威脅情報資料庫載入
        // 簡化實作：返回空陣列
        return [];
    }
    
    private function getStatusMessage($status) {
        switch ($status) {
            case self::SCAN_STATUS_CLEAN:
                return '檔案安全，未發現威脅';
            case self::SCAN_STATUS_INFECTED:
                return '檔案包含惡意內容，已被阻止';
            case self::SCAN_STATUS_SUSPICIOUS:
                return '檔案包含可疑內容，建議謹慎處理';
            case self::SCAN_STATUS_ERROR:
                return '掃描過程發生錯誤';
            default:
                return '未知狀態';
        }
    }
    
    private function getBuiltinScanMessage($status, $threatCount) {
        switch ($status) {
            case self::SCAN_STATUS_CLEAN:
                return '內建掃描通過，未發現威脅';
            case self::SCAN_STATUS_INFECTED:
                return "內建掃描發現 {$threatCount} 個高風險威脅";
            case self::SCAN_STATUS_SUSPICIOUS:
                return "內建掃描發現 {$threatCount} 個可疑項目";
            default:
                return '內建掃描完成';
        }
    }
    
    /**
     * 獲取掃描統計
     */
    public function getScanStats($days = 7) {
        try {
            $db = Database::getInstance()->getConnection();
            
            $sql = "
                SELECT 
                    scan_status,
                    COUNT(*) as count,
                    AVG(file_size) as avg_size
                FROM media_files 
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
                GROUP BY scan_status
            ";
            
            $stmt = $db->prepare($sql);
            $stmt->execute([$days]);
            $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            $stats = [
                'period_days' => $days,
                'total_scans' => 0,
                'by_status' => []
            ];
            
            foreach ($results as $row) {
                $stats['total_scans'] += $row['count'];
                $stats['by_status'][$row['scan_status']] = [
                    'count' => (int)$row['count'],
                    'avg_size' => (float)$row['avg_size']
                ];
            }
            
            return $stats;
            
        } catch (Exception $e) {
            Logger::logError('Failed to get scan stats', [], $e);
            return null;
        }
    }
}
