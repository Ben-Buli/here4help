<?php
/**
 * MySQL 5.7.44 相容性修正 - PHP 代碼修正
 * 修正日期：2025-09-15
 * 目標版本：MySQL 5.7.44-cll-lve
 */

/**
 * JSON 處理工具類 - MySQL 5.7.44 相容版本
 */
class JsonHelper {
    
    /**
     * 安全編碼 JSON 資料
     * @param mixed $data 要編碼的資料
     * @param int $options JSON 編碼選項
     * @return string|null 編碼後的 JSON 字串，失敗時返回 null
     */
    public static function encode($data, $options = JSON_UNESCAPED_UNICODE) {
        if ($data === null) {
            return null;
        }
        
        $json = json_encode($data, $options);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log("JSON 編碼錯誤: " . json_last_error_msg());
            return null;
        }
        
        return $json;
    }
    
    /**
     * 安全解碼 JSON 資料
     * @param string $json JSON 字串
     * @param bool $assoc 是否返回關聯陣列
     * @return mixed|null 解碼後的資料，失敗時返回 null
     */
    public static function decode($json, $assoc = true) {
        if (empty($json) || $json === null) {
            return null;
        }
        
        $data = json_decode($json, $assoc);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log("JSON 解碼錯誤: " . json_last_error_msg() . " - JSON: " . substr($json, 0, 100));
            return null;
        }
        
        return $data;
    }
    
    /**
     * 檢查 JSON 字串是否有效
     * @param string $json JSON 字串
     * @return bool 是否有效
     */
    public static function isValid($json) {
        if (empty($json)) {
            return false;
        }
        
        json_decode($json);
        return json_last_error() === JSON_ERROR_NONE;
    }
}

/**
 * 資料庫 JSON 欄位處理工具
 */
class DatabaseJsonHelper {
    
    /**
     * 安全處理資料庫中的 JSON 欄位
     * @param string $jsonData 資料庫中的 JSON 字串
     * @param string $fieldName 欄位名稱（用於錯誤日誌）
     * @return array|null 解析後的陣列，失敗時返回 null
     */
    public static function safeDecode($jsonData, $fieldName = 'unknown') {
        if (empty($jsonData)) {
            return null;
        }
        
        $decoded = JsonHelper::decode($jsonData);
        
        if ($decoded === null) {
            error_log("資料庫 JSON 欄位解碼失敗: {$fieldName} - 原始資料: " . substr($jsonData, 0, 200));
        }
        
        return $decoded;
    }
    
    /**
     * 安全編碼資料到資料庫 JSON 欄位
     * @param mixed $data 要編碼的資料
     * @param string $fieldName 欄位名稱（用於錯誤日誌）
     * @return string|null 編碼後的 JSON 字串，失敗時返回 null
     */
    public static function safeEncode($data, $fieldName = 'unknown') {
        if ($data === null) {
            return null;
        }
        
        $encoded = JsonHelper::encode($data);
        
        if ($encoded === null) {
            error_log("資料庫 JSON 欄位編碼失敗: {$fieldName} - 原始資料: " . print_r($data, true));
        }
        
        return $encoded;
    }
}

/**
 * 修正後的任務應徵處理範例
 */
class TaskApplicationHandler {
    
    /**
     * 處理應徵問題答案 - MySQL 5.7.44 相容版本
     * @param array $answers 答案陣列
     * @return string|null 編碼後的 JSON 字串
     */
    public static function processAnswers($answers) {
        if (empty($answers) || !is_array($answers)) {
            return null;
        }
        
        // 清理空值答案
        $cleanAnswers = [];
        foreach ($answers as $question => $answer) {
            $question = trim((string)$question);
            $answer = trim((string)$answer);
            if (!empty($question) && !empty($answer)) {
                $cleanAnswers[$question] = $answer;
            }
        }
        
        if (empty($cleanAnswers)) {
            return null;
        }
        
        // 使用安全的 JSON 編碼
        return DatabaseJsonHelper::safeEncode($cleanAnswers, 'task_application_answers');
    }
    
