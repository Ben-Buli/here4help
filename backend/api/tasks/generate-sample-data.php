<?php
/**
 * 任務資料自動生成腳本
 * 用於為現有 tasks 資料空欄位自動生成符合語境的任務資訊
 * 
 * 使用方法：
 * 1. 直接訪問此檔案來生成範例資料
 * 2. 或者透過 API 調用來生成資料
 */

require_once '../../config/database.php';
require_once '../../utils/Response.php';

// 設定 CORS 標頭
Response::setCorsHeaders();

// 允許 GET 和 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

class TaskDataGenerator {
    private $db;
    
    // 範例任務資料
    private $sampleTasks = [
        [
            'title' => '協助搬家整理',
            'description' => '需要協助整理房間和打包物品，主要是書籍和衣物。希望有經驗的人幫忙，工作時間約4小時。',
            'salary' => '800',
            'location' => '台北市信義區',
            'task_date' => '2024-12-25',
            'language_requirement' => '中文',
            'hashtags' => ['搬家', '整理', '台北'],
            'application_questions' => [
                '您有搬家整理的經驗嗎？',
                '您可以在12月25日上午9點開始工作嗎？',
                '您能搬運重物嗎？'
            ]
        ],
        [
            'title' => '英文家教輔導',
            'description' => '尋找英文家教，主要輔導國中英文課程。每週2次，每次2小時，希望有教學經驗。',
            'salary' => '1200',
            'location' => '新北市板橋區',
            'task_date' => '2024-12-20',
            'language_requirement' => '英文',
            'hashtags' => ['家教', '英文', '教育'],
            'application_questions' => [
                '您有英文教學經驗嗎？',
                '您的英文程度如何？',
                '您能配合週二和週四的課程時間嗎？'
            ]
        ],
        [
            'title' => '寵物照顧服務',
            'description' => '需要照顧兩隻貓咪，包括餵食、清理貓砂、陪伴玩耍。主人出差3天，需要愛貓人士。',
            'salary' => '1500',
            'location' => '台中市西區',
            'task_date' => '2024-12-22',
            'language_requirement' => '中文',
            'hashtags' => ['寵物', '照顧', '貓咪'],
            'application_questions' => [
                '您有照顧貓咪的經驗嗎？',
                '您能每天來家裡2次嗎？',
                '您對貓毛過敏嗎？'
            ]
        ],
        [
            'title' => '網站設計協助',
            'description' => '需要協助設計小型企業網站，使用WordPress。希望有相關經驗的設計師幫忙。',
            'salary' => '3000',
            'location' => '高雄市前金區',
            'task_date' => '2024-12-28',
            'language_requirement' => '中文',
            'hashtags' => ['網站設計', 'WordPress', '設計'],
            'application_questions' => [
                '您有WordPress網站設計經驗嗎？',
                '您能提供作品集嗎？',
                '您預計需要多少時間完成？'
            ]
        ],
        [
            'title' => '活動攝影師',
            'description' => '公司年終聚餐需要攝影師，活動時間約3小時。需要專業攝影設備和經驗。',
            'salary' => '2500',
            'location' => '桃園市中壢區',
            'task_date' => '2024-12-30',
            'language_requirement' => '中文',
            'hashtags' => ['攝影', '活動', '年終'],
            'application_questions' => [
                '您有活動攝影經驗嗎？',
                '您使用什麼攝影設備？',
                '您能提供作品集嗎？'
            ]
        ],
        [
            'title' => '翻譯文件協助',
            'description' => '需要將中文文件翻譯成英文，約2000字。希望有翻譯經驗的人協助。',
            'salary' => '1000',
            'location' => '台南市東區',
            'task_date' => '2024-12-23',
            'language_requirement' => '英文',
            'hashtags' => ['翻譯', '文件', '中英'],
            'application_questions' => [
                '您有文件翻譯經驗嗎？',
                '您的英文程度如何？',
                '您能在3天內完成嗎？'
            ]
        ],
        [
            'title' => '居家清潔服務',
            'description' => '需要居家清潔服務，主要是客廳和廚房。希望有清潔經驗的人幫忙。',
            'salary' => '600',
            'location' => '新竹市東區',
            'task_date' => '2024-12-24',
            'language_requirement' => '中文',
            'hashtags' => ['清潔', '居家', '服務'],
            'application_questions' => [
                '您有居家清潔經驗嗎？',
                '您能提供清潔用品嗎？',
                '您預計需要多少時間？'
            ]
        ],
        [
            'title' => '程式開發協助',
            'description' => '需要協助開發簡單的Android應用程式，功能是計算器。希望有Android開發經驗。',
            'salary' => '5000',
            'location' => '台北市大安區',
            'task_date' => '2024-12-31',
            'language_requirement' => '中文',
            'hashtags' => ['程式開發', 'Android', '應用程式'],
            'application_questions' => [
                '您有Android開發經驗嗎？',
                '您使用什麼開發工具？',
                '您能提供作品集嗎？'
            ]
        ]
    ];
    
