<?php
/**
 * 分頁工具類
 * 提供統一的分頁參數處理與回應格式
 */

class Pagination {
    
    // 預設配置
    const DEFAULT_PAGE = 1;
    const DEFAULT_PER_PAGE = 20;
    const MAX_PER_PAGE = 100;
    const MIN_PER_PAGE = 1;
    
    private $page;
    private $perPage;
    private $total;
    private $offset;
    
    /**
     * 建構子
     */
    public function __construct($page = null, $perPage = null) {
        $this->page = $this->validatePage($page);
        $this->perPage = $this->validatePerPage($perPage);
        $this->offset = ($this->page - 1) * $this->perPage;
    }
    
    /**
     * 從請求參數建立分頁物件
     */
    public static function fromRequest($request = null) {
        if ($request === null) {
            // 從 $_GET 或 POST 資料獲取
            $request = $_GET ?? [];
            if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'POST') {
                $postData = json_decode(file_get_contents('php://input'), true);
                if ($postData) {
                    $request = array_merge($request, $postData);
                }
            }
        }
        
        $page = $request['page'] ?? $request['p'] ?? null;
        $perPage = $request['per_page'] ?? $request['limit'] ?? $request['size'] ?? null;
        
        return new self($page, $perPage);
    }
    
    /**
     * 驗證頁碼
     */
    private function validatePage($page) {
        $page = (int) $page;
        return max(1, $page ?: self::DEFAULT_PAGE);
    }
    
    /**
     * 驗證每頁數量
     */
    private function validatePerPage($perPage) {
        $perPage = (int) $perPage;
        if ($perPage <= 0) {
            return self::DEFAULT_PER_PAGE;
        }
        return min(self::MAX_PER_PAGE, max(self::MIN_PER_PAGE, $perPage));
    }
    
    /**
     * 設定總記錄數
     */
    public function setTotal($total) {
        $this->total = max(0, (int) $total);
        return $this;
    }
    
    /**
     * 獲取頁碼
     */
    public function getPage() {
        return $this->page;
    }
    
    /**
     * 獲取每頁數量
     */
    public function getPerPage() {
        return $this->perPage;
    }
    
    /**
     * 獲取偏移量
     */
    public function getOffset() {
        return $this->offset;
    }
    
    /**
     * 獲取總記錄數
     */
    public function getTotal() {
        return $this->total;
    }
    
    /**
     * 獲取總頁數
     */
    public function getTotalPages() {
        if ($this->total === null) {
            return null;
        }
        return (int) ceil($this->total / $this->perPage);
    }
    
    /**
     * 是否有下一頁
     */
    public function hasNextPage() {
        $totalPages = $this->getTotalPages();
        return $totalPages !== null && $this->page < $totalPages;
    }
    
    /**
     * 是否有上一頁
     */
    public function hasPreviousPage() {
        return $this->page > 1;
    }
    
    /**
     * 獲取下一頁頁碼
     */
    public function getNextPage() {
        return $this->hasNextPage() ? $this->page + 1 : null;
    }
    
    /**
     * 獲取上一頁頁碼
     */
    public function getPreviousPage() {
        return $this->hasPreviousPage() ? $this->page - 1 : null;
    }
    
    /**
     * 獲取 SQL LIMIT 子句
     */
    public function getSqlLimit() {
        return "LIMIT {$this->offset}, {$this->perPage}";
    }
    
    /**
     * 獲取 SQL OFFSET 子句（PostgreSQL 風格）
     */
    public function getSqlOffset() {
        return "LIMIT {$this->perPage} OFFSET {$this->offset}";
    }
    
    /**
     * 生成分頁資訊陣列
     */
    public function toArray() {
        $totalPages = $this->getTotalPages();
        
        return [
            'current_page' => $this->page,
            'per_page' => $this->perPage,
            'total' => $this->total,
            'total_pages' => $totalPages,
            'has_next_page' => $this->hasNextPage(),
            'has_previous_page' => $this->hasPreviousPage(),
            'next_page' => $this->getNextPage(),
            'previous_page' => $this->getPreviousPage(),
            'from' => $this->total > 0 ? $this->offset + 1 : 0,
            'to' => $this->total > 0 ? min($this->offset + $this->perPage, $this->total) : 0
        ];
    }
    
    /**
     * 生成簡化的分頁資訊
     */
    public function toSimpleArray() {
        return [
            'page' => $this->page,
            'per_page' => $this->perPage,
            'total' => $this->total,
            'has_more' => $this->hasNextPage()
        ];
    }
    
    /**
     * 生成分頁連結
     */
    public function generateLinks($baseUrl, $queryParams = []) {
        $links = [];
        
        // 移除現有的分頁參數
        unset($queryParams['page'], $queryParams['per_page']);
        
        // 第一頁
        if ($this->hasPreviousPage()) {
            $links['first'] = $this->buildUrl($baseUrl, array_merge($queryParams, ['page' => 1]));
            $links['previous'] = $this->buildUrl($baseUrl, array_merge($queryParams, ['page' => $this->getPreviousPage()]));
        }
        
        // 當前頁
        $links['self'] = $this->buildUrl($baseUrl, array_merge($queryParams, ['page' => $this->page]));
        
        // 下一頁和最後一頁
        if ($this->hasNextPage()) {
            $links['next'] = $this->buildUrl($baseUrl, array_merge($queryParams, ['page' => $this->getNextPage()]));
            $totalPages = $this->getTotalPages();
            if ($totalPages) {
                $links['last'] = $this->buildUrl($baseUrl, array_merge($queryParams, ['page' => $totalPages]));
            }
        }
        
        return $links;
    }
    
    /**
     * 建構 URL
     */
    private function buildUrl($baseUrl, $params) {
        if (empty($params)) {
            return $baseUrl;
        }
        
        $separator = strpos($baseUrl, '?') !== false ? '&' : '?';
        return $baseUrl . $separator . http_build_query($params);
    }
    
    /**
     * 驗證分頁參數
     */
    public static function validateParams($page, $perPage) {
        $errors = [];
        
        if ($page !== null) {
            $page = (int) $page;
            if ($page < 1) {
                $errors['page'] = '頁碼必須大於 0';
            }
        }
        
        if ($perPage !== null) {
            $perPage = (int) $perPage;
            if ($perPage < self::MIN_PER_PAGE) {
                $errors['per_page'] = "每頁數量不能少於 " . self::MIN_PER_PAGE;
            } elseif ($perPage > self::MAX_PER_PAGE) {
                $errors['per_page'] = "每頁數量不能超過 " . self::MAX_PER_PAGE;
            }
        }
        
        return $errors;
    }
    
    /**
     * 分頁資料包裝器
     */
    public static function paginate($items, $total, $pagination) {
        return [
            'items' => $items,
            'pagination' => $pagination->setTotal($total)->toArray()
        ];
    }
    
    /**
     * 簡化分頁資料包裝器
     */
    public static function paginateSimple($items, $total, $pagination) {
        return [
            'data' => $items,
            'meta' => $pagination->setTotal($total)->toSimpleArray()
        ];
    }
    
    /**
     * 獲取分頁統計資訊
     */
    public function getStats() {
        if ($this->total === null) {
            return null;
        }
        
        $totalPages = $this->getTotalPages();
        $from = $this->total > 0 ? $this->offset + 1 : 0;
        $to = $this->total > 0 ? min($this->offset + $this->perPage, $this->total) : 0;
        
        return [
            'showing' => $to - $from + 1,
            'from' => $from,
            'to' => $to,
            'total' => $this->total,
            'page' => $this->page,
            'total_pages' => $totalPages
        ];
    }
    
    /**
     * 生成分頁描述文字
     */
    public function getDescription($language = 'zh') {
        if ($this->total === null) {
            return '';
        }
        
        $stats = $this->getStats();
        
        if ($language === 'zh') {
            if ($this->total === 0) {
                return '沒有找到任何記錄';
            }
            return "顯示第 {$stats['from']} 到 {$stats['to']} 項，共 {$stats['total']} 項記錄";
        } else {
            if ($this->total === 0) {
                return 'No records found';
            }
            return "Showing {$stats['from']} to {$stats['to']} of {$stats['total']} results";
        }
    }
    
    /**
     * 檢查是否為有效的分頁請求
     */
    public function isValidPage() {
        if ($this->total === null) {
            return true; // 無法驗證，假設有效
        }
        
        $totalPages = $this->getTotalPages();
        return $this->page <= $totalPages || $totalPages === 0;
    }
}
?>
