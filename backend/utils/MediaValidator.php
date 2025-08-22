<?php
/**
 * 媒體檔案驗證器
 * 檔案大小、類型白名單驗證與壓縮策略
 */

require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/Logger.php';

class MediaValidator {
    
    // 允許的檔案類型 (MIME types)
    const ALLOWED_IMAGE_TYPES = [
        'image/jpeg',
        'image/jpg', 
        'image/png',
        'image/gif',
        'image/webp'
    ];
    
    const ALLOWED_DOCUMENT_TYPES = [
        'application/pdf',
        'text/plain',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ];
    
    // 檔案大小限制 (bytes)
    const MAX_IMAGE_SIZE = 10 * 1024 * 1024; // 10MB
    const MAX_DOCUMENT_SIZE = 20 * 1024 * 1024; // 20MB
    const MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB
    
    // 圖片尺寸限制
    const MAX_IMAGE_WIDTH = 4096;
    const MAX_IMAGE_HEIGHT = 4096;
    const MAX_AVATAR_WIDTH = 1024;
    const MAX_AVATAR_HEIGHT = 1024;
    
    // 壓縮品質
    const JPEG_QUALITY = 85;
    const PNG_COMPRESSION = 6;
    const WEBP_QUALITY = 80;
    
    private $config;
    
    public function __construct() {
        $this->loadConfig();
    }
    
    /**
     * 載入配置
     */
    private function loadConfig() {
        $this->config = [
            'max_image_size' => $_ENV['MAX_IMAGE_SIZE'] ?? self::MAX_IMAGE_SIZE,
            'max_document_size' => $_ENV['MAX_DOCUMENT_SIZE'] ?? self::MAX_DOCUMENT_SIZE,
            'max_avatar_size' => $_ENV['MAX_AVATAR_SIZE'] ?? self::MAX_AVATAR_SIZE,
            'jpeg_quality' => $_ENV['JPEG_QUALITY'] ?? self::JPEG_QUALITY,
            'enable_compression' => $_ENV['ENABLE_MEDIA_COMPRESSION'] ?? true,
            'enable_watermark' => $_ENV['ENABLE_WATERMARK'] ?? false,
        ];
    }
    
    /**
     * 驗證上傳檔案
     */
    public function validateUpload($file, $context = 'chat') {
        $result = [
            'valid' => false,
            'errors' => [],
            'file_info' => [],
            'should_compress' => false
        ];
        
        try {
            // 基本檔案檢查
            if (!$this->validateBasicFile($file, $result)) {
                return $result;
            }
            
            // 檔案類型檢查
            if (!$this->validateFileType($file, $result, $context)) {
                return $result;
            }
            
            // 檔案大小檢查
            if (!$this->validateFileSize($file, $result, $context)) {
                return $result;
            }
            
            // 圖片特殊檢查
            if ($this->isImage($file['type'])) {
                if (!$this->validateImageProperties($file, $result, $context)) {
                    return $result;
                }
                
                // 判斷是否需要壓縮
                $result['should_compress'] = $this->shouldCompress($file, $context);
            }
            
            // 安全性檢查
            if (!$this->validateSecurity($file, $result)) {
                return $result;
            }
            
            $result['valid'] = true;
            $result['file_info'] = $this->getFileInfo($file);
            
            Logger::logBusiness('media_validation_success', null, [
                'file_name' => $file['name'],
                'file_size' => $file['size'],
                'file_type' => $file['type'],
                'context' => $context
            ]);
            
        } catch (Exception $e) {
            $result['errors'][] = '檔案驗證過程發生錯誤';
            Logger::logError('Media validation failed', [
                'file_name' => $file['name'] ?? 'unknown',
                'error' => $e->getMessage()
            ], $e);
        }
        
        return $result;
    }
    
    /**
     * 基本檔案檢查
     */
    private function validateBasicFile($file, &$result) {
        if (!isset($file['tmp_name']) || !is_uploaded_file($file['tmp_name'])) {
            $result['errors'][] = '無效的上傳檔案';
            return false;
        }
        
        if ($file['error'] !== UPLOAD_ERR_OK) {
            $result['errors'][] = $this->getUploadErrorMessage($file['error']);
            return false;
        }
        
        if (empty($file['name'])) {
            $result['errors'][] = '檔案名稱不能為空';
            return false;
        }
        
        // 檢查檔案名稱安全性
        if (!$this->isValidFileName($file['name'])) {
            $result['errors'][] = '檔案名稱包含非法字元';
            return false;
        }
        
        return true;
    }
    