    // 範例使用者名稱
    private $sampleUsers = [
        '張小明',
        '李美玲',
        '王建國',
        '陳雅婷',
        '劉志豪',
        '林佳慧',
        '黃志偉',
        '吳淑芬'
    ];
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    /**
     * 生成範例任務資料
     */
    public function generateSampleTasks($count = 8) {
        try {
            $generatedTasks = [];
            
            for ($i = 0; $i < $count; $i++) {
                $taskData = $this->sampleTasks[$i % count($this->sampleTasks)];
                $creatorName = $this->sampleUsers[$i % count($this->sampleUsers)];
                
                // 生成 UUID
                $taskId = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                    mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                    mt_rand(0, 0xffff),
                    mt_rand(0, 0x0fff) | 0x4000,
                    mt_rand(0, 0x3fff) | 0x8000,
                    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
                );
                
                // 處理 hashtags
                $hashtags = '';
                if (!empty($taskData['hashtags']) && is_array($taskData['hashtags'])) {
                    $hashtags = implode(',', $taskData['hashtags']);
                }
                
                // 插入任務資料
                $sql = "INSERT INTO tasks (id, creator_name, title, description, salary, location, task_date, status, language_requirement, hashtags, created_at, updated_at) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
                
                $params = [
                    $taskId,
                    $creatorName,
                    $taskData['title'],
                    $taskData['description'],
                    $taskData['salary'],
                    $taskData['location'],
                    $taskData['task_date'],
                    'Open',
                    $taskData['language_requirement'],
                    $hashtags
                ];
                
                $this->db->query($sql, $params);
                
                // 處理申請問題
                if (!empty($taskData['application_questions']) && is_array($taskData['application_questions'])) {
                    foreach ($taskData['application_questions'] as $index => $question) {
                        if (!empty($question)) {
                            $questionId = sprintf('q%d-%s', $index + 1, $taskId);
                            $questionSql = "INSERT INTO application_questions (id, task_id, application_question, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())";
                            $this->db->query($questionSql, [$questionId, $taskId, $question]);
                        }
                    }
                }
                
                $generatedTasks[] = [
                    'id' => $taskId,
                    'creator_name' => $creatorName,
                    'title' => $taskData['title'],
                    'status' => 'Open'
                ];
            }
            
            return $generatedTasks;
            
        } catch (Exception $e) {
            throw new Exception('Failed to generate sample tasks: ' . $e->getMessage());
        }
    }
    
    /**
     * 檢查現有任務資料的空欄位
     */
    public function checkEmptyFields() {
        try {
            $sql = "SELECT id, creator_name, title, description, salary, location, task_date, language_requirement 
                    FROM tasks 
                    WHERE creator_name IS NULL 
                       OR title IS NULL 
                       OR description IS NULL 
                       OR salary IS NULL 
                       OR location IS NULL 
                       OR task_date IS NULL 
                       OR language_requirement IS NULL";
            
            $emptyTasks = $this->db->fetchAll($sql);
            return $emptyTasks;
            
        } catch (Exception $e) {
            throw new Exception('Failed to check empty fields: ' . $e->getMessage());
        }
    }
    
    /**
     * 為空欄位生成資料
     */
    public function fillEmptyFields() {
        try {
            $emptyTasks = $this->checkEmptyFields();
            $filledTasks = [];
            
            foreach ($emptyTasks as $task) {
                $taskData = $this->sampleTasks[array_rand($this->sampleTasks)];
                $creatorName = $this->sampleUsers[array_rand($this->sampleUsers)];
                
                $updateFields = [];
                $params = [];
                
                // 檢查並填充空欄位
                if (empty($task['creator_name'])) {
                    $updateFields[] = "creator_name = ?";
                    $params[] = $creatorName;
                }
                
                if (empty($task['title'])) {
                    $updateFields[] = "title = ?";
                    $params[] = $taskData['title'];
                }
                
                if (empty($task['description'])) {
                    $updateFields[] = "description = ?";
                    $params[] = $taskData['description'];
                }
                
                if (empty($task['salary'])) {
                    $updateFields[] = "salary = ?";
                    $params[] = $taskData['salary'];
                }
                
                if (empty($task['location'])) {
                    $updateFields[] = "location = ?";
                    $params[] = $taskData['location'];
                }
                
                if (empty($task['task_date'])) {
                    $updateFields[] = "task_date = ?";
                    $params[] = $taskData['task_date'];
                }
                
                if (empty($task['language_requirement'])) {
                    $updateFields[] = "language_requirement = ?";
                    $params[] = $taskData['language_requirement'];
                }
                
                if (!empty($updateFields)) {
                    $updateFields[] = "updated_at = NOW()";
                    $params[] = $task['id'];
                    
                    $sql = "UPDATE tasks SET " . implode(', ', $updateFields) . " WHERE id = ?";
                    $this->db->query($sql, $params);
                    
                    $filledTasks[] = [
                        'id' => $task['id'],
                        'updated_fields' => array_keys(array_filter([
                            'creator_name' => empty($task['creator_name']),
                            'title' => empty($task['title']),
                            'description' => empty($task['description']),
                            'salary' => empty($task['salary']),
                            'location' => empty($task['location']),
                            'task_date' => empty($task['task_date']),
                            'language_requirement' => empty($task['language_requirement'])
                        ]))
                    ];
                }
            }
            
            return $filledTasks;
            
        } catch (Exception $e) {
            throw new Exception('Failed to fill empty fields: ' . $e->getMessage());
        }
    }
}

