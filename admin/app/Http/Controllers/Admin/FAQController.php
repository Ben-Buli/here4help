<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Auth;

class FAQController extends Controller
{
    /**
     * 獲取 FAQ 列表
     */
    public function index(Request $request)
    {
        try {
            $perPage = $request->input('per_page', 20);
            $page = $request->input('page', 1);
            $search = $request->input('search', '');
            $category = $request->input('category', '');
            $isActive = $request->input('is_active', '');
            $sortBy = $request->input('sort_by', 'sort_order');
            $sortOrder = $request->input('sort_order', 'asc');
            
            // 使用 PHP 後端資料庫
            $db = $this->getBackendDB();
            
            // 構建查詢
            $query = "SELECT 
                f.*,
                u1.name as created_by_name,
                u2.name as updated_by_name
            FROM faqs f
            LEFT JOIN admins u1 ON f.created_by = u1.id
            LEFT JOIN admins u2 ON f.updated_by = u2.id
            WHERE 1=1";
            
            $params = [];
            
            if (!empty($search)) {
                $query .= " AND (f.question LIKE ? OR f.answer LIKE ?)";
                $params[] = "%{$search}%";
                $params[] = "%{$search}%";
            }
            
            if ($category !== '') {
                $query .= " AND f.category = ?";
                $params[] = $category;
            }
            
            if ($isActive !== '') {
                $query .= " AND f.is_active = ?";
                $params[] = (int)$isActive;
            }
            
            // 獲取總數
            $countQuery = str_replace('SELECT f.*, u1.name as created_by_name, u2.name as updated_by_name', 'SELECT COUNT(*) as total', $query);
            $stmt = $db->prepare($countQuery);
            $stmt->execute($params);
            $total = $stmt->fetch(\PDO::FETCH_ASSOC)['total'];
            
            // 添加排序和分頁
            $query .= " ORDER BY f.{$sortBy} {$sortOrder}";
            $offset = ($page - 1) * $perPage;
            $query .= " LIMIT ? OFFSET ?";
            $params[] = (int)$perPage;
            $params[] = (int)$offset;
            
            $stmt = $db->prepare($query);
            $stmt->execute($params);
            $faqs = $stmt->fetchAll(\PDO::FETCH_ASSOC);
            
            // 獲取統計
            $statsQuery = "SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_count
            FROM faqs";
            $stats = $db->query($statsQuery)->fetch(\PDO::FETCH_ASSOC);
            
            return response()->json([
                'success' => true,
                'data' => [
                    'items' => $faqs,
                    'pagination' => [
                        'current_page' => (int)$page,
                        'per_page' => (int)$perPage,
                        'total' => (int)$total,
                        'last_page' => ceil($total / $perPage)
                    ],
                    'stats' => $stats
                ]
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch FAQs: ' . $e->getMessage()
            ], 500);
        }
    }
    
    /**
     * 獲取單個 FAQ
     */
    public function show($id)
    {
        try {
            $db = $this->getBackendDB();
            
            $query = "SELECT f.* FROM faqs f WHERE f.id = ?";
            
            $stmt = $db->prepare($query);
            $stmt->execute([$id]);
            $faq = $stmt->fetch(\PDO::FETCH_ASSOC);
            
            if (!$faq) {
                return response()->json([
                    'success' => false,
                    'message' => 'FAQ not found'
                ], 404);
            }
            
            return response()->json([
                'success' => true,
                'data' => $faq
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch FAQ: ' . $e->getMessage()
            ], 500);
        }
    }
    
    /**
     * 創建 FAQ
     */
    public function store(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'question' => 'required|string|max:500',
                'answer' => 'required|string',
                'category' => 'required|string|max:100',
                'language' => 'string|max:10',
            ]);
            
            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }
            
            $db = $this->getBackendDB();
            
            // 獲取當前最大 sort_order
            $maxOrder = $db->query("SELECT MAX(sort_order) as max_order FROM faqs")->fetch(\PDO::FETCH_ASSOC)['max_order'] ?? 0;
            
            $query = "INSERT INTO faqs (
                question, answer, category, language, is_active, sort_order, created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?)";
            
            $stmt = $db->prepare($query);
            $stmt->execute([
                $request->input('question'),
                $request->input('answer'),
                $request->input('category'),
                $request->input('language', 'en'), // 預設為英語
                $request->input('is_active', 1),
                $maxOrder + 1,
                Auth::id() ?? null
            ]);
            
            $faqId = $db->lastInsertId();
            
            return response()->json([
                'success' => true,
                'message' => 'FAQ created successfully',
                'data' => ['id' => $faqId]
            ], 201);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create FAQ: ' . $e->getMessage()
            ], 500);
        }
    }
    
    /**
     * 更新 FAQ
     */
    public function update(Request $request, $id)
    {
        try {
            $validator = Validator::make($request->all(), [
                'question' => 'string|max:500',
                'answer' => 'string',
                'category' => 'string|max:100',
                'is_active' => 'boolean',
                'language' => 'string|max:10',
                'sort_order' => 'integer'
            ]);
            
            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }
            
            $db = $this->getBackendDB();
            
            $updates = [];
            $params = [];
            
            foreach (['question', 'answer', 'category', 'is_active', 'language', 'sort_order'] as $field) {
                if ($request->has($field)) {
                    $updates[] = "{$field} = ?";
                    $params[] = $request->input($field);
                }
            }
            
            if (empty($updates)) {
                return response()->json([
                    'success' => false,
                    'message' => 'No fields to update'
                ], 400);
            }
            
            $updates[] = "updated_by = ?";
            $params[] = Auth::id() ?? null;
            $params[] = $id;
            
            $query = "UPDATE faqs SET " . implode(', ', $updates) . " WHERE id = ?";
            $stmt = $db->prepare($query);
            $stmt->execute($params);
            
            return response()->json([
                'success' => true,
                'message' => 'FAQ updated successfully'
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update FAQ: ' . $e->getMessage()
            ], 500);
        }
    }
    
    /**
     * 刪除 FAQ
     */
    public function destroy($id)
    {
        try {
            $db = $this->getBackendDB();
            
            $query = "DELETE FROM faqs WHERE id = ?";
            $stmt = $db->prepare($query);
            $stmt->execute([$id]);
            
            return response()->json([
                'success' => true,
                'message' => 'FAQ deleted successfully'
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete FAQ: ' . $e->getMessage()
            ], 500);
        }
    }
    
    /**
     * 批量更新排序
     */
    public function updateOrder(Request $request)
    {
        try {
            $items = $request->input('items', []);
            
            if (empty($items)) {
                return response()->json([
                    'success' => false,
                    'message' => 'No items provided'
                ], 400);
            }
            
            $db = $this->getBackendDB();
            $db->beginTransaction();
            
            $query = "UPDATE faqs SET sort_order = ? WHERE id = ?";
            $stmt = $db->prepare($query);
            
            foreach ($items as $item) {
                $stmt->execute([$item['sort_order'], $item['id']]);
            }
            
            $db->commit();
            
            return response()->json([
                'success' => true,
                'message' => 'Order updated successfully'
            ]);
            
        } catch (\Exception $e) {
            $db->rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to update order: ' . $e->getMessage()
            ], 500);
        }
    }
    
    /**
     * 獲取 PHP 後端資料庫連接
     */
    private function getBackendDB()
    {
        $config = config('database.connections.backend');
        
        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            $config['host'],
            $config['port'],
            $config['database']
        );
        
        return new \PDO($dsn, $config['username'], $config['password'], [
            \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
            \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC
        ]);
    }
}