    /**
     * 檔案類型檢查
     */
    private function validateFileType($file, &$result, $context) {
        $mimeType = $this->getMimeType($file['tmp_name']);
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        
        // 檢查 MIME 類型
        $allowedTypes = [];
        switch ($context) {
            case 'avatar':
            case 'chat':
            case 'dispute':
                $allowedTypes = self::ALLOWED_IMAGE_TYPES;
                break;
            case 'document':
            case 'verification':
                $allowedTypes = array_merge(self::ALLOWED_IMAGE_TYPES, self::ALLOWED_DOCUMENT_TYPES);
                break;
            default:
                $allowedTypes = self::ALLOWED_IMAGE_TYPES;
        }
        
        if (!in_array($mimeType, $allowedTypes)) {
            $result['errors'][] = "不支援的檔案類型: $mimeType";
            return false;
        }
        
        // 檢查副檔名與 MIME 類型是否匹配
        if (!$this->validateMimeExtensionMatch($mimeType, $extension)) {
            $result['errors'][] = '檔案類型與副檔名不匹配';
            return false;
        }
        
        return true;
    }
    
    /**
     * 檔案大小檢查
     */
    private function validateFileSize($file, &$result, $context) {
        $maxSize = $this->getMaxFileSize($context);
        
        if ($file['size'] > $maxSize) {
            $result['errors'][] = "檔案大小超過限制 (" . $this->formatBytes($maxSize) . ")";
            return false;
        }
        
        if ($file['size'] === 0) {
            $result['errors'][] = '檔案大小不能為 0';
            return false;
        }
        
        return true;
    }
    
    /**
     * 圖片屬性檢查
     */
    private function validateImageProperties($file, &$result, $context) {
        $imageInfo = getimagesize($file['tmp_name']);
        
        if ($imageInfo === false) {
            $result['errors'][] = '無效的圖片檔案';
            return false;
        }
        
        list($width, $height) = $imageInfo;
        
        // 檢查圖片尺寸
        $maxWidth = $context === 'avatar' ? self::MAX_AVATAR_WIDTH : self::MAX_IMAGE_WIDTH;
        $maxHeight = $context === 'avatar' ? self::MAX_AVATAR_HEIGHT : self::MAX_IMAGE_HEIGHT;
        
        if ($width > $maxWidth || $height > $maxHeight) {
            $result['errors'][] = "圖片尺寸超過限制 ({$maxWidth}x{$maxHeight})";
            return false;
        }
        
        // 檢查最小尺寸
        if ($width < 10 || $height < 10) {
            $result['errors'][] = '圖片尺寸過小';
            return false;
        }
        
        // 檢查長寬比 (防止極端比例)
        $aspectRatio = max($width, $height) / min($width, $height);
        if ($aspectRatio > 20) {
            $result['errors'][] = '圖片長寬比例異常';
            return false;
        }
        
        return true;
    }
    
    /**
     * 安全性檢查
     */
    private function validateSecurity($file, &$result) {
        // 檢查檔案頭部 (Magic Number)
        if (!$this->validateFileHeader($file['tmp_name'])) {
            $result['errors'][] = '檔案格式驗證失敗';
            return false;
        }
        
        // 掃描可疑內容
        if ($this->containsSuspiciousContent($file['tmp_name'])) {
            $result['errors'][] = '檔案包含可疑內容';
            return false;
        }
        
        return true;
    }
    