// 處理請求
try {
    $generator = new TaskDataGenerator();
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // 檢查是否有查詢參數
        $action = $_GET['action'] ?? 'check';
        
        switch ($action) {
            case 'check':
                // 檢查空欄位
                $emptyTasks = $generator->checkEmptyFields();
                Response::success([
                    'empty_tasks' => $emptyTasks,
                    'count' => count($emptyTasks)
                ], 'Empty fields checked successfully');
                break;
                
            case 'fill':
                // 填充空欄位
                $filledTasks = $generator->fillEmptyFields();
                Response::success([
                    'filled_tasks' => $filledTasks,
                    'count' => count($filledTasks)
                ], 'Empty fields filled successfully');
                break;
                
            case 'generate':
                // 生成新範例資料
                $count = (int)($_GET['count'] ?? 8);
                $generatedTasks = $generator->generateSampleTasks($count);
                Response::success([
                    'generated_tasks' => $generatedTasks,
                    'count' => count($generatedTasks)
                ], 'Sample tasks generated successfully');
                break;
                
            default:
                Response::error('Invalid action');
        }
    } else {
        // POST 請求 - 生成新範例資料
        $input = json_decode(file_get_contents('php://input'), true);
        $count = $input['count'] ?? 8;
        
        $generatedTasks = $generator->generateSampleTasks($count);
        Response::success([
            'generated_tasks' => $generatedTasks,
            'count' => count($generatedTasks)
        ], 'Sample tasks generated successfully');
    }
    
} catch (Exception $e) {
    Response::serverError('Failed to process request: ' . $e->getMessage());
}
?> 