    /**
     * 解析應徵問題答案 - MySQL 5.7.44 相容版本
     * @param string $answersJson JSON 字串
     * @return array|null 解析後的答案陣列
     */
    public static function parseAnswers($answersJson) {
        return DatabaseJsonHelper::safeDecode($answersJson, 'task_application_answers');
    }
}

/**
 * 修正後的 OAuth 資料處理範例
 */
class OAuthDataHandler {
    
    /**
     * 處理 OAuth 原始資料 - MySQL 5.7.44 相容版本
     * @param array $rawData OAuth 原始資料
     * @return string|null 編碼後的 JSON 字串
     */
    public static function processRawData($rawData) {
        if (empty($rawData) || !is_array($rawData)) {
            return null;
        }
        
        return DatabaseJsonHelper::safeEncode($rawData, 'oauth_raw_data');
    }
    
    /**
     * 解析 OAuth 原始資料 - MySQL 5.7.44 相容版本
     * @param string $rawDataJson JSON 字串
     * @return array|null 解析後的資料陣列
     */
    public static function parseRawData($rawDataJson) {
        return DatabaseJsonHelper::safeDecode($rawDataJson, 'oauth_raw_data');
    }
}

/**
 * 修正後的通知偏好處理範例
 */
class NotificationPreferenceHandler {
    
    /**
     * 處理通知偏好設定 - MySQL 5.7.44 相容版本
     * @param array $preferences 偏好設定陣列
     * @return string|null 編碼後的 JSON 字串
     */
    public static function processPreferences($preferences) {
        if (empty($preferences) || !is_array($preferences)) {
            return null;
        }
        
        return DatabaseJsonHelper::safeEncode($preferences, 'notification_preferences');
    }
    
    /**
     * 解析通知偏好設定 - MySQL 5.7.44 相容版本
     * @param string $preferencesJson JSON 字串
     * @return array|null 解析後的偏好設定陣列
     */
    public static function parsePreferences($preferencesJson) {
        return DatabaseJsonHelper::safeDecode($preferencesJson, 'notification_preferences');
    }
}

/**
 * 使用範例
 */
class UsageExamples {
    
    /**
     * 任務應徵處理範例
     */
    public static function taskApplicationExample() {
        // 處理應徵答案
        $answers = [
            'introduction' => '我是一個有經驗的開發者',
            'experience' => '5年 PHP 開發經驗',
            'availability' => '週末全天'
        ];
        
        $answersJson = TaskApplicationHandler::processAnswers($answers);
        
        // 儲存到資料庫
        if ($answersJson !== null) {
            // 執行 INSERT 或 UPDATE 語句
            echo "成功編碼應徵答案\n";
        } else {
            echo "應徵答案編碼失敗\n";
        }
        
        // 從資料庫讀取並解析
        $decodedAnswers = TaskApplicationHandler::parseAnswers($answersJson);
        
        if ($decodedAnswers !== null) {
            echo "成功解析應徵答案: " . print_r($decodedAnswers, true) . "\n";
        } else {
            echo "應徵答案解析失敗\n";
        }
    }
    
    /**
     * OAuth 資料處理範例
     */
    public static function oauthDataExample() {
        // 處理 OAuth 原始資料
        $rawData = [
            'id' => '123456789',
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'picture' => 'https://example.com/avatar.jpg'
        ];
        
        $rawDataJson = OAuthDataHandler::processRawData($rawData);
        
        // 儲存到資料庫
        if ($rawDataJson !== null) {
            echo "成功編碼 OAuth 資料\n";
        } else {
            echo "OAuth 資料編碼失敗\n";
        }
        
        // 從資料庫讀取並解析
        $decodedData = OAuthDataHandler::parseRawData($rawDataJson);
        
        if ($decodedData !== null) {
            echo "成功解析 OAuth 資料: " . print_r($decodedData, true) . "\n";
        } else {
            echo "OAuth 資料解析失敗\n";
        }
    }
}

// 測試範例
if (php_sapi_name() === 'cli') {
    echo "=== MySQL 5.7.44 相容性修正測試 ===\n";
    
    echo "\n1. 任務應徵處理測試:\n";
    UsageExamples::taskApplicationExample();
    
    echo "\n2. OAuth 資料處理測試:\n";
    UsageExamples::oauthDataExample();
    
    echo "\n=== 測試完成 ===\n";
}

?>
