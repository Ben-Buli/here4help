<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class UserTransactionController extends Controller
{
    /**
     * 獲取使用者交易紀錄列表
     */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'user_id' => 'integer',
            'transaction_type' => 'string|in:earn,spend,deposit,fee,refund,adjustment',
            'date_from' => 'string',
            'date_to' => 'string',
            'search' => 'string',
            'sort_by' => 'string|in:id,user_id,amount,created_at',
            'sort_order' => 'string|in:asc,desc'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $page = $request->get('page', 1);
        $perPage = $request->get('per_page', 15);
        $userId = $request->get('user_id');
        $transactionType = $request->get('transaction_type');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');
        $search = $request->get('search');
        $sortBy = $request->get('sort_by', 'created_at');
        $sortOrder = $request->get('sort_order', 'desc');

        $query = DB::table('point_transactions as pt')
            ->leftJoin('users as u', 'pt.user_id', '=', 'u.id')
            ->select([
                'pt.id',
                'pt.user_id',
                'pt.transaction_type',
                'pt.amount',
                'pt.description',
                'pt.related_task_id',
                'pt.status',
                'pt.created_at',
                'u.name as user_name',
                'u.email as user_email',
                'u.points as current_balance'
            ]);

        // 篩選條件
        if ($userId) {
            $query->where('pt.user_id', $userId);
        }

        if ($transactionType) {
            $query->where('pt.transaction_type', $transactionType);
        }

        if ($dateFrom) {
            $query->whereDate('pt.created_at', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->whereDate('pt.created_at', '<=', $dateTo);
        }

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('u.name', 'like', "%{$search}%")
                  ->orWhere('u.email', 'like', "%{$search}%")
                  ->orWhere('pt.description', 'like', "%{$search}%");
            });
        }

        // 排序
        $query->orderBy("pt.{$sortBy}", $sortOrder);

        // 分頁
        $total = $query->count();
        $transactions = $query->skip(($page - 1) * $perPage)
                             ->take($perPage)
                             ->get();

        // 統計資訊
        $stats = DB::table('point_transactions as pt')
            ->selectRaw('
                COUNT(*) as total_transactions,
                COUNT(DISTINCT user_id) as unique_users,
                SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense,
                AVG(ABS(amount)) as avg_amount
            ')
            ->when($dateFrom, function ($q) use ($dateFrom) {
                return $q->whereDate('pt.created_at', '>=', $dateFrom);
            })
            ->when($dateTo, function ($q) use ($dateTo) {
                return $q->whereDate('pt.created_at', '<=', $dateTo);
            })
            ->first();

        // 按交易類型統計
        $typeStats = DB::table('point_transactions as pt')
            ->selectRaw('
                transaction_type,
                COUNT(*) as count,
                SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense
            ')
            ->when($dateFrom, function ($q) use ($dateFrom) {
                return $q->whereDate('pt.created_at', '>=', $dateFrom);
            })
            ->when($dateTo, function ($q) use ($dateTo) {
                return $q->whereDate('pt.created_at', '<=', $dateTo);
            })
            ->groupBy('transaction_type')
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $transactions,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage)
                ],
                'stats' => $stats,
                'type_stats' => $typeStats
            ]
        ]);
    }

    /**
     * 獲取特定使用者的交易紀錄
     */
    public function show(Request $request, $userId)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'transaction_type' => 'string|in:earn,spend,deposit,fee,refund,adjustment',
            'date_from' => 'string',
            'date_to' => 'string'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $page = $request->get('page', 1);
        $perPage = $request->get('per_page', 15);
        $transactionType = $request->get('transaction_type');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');

        $query = DB::table('point_transactions as pt')
            ->leftJoin('users as u', 'pt.user_id', '=', 'u.id')
            ->select([
                'pt.id',
                'pt.user_id',
                'pt.transaction_type',
                'pt.amount',
                'pt.description',
                'pt.related_task_id',
                'pt.status',
                'pt.created_at',
                'u.name as user_name',
                'u.email as user_email',
                'u.points as current_balance'
            ])
            ->where('pt.user_id', $userId);

        if ($transactionType) {
            $query->where('pt.transaction_type', $transactionType);
        }

        if ($dateFrom) {
            $query->whereDate('pt.created_at', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->whereDate('pt.created_at', '<=', $dateTo);
        }

        $query->orderBy('pt.created_at', 'desc');

        $total = $query->count();
        $transactions = $query->skip(($page - 1) * $perPage)
                             ->take($perPage)
                             ->get();

        // 用戶交易統計
        $userStats = DB::table('point_transactions as pt')
            ->selectRaw('
                SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense,
                COUNT(*) as total_transactions
            ')
            ->where('pt.user_id', $userId)
            ->when($dateFrom, function ($q) use ($dateFrom) {
                return $q->whereDate('pt.created_at', '>=', $dateFrom);
            })
            ->when($dateTo, function ($q) use ($dateTo) {
                return $q->whereDate('pt.created_at', '<=', $dateTo);
            })
            ->first();

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $transactions,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage)
                ],
                'user_stats' => $userStats
            ]
        ]);
    }
}