    /**
     * 壓縮圖片
     */
    public function compressImage($sourcePath, $destinationPath, $context = 'chat') {
        try {
            $imageInfo = getimagesize($sourcePath);
            if (!$imageInfo) {
                throw new Exception('無法讀取圖片資訊');
            }
            
            list($width, $height, $type) = $imageInfo;
            
            // 創建圖片資源
            $sourceImage = $this->createImageResource($sourcePath, $type);
            if (!$sourceImage) {
                throw new Exception('無法創建圖片資源');
            }
            
            // 計算新尺寸
            $newDimensions = $this->calculateNewDimensions($width, $height, $context);
            
            // 創建新圖片
            $newImage = imagecreatetruecolor($newDimensions['width'], $newDimensions['height']);
            
            // 保持透明度 (PNG/GIF)
            if ($type === IMAGETYPE_PNG || $type === IMAGETYPE_GIF) {
                imagealphablending($newImage, false);
                imagesavealpha($newImage, true);
                $transparent = imagecolorallocatealpha($newImage, 255, 255, 255, 127);
                imagefill($newImage, 0, 0, $transparent);
            }
            
            // 重新採樣
            imagecopyresampled(
                $newImage, $sourceImage,
                0, 0, 0, 0,
                $newDimensions['width'], $newDimensions['height'],
                $width, $height
            );
            
            // 保存圖片
            $success = $this->saveCompressedImage($newImage, $destinationPath, $type);
            
            // 清理資源
            imagedestroy($sourceImage);
            imagedestroy($newImage);
            
            if ($success) {
                Logger::logBusiness('image_compressed', null, [
                    'original_size' => filesize($sourcePath),
                    'compressed_size' => filesize($destinationPath),
                    'original_dimensions' => "{$width}x{$height}",
                    'new_dimensions' => "{$newDimensions['width']}x{$newDimensions['height']}",
                    'context' => $context
                ]);
            }
            
            return $success;
            
        } catch (Exception $e) {
            Logger::logError('Image compression failed', [
                'source_path' => $sourcePath,
                'destination_path' => $destinationPath,
                'error' => $e->getMessage()
            ], $e);
            return false;
        }
    }
    
    /**
     * 輔助方法
     */
    private function isImage($mimeType) {
        return in_array($mimeType, self::ALLOWED_IMAGE_TYPES);
    }
    
