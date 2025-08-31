<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class UserActivityController extends Controller
{
    /**
     * 獲取使用者活動紀錄列表
     */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'user_id' => 'integer',
            'action' => 'string',
            'actor_type' => 'string|in:user,admin,system',
            'date_from' => 'string',
            'date_to' => 'string',
            'search' => 'string',
            'sort_by' => 'string|in:id,user_id,action,created_at',
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
        $action = $request->get('action');
        $actorType = $request->get('actor_type');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');
        $search = $request->get('search');
        $sortBy = $request->get('sort_by', 'created_at');
        $sortOrder = $request->get('sort_order', 'desc');

        $query = DB::table('user_active_log as ual')
            ->leftJoin('users as u', 'ual.user_id', '=', 'u.id')
            ->leftJoin('admins as a', 'ual.actor_id', '=', 'a.id')
            ->select([
                'ual.id',
                'ual.user_id',
                'ual.actor_type',
                'ual.actor_id',
                'ual.action',
                'ual.field',
                'ual.old_value',
                'ual.new_value',
                'ual.reason',
                'ual.ip',
                'ual.created_at',
                'u.name as user_name',
                'u.email as user_email',
                'a.username as admin_username',
                'a.full_name as admin_full_name'
            ]);

        // 篩選條件
        if ($userId) {
            $query->where('ual.user_id', $userId);
        }

        if ($action) {
            $query->where('ual.action', 'like', "%{$action}%");
        }

        if ($actorType) {
            $query->where('ual.actor_type', $actorType);
        }

        if ($dateFrom) {
            $query->whereDate('ual.created_at', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->whereDate('ual.created_at', '<=', $dateTo);
        }

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('u.name', 'like', "%{$search}%")
                  ->orWhere('u.email', 'like', "%{$search}%")
                  ->orWhere('ual.action', 'like', "%{$search}%")
                  ->orWhere('ual.reason', 'like', "%{$search}%");
            });
        }

        // 排序
        $query->orderBy("ual.{$sortBy}", $sortOrder);

        // 分頁
        $total = $query->count();
        $activities = $query->skip(($page - 1) * $perPage)
                           ->take($perPage)
                           ->get();

        // 統計資訊
        $stats = DB::table('user_active_log')
            ->selectRaw('
                COUNT(*) as total_activities,
                COUNT(DISTINCT user_id) as unique_users,
                COUNT(DISTINCT action) as unique_actions
            ')
            ->when($dateFrom, function ($q) use ($dateFrom) {
                return $q->whereDate('created_at', '>=', $dateFrom);
            })
            ->when($dateTo, function ($q) use ($dateTo) {
                return $q->whereDate('created_at', '<=', $dateTo);
            })
            ->first();

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $activities,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage)
                ],
                'stats' => $stats
            ]
        ]);
    }

    /**
     * 獲取特定使用者的活動紀錄
     */
    public function show(Request $request, $userId)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'action' => 'string',
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
        $action = $request->get('action');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');

        $query = DB::table('user_active_log as ual')
            ->leftJoin('users as u', 'ual.user_id', '=', 'u.id')
            ->leftJoin('admins as a', 'ual.actor_id', '=', 'a.id')
            ->select([
                'ual.id',
                'ual.user_id',
                'ual.actor_type',
                'ual.actor_id',
                'ual.action',
                'ual.field',
                'ual.old_value',
                'ual.new_value',
                'ual.reason',
                'ual.ip',
                'ual.created_at',
                'u.name as user_name',
                'u.email as user_email',
                'a.username as admin_username',
                'a.full_name as admin_full_name'
            ])
            ->where('ual.user_id', $userId);

        if ($action) {
            $query->where('ual.action', 'like', "%{$action}%");
        }

        if ($dateFrom) {
            $query->whereDate('ual.created_at', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->whereDate('ual.created_at', '<=', $dateTo);
        }

        $query->orderBy('ual.created_at', 'desc');

        $total = $query->count();
        $activities = $query->skip(($page - 1) * $perPage)
                           ->take($perPage)
                           ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $activities,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage)
                ]
            ]
        ]);
    }
}
