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
require_once '../../utils/TokenValidator.php';
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
            'title' => 'Help with English Conversation',
            'description' => 'Looking for someone to practice English conversation with. Need help with daily conversation skills.',
            'reward_point' => '800',
            'location' => 'NTU',
            'task_date' => '2025-01-15',
            'language_requirement' => 'English',
            'hashtags' => ['English', 'Conversation', 'Practice'],
            'application_questions' => [
                'Do you have experience teaching English?',
                'What is your native language?'
            ]
        ],
        [
            'title' => 'Japanese Translation Help',
            'description' => 'Need help translating a short document from Japanese to English. Document is about 500 words.',
            'reward_point' => '1200',
            'location' => 'NCCU',
            'task_date' => '2025-01-20',
            'language_requirement' => 'Japanese,English',
            'hashtags' => ['Japanese', 'Translation', 'Document'],
            'application_questions' => [
                'Do you have experience with Japanese translation?',
                'What is your Japanese proficiency level?'
            ]
        ],
        [
            'title' => 'Math Tutoring for High School Student',
            'description' => 'Looking for a tutor to help with high school mathematics. Topics include algebra and calculus.',
            'reward_point' => '1500',
            'location' => 'NTHU',
            'task_date' => '2025-01-25',
            'language_requirement' => 'Chinese,English',
            'hashtags' => ['Math', 'Tutoring', 'Education'],
            'application_questions' => [
                'What is your educational background in mathematics?',
                'Do you have experience tutoring high school students?'
            ]
        ],
        [
            'title' => 'Website Design Consultation',
            'description' => 'Need consultation for a small business website design. Looking for modern and user-friendly design suggestions.',
            'reward_point' => '3000',
            'location' => 'NCKU',
            'task_date' => '2025-01-30',
            'language_requirement' => 'English',
            'hashtags' => ['Design', 'Website', 'Consultation'],
            'application_questions' => [
                'What is your experience with website design?',
                'Can you provide examples of your previous work?'
            ]
        ],
        [
            'title' => 'Photography for Event',
            'description' => 'Need a photographer for a small corporate event. Event will be held in Taipei.',
            'reward_point' => '2500',
            'location' => 'NTU',
            'task_date' => '2025-02-05',
            'language_requirement' => 'Chinese',
            'hashtags' => ['Photography', 'Event', 'Corporate'],
            'application_questions' => [
                'Do you have experience with event photography?',
                'What equipment do you use?'
            ]
        ],
        [
            'title' => 'Cooking Class Assistant',
            'description' => 'Looking for an assistant for a cooking class. Need help with preparation and cleanup.',
            'reward_point' => '1000',
            'location' => 'NCCU',
            'task_date' => '2025-02-10',
            'language_requirement' => 'Chinese,English',
            'hashtags' => ['Cooking', 'Class', 'Assistant'],
            'application_questions' => [
                'Do you have experience in cooking or food preparation?',
                'Are you comfortable working in a kitchen environment?'
            ]
        ],
        [
            'title' => 'Data Entry Work',
            'description' => 'Need help with data entry work. Simple Excel spreadsheet work.',
            'reward_point' => '600',
            'location' => 'NTHU',
            'task_date' => '2025-02-15',
            'language_requirement' => 'Chinese',
            'hashtags' => ['Data Entry', 'Excel', 'Office'],
            'application_questions' => [
                'Do you have experience with Excel?',
                'How fast can you type?'
            ]
        ],
        [
            'title' => 'Business Plan Review',
            'description' => 'Need someone to review and provide feedback on a business plan.',
            'reward_point' => '5000',
            'location' => 'NCKU',
            'task_date' => '2025-02-20',
            'language_requirement' => 'English',
            'hashtags' => ['Business', 'Plan', 'Review'],
            'application_questions' => [
                'What is your background in business?',
                'Do you have experience reviewing business plans?'
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
                // 隨機指派一個已存在用戶作為 creator_id（若無法找到，預設為 2）
                $creatorIdRow = $this->db->fetch("SELECT id FROM users ORDER BY RAND() LIMIT 1");
                $creatorId = $creatorIdRow ? (int)$creatorIdRow['id'] : 2;
                
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
                $statusRow = $this->db->fetch("SELECT id FROM task_statuses WHERE code = 'open' LIMIT 1");
                $statusId = $statusRow ? (int)$statusRow['id'] : null;

                $sql = "INSERT INTO tasks (id, creator_id, title, description, reward_point, location, task_date, status_id, language_requirement, hashtags, created_at, updated_at) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
                
                $params = [
                    $taskId,
                    $creatorId,
                    $taskData['title'],
                    $taskData['description'],
                    $taskData['reward_point'],
                    $taskData['location'],
                    $taskData['task_date'],
                    $statusId,
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
                    'creator_id' => $creatorId,
                    'title' => $taskData['title'],
                    'status_code' => 'open'
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
            $sql = "SELECT id, creator_id, title, description, reward_point, location, task_date, language_requirement 
                    FROM tasks 
                    WHERE creator_id IS NULL 
                       OR title IS NULL 
                       OR description IS NULL 
                       OR reward_point IS NULL 
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
                $creatorIdRow = $this->db->fetch("SELECT id FROM users ORDER BY RAND() LIMIT 1");
                $creatorId = $creatorIdRow ? (int)$creatorIdRow['id'] : 2;
                
                $updateFields = [];
                $params = [];
                
                // 檢查並填充空欄位
                if (empty($task['creator_id'])) {
                    $updateFields[] = "creator_id = ?";
                    $params[] = $creatorId;
                }
                
                if (empty($task['title'])) {
                    $updateFields[] = "title = ?";
                    $params[] = $taskData['title'];
                }
                
                if (empty($task['description'])) {
                    $updateFields[] = "description = ?";
                    $params[] = $taskData['description'];
                }
                
                if (empty($task['reward_point'])) {
                    $updateFields[] = "reward_point = ?";
                    $params[] = $taskData['reward_point'];
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
                            'creator_id' => empty($task['creator_id']),
                            'title' => empty($task['title']),
                            'description' => empty($task['description']),
                            'reward_point' => empty($task['reward_point']),
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