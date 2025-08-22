<?php
/**
 * API 文檔生成器
 * 基於 OpenAPI 規範生成 API 文檔
 */

class ApiDocGenerator {
    
    private $openApiSpec;
    private $baseUrl;
    
    public function __construct($openApiFile = null) {
        $openApiFile = $openApiFile ?: __DIR__ . '/../../docs/api/openapi.yaml';
        
        if (!file_exists($openApiFile)) {
            throw new Exception("OpenAPI spec file not found: $openApiFile");
        }
        
        // 簡單的 YAML 解析（僅支援基本格式）
        $this->openApiSpec = $this->parseYaml($openApiFile);
        $this->baseUrl = $this->openApiSpec['servers'][0]['url'] ?? '';
    }
    
    /**
     * 簡單的 YAML 解析器
     */
    private function parseYaml($file) {
        $content = file_get_contents($file);
        
        // 這是一個非常簡化的 YAML 解析器
        // 在生產環境中應該使用 symfony/yaml 或其他專業的 YAML 解析器
        $lines = explode("\n", $content);
        $result = [];
        $currentPath = [];
        
        foreach ($lines as $line) {
            $line = rtrim($line);
            if (empty($line) || strpos($line, '#') === 0) {
                continue;
            }
            
            $indent = strlen($line) - strlen(ltrim($line));
            $line = trim($line);
            
            if (strpos($line, ':') !== false) {
                list($key, $value) = explode(':', $line, 2);
                $key = trim($key);
                $value = trim($value);
                
                // 簡化處理，僅提取基本資訊
                if ($key === 'title') {
                    $result['info']['title'] = $value;
                } elseif ($key === 'version') {
                    $result['info']['version'] = $value;
                } elseif ($key === 'description' && $indent === 2) {
                    $result['info']['description'] = $value;
                }
            }
        }
        
        // 返回基本結構
        return [
            'info' => $result['info'] ?? [
                'title' => 'Here4Help API',
                'version' => '1.0.0',
                'description' => 'Here4Help 平台 API'
            ],
            'servers' => [
                ['url' => 'http://localhost:8888/here4help/backend/api']
            ]
        ];
    }
    