    private function getMimeType($filePath) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $filePath);
        finfo_close($finfo);
        return $mimeType;
    }
    
    private function getMaxFileSize($context) {
        switch ($context) {
            case 'avatar':
                return $this->config['max_avatar_size'];
            case 'document':
            case 'verification':
                return $this->config['max_document_size'];
            default:
                return $this->config['max_image_size'];
        }
    }
    
    private function shouldCompress($file, $context) {
        if (!$this->config['enable_compression']) {
            return false;
        }
        
        if (!$this->isImage($file['type'])) {
            return false;
        }
        
        // 根據檔案大小決定是否壓縮
        $threshold = $context === 'avatar' ? 1024 * 1024 : 2 * 1024 * 1024; // 1MB or 2MB
        return $file['size'] > $threshold;
    }
    
    private function calculateNewDimensions($width, $height, $context) {
        $maxWidth = $context === 'avatar' ? 512 : 1920;
        $maxHeight = $context === 'avatar' ? 512 : 1920;
        
        if ($width <= $maxWidth && $height <= $maxHeight) {
            return ['width' => $width, 'height' => $height];
        }
        
        $ratio = min($maxWidth / $width, $maxHeight / $height);
        
        return [
            'width' => (int)($width * $ratio),
            'height' => (int)($height * $ratio)
        ];
    }
    
    private function createImageResource($path, $type) {
        switch ($type) {
            case IMAGETYPE_JPEG:
                return imagecreatefromjpeg($path);
            case IMAGETYPE_PNG:
                return imagecreatefrompng($path);
            case IMAGETYPE_GIF:
                return imagecreatefromgif($path);
            case IMAGETYPE_WEBP:
                return imagecreatefromwebp($path);
            default:
                return false;
        }
    }
    
    private function saveCompressedImage($image, $path, $type) {
        switch ($type) {
            case IMAGETYPE_JPEG:
                return imagejpeg($image, $path, $this->config['jpeg_quality']);
            case IMAGETYPE_PNG:
                return imagepng($image, $path, self::PNG_COMPRESSION);
            case IMAGETYPE_GIF:
                return imagegif($image, $path);
            case IMAGETYPE_WEBP:
                return imagewebp($image, $path, self::WEBP_QUALITY);
            default:
                return false;
        }
    }
    
    private function validateFileHeader($filePath) {
        $handle = fopen($filePath, 'rb');
        if (!$handle) {
            return false;
        }
        
        $header = fread($handle, 16);
        fclose($handle);
        
        // 檢查常見圖片格式的 Magic Number
        $magicNumbers = [
            'jpeg' => ["\xFF\xD8\xFF"],
            'png' => ["\x89PNG\r\n\x1A\n"],
            'gif' => ["GIF87a", "GIF89a"],
            'webp' => ["RIFF", "WEBP"],
            'pdf' => ["%PDF-"]
        ];
        
        foreach ($magicNumbers as $format => $signatures) {
            foreach ($signatures as $signature) {
                if (strpos($header, $signature) === 0) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    private function containsSuspiciousContent($filePath) {
        // 簡單的惡意內容檢測
        $content = file_get_contents($filePath, false, null, 0, 8192); // 讀取前 8KB
        
        $suspiciousPatterns = [
            '/<script/i',
            '/javascript:/i',
            '/vbscript:/i',
            '/onload=/i',
            '/onerror=/i',
            '/<iframe/i',
            '/<object/i',
            '/<embed/i'
        ];
        
        foreach ($suspiciousPatterns as $pattern) {
            if (preg_match($pattern, $content)) {
                return true;
            }
        }
        
        return false;
    }
    
    private function isValidFileName($fileName) {
        // 檢查檔案名稱是否包含危險字元
        $dangerousChars = ['..', '/', '\\', '<', '>', ':', '"', '|', '?', '*', "\0"];
        
        foreach ($dangerousChars as $char) {
            if (strpos($fileName, $char) !== false) {
                return false;
            }
        }
        
        // 檢查檔案名稱長度
        if (strlen($fileName) > 255) {
            return false;
        }
        
        return true;
    }
    
    private function validateMimeExtensionMatch($mimeType, $extension) {
        $validCombinations = [
            'image/jpeg' => ['jpg', 'jpeg'],
            'image/png' => ['png'],
            'image/gif' => ['gif'],
            'image/webp' => ['webp'],
            'application/pdf' => ['pdf'],
            'text/plain' => ['txt'],
            'application/msword' => ['doc'],
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => ['docx']
        ];
        
        if (!isset($validCombinations[$mimeType])) {
            return false;
        }
        
        return in_array($extension, $validCombinations[$mimeType]);
    }
    
    private function getUploadErrorMessage($errorCode) {
        switch ($errorCode) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                return '檔案大小超過限制';
            case UPLOAD_ERR_PARTIAL:
                return '檔案上傳不完整';
            case UPLOAD_ERR_NO_FILE:
                return '沒有選擇檔案';
            case UPLOAD_ERR_NO_TMP_DIR:
                return '臨時目錄不存在';
            case UPLOAD_ERR_CANT_WRITE:
                return '檔案寫入失敗';
            case UPLOAD_ERR_EXTENSION:
                return '檔案上傳被擴展阻止';
            default:
                return '未知上傳錯誤';
        }
    }
    
    private function getFileInfo($file) {
        $info = [
            'name' => $file['name'],
            'size' => $file['size'],
            'type' => $file['type'],
            'extension' => strtolower(pathinfo($file['name'], PATHINFO_EXTENSION))
        ];
        
        if ($this->isImage($file['type'])) {
            $imageInfo = getimagesize($file['tmp_name']);
            if ($imageInfo) {
                $info['width'] = $imageInfo[0];
                $info['height'] = $imageInfo[1];
                $info['aspect_ratio'] = round($imageInfo[0] / $imageInfo[1], 2);
            }
        }
        
        return $info;
    }
    
    public function formatBytes($bytes, $precision = 2) {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        
        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }
        
        return round($bytes, $precision) . ' ' . $units[$i];
    }
    
    /**
     * 獲取檔案類型統計
     */
    public static function getFileTypeStats() {
        return [
            'allowed_image_types' => self::ALLOWED_IMAGE_TYPES,
            'allowed_document_types' => self::ALLOWED_DOCUMENT_TYPES,
            'size_limits' => [
                'max_image_size' => self::MAX_IMAGE_SIZE,
                'max_document_size' => self::MAX_DOCUMENT_SIZE,
                'max_avatar_size' => self::MAX_AVATAR_SIZE
            ],
            'dimension_limits' => [
                'max_image_width' => self::MAX_IMAGE_WIDTH,
                'max_image_height' => self::MAX_IMAGE_HEIGHT,
                'max_avatar_width' => self::MAX_AVATAR_WIDTH,
                'max_avatar_height' => self::MAX_AVATAR_HEIGHT
            ]
        ];
    }
}
