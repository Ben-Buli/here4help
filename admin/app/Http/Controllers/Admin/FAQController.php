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
            
            $allowedSortFields = [
                'sort_order',
                'id',
                'question',
                'category',
                'is_active',
                'created_at',
                'updated_at',
            ];

            if (!in_array($sortBy, $allowedSortFields, true)) {
                $sortBy = 'sort_order';
            }

            $sortOrder = strtolower($sortOrder) === 'desc' ? 'desc' : 'asc';

            $baseQuery = DB::table('faqs as f')
                ->leftJoin('admins as u1', 'f.created_by', '=', 'u1.id')
                ->leftJoin('admins as u2', 'f.updated_by', '=', 'u2.id')
                ->select('f.*', 'u1.full_name as created_by_name', 'u2.full_name as updated_by_name');

            if (!empty($search)) {
                $baseQuery->where(function ($query) use ($search) {
                    $query->where('f.question', 'like', "%{$search}%")
                        ->orWhere('f.answer', 'like', "%{$search}%");
                });
            }

            if ($category !== '') {
                $baseQuery->where('f.category', $category);
            }

            if ($isActive !== '') {
                $baseQuery->where('f.is_active', (int) $isActive);
            }

            $total = (clone $baseQuery)->count();

            $faqs = (clone $baseQuery)
                ->orderBy($sortBy, $sortOrder)
                ->forPage($page, $perPage)
                ->get()
                ->toArray();

            $statsRecord = DB::table('faqs')
                ->selectRaw('COUNT(*) as total, SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_count')
                ->first();
            $stats = $statsRecord ? (array) $statsRecord : ['total' => 0, 'active_count' => 0];
            
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
            // 驗證 ID 是否為有效數字
            if (!is_numeric($id) || $id <= 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid FAQ ID'
                ], 400);
            }
            
            $id = (int) $id;
            
            $faq = DB::table('faqs')->where('id', $id)->first();
            
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
            
            $maxOrder = DB::table('faqs')->max('sort_order') ?? 0;

            $faqId = DB::table('faqs')->insertGetId([
                'question' => $request->input('question'),
                'answer' => $request->input('answer'),
                'category' => $request->input('category'),
                'language' => $request->input('language', 'en'),
                'is_active' => $request->input('is_active', 1),
                'sort_order' => $maxOrder + 1,
                'created_by' => Auth::id(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            
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
            // 驗證 ID 是否為有效數字
            if (!is_numeric($id) || $id <= 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid FAQ ID'
                ], 400);
            }
            
            $id = (int) $id;
            
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
            
            $data = [];

            foreach (['question', 'answer', 'category', 'is_active', 'language', 'sort_order'] as $field) {
                if ($request->has($field)) {
                    $data[$field] = $request->input($field);
                }
            }

            if (empty($data)) {
                return response()->json([
                    'success' => false,
                    'message' => 'No fields to update'
                ], 400);
            }
            
            $data['updated_by'] = Auth::id();
            $data['updated_at'] = now();

            $updated = DB::table('faqs')->where('id', $id)->update($data);

            if (!$updated) {
                return response()->json([
                    'success' => false,
                    'message' => 'FAQ not found'
                ], 404);
            }
            
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
            // 驗證 ID 是否為有效數字
            if (!is_numeric($id) || $id <= 0) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid FAQ ID'
                ], 400);
            }
            
            $id = (int) $id;
            
            $deleted = DB::table('faqs')->where('id', $id)->delete();

            if (!$deleted) {
                return response()->json([
                    'success' => false,
                    'message' => 'FAQ not found'
                ], 404);
            }
            
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
            
            DB::transaction(function () use ($items) {
                foreach ($items as $item) {
                    DB::table('faqs')
                        ->where('id', $item['id'])
                        ->update([
                            'sort_order' => $item['sort_order'],
                            'updated_by' => Auth::id(),
                            'updated_at' => now(),
                        ]);
                }
            });
            
            return response()->json([
                'success' => true,
                'message' => 'Order updated successfully'
            ]);
            
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update order: ' . $e->getMessage()
            ], 500);
        }
    }
}