    /**
     * 生成 HTML 文檔
     */
    public function generateHtml() {
        $title = $this->openApiSpec['info']['title'] ?? 'API Documentation';
        $version = $this->openApiSpec['info']['version'] ?? '1.0.0';
        $description = $this->openApiSpec['info']['description'] ?? '';
        
        $html = <<<HTML
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem;
            border-radius: 10px;
            margin-bottom: 2rem;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5rem;
        }
        .version {
            opacity: 0.8;
            font-size: 1.1rem;
        }
        .section {
            background: white;
            padding: 2rem;
            border-radius: 10px;
            margin-bottom: 2rem;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .section h2 {
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 0.5rem;
        }
        .endpoint {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 1rem;
            margin: 1rem 0;
            border-radius: 0 5px 5px 0;
        }
        .method {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 3px;
            font-weight: bold;
            font-size: 0.8rem;
            margin-right: 0.5rem;
        }
        .method.get { background: #28a745; color: white; }
        .method.post { background: #007bff; color: white; }
        .method.put { background: #ffc107; color: black; }
        .method.delete { background: #dc3545; color: white; }
        .code {
            background: #f1f3f4;
            padding: 1rem;
            border-radius: 5px;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 0.9rem;
            overflow-x: auto;
        }
        .error-codes {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1rem;
        }
        .error-code {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            padding: 1rem;
            border-radius: 5px;
        }
        .error-code.success { background: #d4edda; border-color: #c3e6cb; }
        .error-code.error { background: #f8d7da; border-color: #f5c6cb; }
    </style>
</head>
<body>
    <div class="header">
        <h1>$title</h1>
        <div class="version">版本 $version</div>
    </div>

    <div class="section">
        <h2>📖 API 概述</h2>
        <p>$description</p>
        
        <h3>🔗 基礎 URL</h3>
        <div class="code">{$this->baseUrl}</div>
        
        <h3>🔐 認證方式</h3>
        <ul>
            <li><strong>Bearer Token (JWT)</strong>: 在 Authorization 標頭中傳遞 <code>Bearer &lt;token&gt;</code></li>
            <li><strong>API Key</strong>: 在 X-API-Key 標頭中傳遞（開發環境）</li>
        </ul>
    </div>

    <div class="section">
        <h2>📋 統一回應格式</h2>
        <p>所有 API 端點都遵循統一的回應格式：</p>
        
        <h3>✅ 成功回應</h3>
        <div class="code">{
  "success": true,
  "code": "SUCCESS",
  "message": "操作成功",
  "data": {...},
  "traceId": "68A8362D5712F07814D26",
  "timestamp": "2025-01-11T17:30:00+08:00",
  "server_time": 1641897000
}</div>

        <h3>❌ 錯誤回應</h3>
        <div class="code">{
  "success": false,
  "code": "E2001",
  "message": "未授權訪問",
  "traceId": "68A8362D5712F07814D26",
  "timestamp": "2025-01-11T17:30:00+08:00",
  "server_time": 1641897000
}</div>
    </div>

    <div class="section">
        <h2>📄 分頁格式</h2>
        
        <h3>請求參數</h3>
        <ul>
            <li><code>page</code>: 頁碼（預設: 1）</li>
            <li><code>per_page</code>: 每頁數量（預設: 20，最大: 100）</li>
        </ul>
        
        <h3>回應格式</h3>
        <div class="code">{
  "success": true,
  "code": "SUCCESS",
  "data": {
    "items": [...],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 100,
      "total_pages": 5,
      "has_next_page": true,
      "has_previous_page": false,
      "from": 1,
      "to": 20
    }
  }
}</div>
    </div>

    <div class="section">
        <h2>🔢 錯誤碼參考</h2>
        <div class="error-codes">
HTML;

        // 生成錯誤碼列表
        $errorCodes = $this->getErrorCodes();
        foreach ($errorCodes as $category => $codes) {
            $html .= "<div class=\"error-code\">";
            $html .= "<h4>" . $this->getCategoryName($category) . "</h4>";
            foreach ($codes as $code => $message) {
                $class = $code === 'SUCCESS' ? 'success' : 'error';
                $html .= "<div><code>$code</code>: $message</div>";
            }
            $html .= "</div>";
        }

        $html .= <<<HTML
        </div>
    </div>

    <div class="section">
        <h2>🚀 主要端點</h2>
        
        <div class="endpoint">
            <span class="method post">POST</span>
            <strong>/auth/login.php</strong>
            <p>用戶登入</p>
            <div class="code">curl -X POST {$this->baseUrl}/auth/login.php \\
  -H "Content-Type: application/json" \\
  -d '{"email": "user@example.com", "password": "password123"}'</div>
        </div>

        <div class="endpoint">
            <span class="method post">POST</span>
            <strong>/auth/refresh-token.php</strong>
            <p>刷新 Access Token</p>
            <div class="code">curl -X POST {$this->baseUrl}/auth/refresh-token.php \\
  -H "Content-Type: application/json" \\
  -d '{"refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."}'</div>
        </div>

        <div class="endpoint">
            <span class="method get">GET</span>
            <strong>/tasks/list.php</strong>
            <p>獲取任務列表</p>
            <div class="code">curl -X GET "{$this->baseUrl}/tasks/list.php?page=1&per_page=20" \\
  -H "Authorization: Bearer &lt;token&gt;"</div>
        </div>

        <div class="endpoint">
            <span class="method get">GET</span>
            <strong>/chat/get_rooms.php</strong>
            <p>獲取聊天室列表</p>
            <div class="code">curl -X GET "{$this->baseUrl}/chat/get_rooms.php?page=1&per_page=20" \\
  -H "Authorization: Bearer &lt;token&gt;"</div>
        </div>
    </div>

    <div class="section">
        <h2>🔍 請求追蹤</h2>
        <p>每個 API 請求都會生成唯一的 TraceId，用於問題追蹤和除錯：</p>
        <ul>
            <li><strong>請求標頭</strong>: 可在 <code>X-Trace-Id</code> 標頭中傳遞自定義 TraceId</li>
            <li><strong>回應標頭</strong>: 回應會包含 <code>X-Trace-Id</code> 標頭</li>
            <li><strong>回應內容</strong>: TraceId 也會包含在回應的 JSON 中</li>
        </ul>
        
        <div class="code"># 請求範例
curl -X GET "{$this->baseUrl}/tasks/list.php" \\
  -H "Authorization: Bearer &lt;token&gt;" \\
  -H "X-Trace-Id: CUSTOM123456789"

# 回應標頭
X-Trace-Id: CUSTOM123456789
X-Request-Id: CUSTOM123456789</div>
    </div>

    <div class="section">
        <h2>⚡ 節流限制</h2>
        <p>API 實施節流限制以防止濫用：</p>
        <ul>
            <li><strong>認證端點</strong>: 5 requests / 5 minutes</li>
            <li><strong>訊息端點</strong>: 30 requests / 1 minute</li>
            <li><strong>檢舉端點</strong>: 3 requests / 1 hour</li>
            <li><strong>一般端點</strong>: 100 requests / 1 minute</li>
        </ul>
        
        <p>節流資訊會在回應標頭中提供：</p>
        <div class="code">X-RateLimit-Remaining: 4
X-RateLimit-Reset: 1641897600
Retry-After: 300</div>
    </div>

    <footer style="text-align: center; margin-top: 3rem; padding: 2rem; color: #666;">
        <p>Generated by Here4Help API Documentation Generator</p>
        <p>Last updated: " . date('Y-m-d H:i:s') . "</p>
    </footer>
</body>
</html>
HTML;

        return $html;
    }
    
    /**
     * 獲取錯誤碼列表
     */
    private function getErrorCodes() {
        require_once __DIR__ . '/ErrorCodes.php';
        
        $codes = ErrorCodes::getAllCodes();
        $categorized = [];
        
        foreach ($codes as $code) {
            $category = ErrorCodes::getCodeCategory($code);
            $message = ErrorCodes::getMessage($code);
            $categorized[$category][$code] = $message;
        }
        
        return $categorized;
    }
    
    /**
     * 獲取分類名稱
     */
    private function getCategoryName($category) {
        $names = [
            'success' => '✅ 成功',
            'general' => '🔧 一般錯誤',
            'authentication' => '🔐 認證錯誤',
            'user' => '👤 用戶錯誤',
            'task' => '📋 任務錯誤',
            'chat' => '💬 聊天錯誤',
            'rate_limit' => '🚦 節流限制',
            'business_logic' => '💼 業務邏輯',
            'third_party' => '🔗 第三方服務',
            'validation' => '✏️ 資料驗證'
        ];
        
        return $names[$category] ?? ucfirst($category);
    }
    
    /**
     * 生成並保存 HTML 文檔
     */
    public function saveHtml($outputFile = null) {
        $outputFile = $outputFile ?: __DIR__ . '/../../docs/api/index.html';
        
        $html = $this->generateHtml();
        
        $dir = dirname($outputFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        
        return file_put_contents($outputFile, $html) !== false;
    }
    
    /**
     * 生成 Postman Collection
     */
    public function generatePostmanCollection() {
        $collection = [
            'info' => [
                'name' => $this->openApiSpec['info']['title'] ?? 'Here4Help API',
                'description' => $this->openApiSpec['info']['description'] ?? '',
                'version' => $this->openApiSpec['info']['version'] ?? '1.0.0',
                'schema' => 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
            ],
            'auth' => [
                'type' => 'bearer',
                'bearer' => [
                    [
                        'key' => 'token',
                        'value' => '{{access_token}}',
                        'type' => 'string'
                    ]
                ]
            ],
            'variable' => [
                [
                    'key' => 'base_url',
                    'value' => $this->baseUrl,
                    'type' => 'string'
                ],
                [
                    'key' => 'access_token',
                    'value' => '',
                    'type' => 'string'
                ]
            ],
            'item' => [
                [
                    'name' => 'Authentication',
                    'item' => [
                        [
                            'name' => 'Login',
                            'request' => [
                                'method' => 'POST',
                                'header' => [
                                    [
                                        'key' => 'Content-Type',
                                        'value' => 'application/json'
                                    ]
                                ],
                                'body' => [
                                    'mode' => 'raw',
                                    'raw' => json_encode([
                                        'email' => 'user@example.com',
                                        'password' => 'password123'
                                    ], JSON_PRETTY_PRINT)
                                ],
                                'url' => [
                                    'raw' => '{{base_url}}/auth/login.php',
                                    'host' => ['{{base_url}}'],
                                    'path' => ['auth', 'login.php']
                                ]
                            ]
                        ],
                        [
                            'name' => 'Refresh Token',
                            'request' => [
                                'method' => 'POST',
                                'header' => [
                                    [
                                        'key' => 'Content-Type',
                                        'value' => 'application/json'
                                    ]
                                ],
                                'body' => [
                                    'mode' => 'raw',
                                    'raw' => json_encode([
                                        'refresh_token' => '{{refresh_token}}'
                                    ], JSON_PRETTY_PRINT)
                                ],
                                'url' => [
                                    'raw' => '{{base_url}}/auth/refresh-token.php',
                                    'host' => ['{{base_url}}'],
                                    'path' => ['auth', 'refresh-token.php']
                                ]
                            ]
                        ]
                    ]
                ],
                [
                    'name' => 'Tasks',
                    'item' => [
                        [
                            'name' => 'Get Task List',
                            'request' => [
                                'method' => 'GET',
                                'header' => [],
                                'url' => [
                                    'raw' => '{{base_url}}/tasks/list.php?page=1&per_page=20',
                                    'host' => ['{{base_url}}'],
                                    'path' => ['tasks', 'list.php'],
                                    'query' => [
                                        ['key' => 'page', 'value' => '1'],
                                        ['key' => 'per_page', 'value' => '20']
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ];
        
        return $collection;
    }
    
    /**
     * 保存 Postman Collection
     */
    public function savePostmanCollection($outputFile = null) {
        $outputFile = $outputFile ?: __DIR__ . '/../../docs/api/postman_collection.json';
        
        $collection = $this->generatePostmanCollection();
        
        $dir = dirname($outputFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        
        return file_put_contents($outputFile, json_encode($collection, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) !== false;
    }
}
?>

