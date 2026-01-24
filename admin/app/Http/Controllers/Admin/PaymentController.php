<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Schema;

class PaymentController extends Controller
{
    /** GET /admin/payment/requests */
    public function requests(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'status' => 'string|in:pending,approved,rejected',
            'from_date' => 'date',
            'to_date' => 'date',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $page = (int)$request->get('page', 1);
        $perPage = (int)$request->get('per_page', 20);
        $status = $request->get('status');
        $from = $request->get('from_date');
        $to = $request->get('to_date');

        $query = DB::table('point_deposit_requests as pdr')
            ->join('users as u', 'pdr.user_id', '=', 'u.id')
            ->leftJoin('admins as a', 'pdr.approver_id', '=', 'a.id')
            ->select([
                'pdr.*',
                'u.name as user_name',
                'u.email as user_email',
                'a.full_name as admin_name',
            ]);

        if ($status) $query->where('pdr.status', $status);
        if ($from) $query->where('pdr.created_at', '>=', $from);
        if ($to) $query->where('pdr.created_at', '<=', $to . ' 23:59:59');

        $total = $query->count();
        $items = $query
            ->orderByRaw("CASE WHEN pdr.status = 'pending' THEN 0 ELSE 1 END")
            ->orderBy('pdr.created_at', 'desc')
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->get();

        $stats = [
            'pending' => DB::table('point_deposit_requests')->where('status', 'pending')->count(),
            'approved_today' => DB::table('point_deposit_requests')->where('status', 'approved')->whereDate('updated_at', now()->toDateString())->count(),
            'total_amount' => (int) DB::table('point_deposit_requests')->where('status', 'approved')->sum('amount_points'),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $items,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => (int)ceil($total / $perPage),
                ],
                'stats' => $stats,
            ],
        ]);
    }

    /** POST /admin/payment/requests/{id}/approve */
    public function approve(Request $request, $id)
    {
        $adminId = $request->user()->id;
        $req = DB::table('point_deposit_requests')->where('id', $id)->first();
        if (!$req || $req->status !== 'pending') {
            return response()->json(['success' => false, 'message' => 'Invalid request'], 400);
        }

        DB::beginTransaction();
        try {
            // 更新請求狀態
            DB::table('point_deposit_requests')->where('id', $id)->update([
                'status' => 'approved',
                'approver_id' => $adminId,
                'approver_reply_description' => $request->get('note', ''),
                'updated_at' => now(),
            ]);

            // 增加用戶點數
            DB::table('users')->where('id', $req->user_id)->update([
                'points' => DB::raw('points + ' . (int)$req->amount_points),
                'updated_at' => now(),
            ]);

            // 記錄點數交易
            DB::table('point_transactions')->insert([
                'user_id' => $req->user_id,
                'transaction_type' => 'deposit',
                'amount' => (int)$req->amount_points,
                'description' => 'Deposit approved by admin',
                'created_at' => now(),
            ]);

            // 活動日誌
            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => 'payment_approve',
                'table_name' => 'point_deposit_requests',
                'record_id' => $id,
                'old_data' => json_encode(['status' => 'pending']),
                'new_data' => json_encode(['status' => 'approved']),
                'created_at' => now(),
            ]);

            DB::commit();
            return response()->json(['success' => true, 'message' => 'Request approved']);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json(['success' => false, 'message' => 'Approve failed: ' . $e->getMessage()], 500);
        }
    }

    /** POST /admin/payment/requests/{id}/reject */
    public function reject(Request $request, $id)
    {
        $adminId = $request->user()->id;
        $req = DB::table('point_deposit_requests')->where('id', $id)->first();
        if (!$req || $req->status !== 'pending') {
            return response()->json(['success' => false, 'message' => 'Invalid request'], 400);
        }

        DB::table('point_deposit_requests')->where('id', $id)->update([
            'status' => 'rejected',
            'approver_id' => $adminId,
            'approver_reply_description' => $request->get('note', ''),
            'updated_at' => now(),
        ]);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'payment_reject',
            'table_name' => 'point_deposit_requests',
            'record_id' => $id,
            'old_data' => json_encode(['status' => 'pending']),
            'new_data' => json_encode(['status' => 'rejected']),
            'created_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Request rejected']);
    }

    /** GET /admin/payment/withdraw-requests */
    public function withdrawRequests(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'status' => 'string|in:pending,approved,rejected,cancelled,paid',
            'from_date' => 'date',
            'to_date' => 'date',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $page = (int)$request->get('page', 1);
        $perPage = (int)$request->get('per_page', 20);
        $status = $request->get('status');
        $from = $request->get('from_date');
        $to = $request->get('to_date');

        $query = DB::table('point_withdraw_requests as pwr')
            ->join('users as u', 'pwr.user_id', '=', 'u.id')
            ->leftJoin('admins as a', 'pwr.admin_id', '=', 'a.id')
            ->select([
                'pwr.*',
                'u.name as user_name',
                'u.email as user_email',
                'a.full_name as admin_name',
            ]);

        if ($status) $query->where('pwr.status', $status);
        if ($from) $query->where('pwr.created_at', '>=', $from);
        if ($to) $query->where('pwr.created_at', '<=', $to . ' 23:59:59');

        $total = $query->count();
        $items = $query->orderByRaw("CASE WHEN pwr.status = 'pending' THEN 0 ELSE 1 END")
            ->orderBy('pwr.created_at', 'desc')
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->get();

        $stats = [
            'pending' => DB::table('point_withdraw_requests')->where('status', 'pending')->count(),
            'approved_today' => DB::table('point_withdraw_requests')->where('status', 'approved')->whereDate('updated_at', now()->toDateString())->count(),
            'total_amount' => (int) DB::table('point_withdraw_requests')->whereIn('status', ['approved', 'paid'])->sum('net_payout_points'),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $items,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => (int)ceil($total / $perPage),
                ],
                'stats' => $stats,
            ],
        ]);
    }

    /** POST /admin/payment/withdraw-requests/{id}/approve */
    public function approveWithdraw(Request $request, $id)
    {
        $adminId = $request->user()->id;
        $req = DB::table('point_withdraw_requests')->where('id', $id)->first();
        if (!$req || $req->status !== 'pending') {
            return response()->json(['success' => false, 'message' => 'Invalid request'], 400);
        }

        DB::beginTransaction();
        try {
            DB::table('point_withdraw_requests')->where('id', $id)->update([
                'status' => 'approved',
                'admin_id' => $adminId,
                'admin_reply' => $request->get('note', ''),
                'reviewed_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => 'withdraw_approve',
                'table_name' => 'point_withdraw_requests',
                'record_id' => $id,
                'old_data' => json_encode(['status' => 'pending']),
                'new_data' => json_encode(['status' => 'approved']),
                'created_at' => now(),
            ]);

            DB::table('user_active_log')->insert([
                'user_id' => $req->user_id,
                'actor_type' => 'admin',
                'actor_id' => $adminId,
                'action' => 'withdraw_approve',
                'field' => 'withdraw_status',
                'old_value' => 'pending',
                'new_value' => 'approved',
                'reason' => $request->get('note', ''),
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => json_encode([
                    'request_id' => $id,
                    'amount_points' => (int) $req->amount_points,
                    'fee_points' => (int) $req->fee_points,
                    'total_deduct_points' => (int) $req->total_deduct_points,
                ]),
                'created_at' => now(),
            ]);

            if ((int) $req->fee_points > 0) {
                $exists = DB::table('fee_revenue_ledger')
                    ->where('fee_type', 'withdrawal_fee')
                    ->where('withdraw_request_id', $id)
                    ->exists();

                if (!$exists) {
                    DB::table('fee_revenue_ledger')->insert([
                        'fee_type' => 'withdrawal_fee',
                        'src_transaction_id' => null,
                        'task_id' => null,
                        'withdraw_request_id' => $id,
                        'payer_user_id' => $req->user_id,
                        'amount_points' => (int) $req->fee_points,
                        'rate' => (float) $req->fee_rate,
                        'note' => 'Withdraw fee',
                        'created_at' => now(),
                    ]);
                }
            }

            DB::commit();
            return response()->json(['success' => true, 'message' => 'Withdraw request approved']);
        } catch (\Throwable $e) {
            DB::rollBack();
            Log::error('Withdraw approve failed', [
                'withdraw_request_id' => $id,
                'admin_id' => $adminId,
                'note' => $request->get('note', ''),
                'error' => $e->getMessage(),
            ]);
            return response()->json(['success' => false, 'message' => 'Unable to approve the request right now.'], 500);
        }
    }

    /** POST /admin/payment/withdraw-requests/{id}/reject */
    public function rejectWithdraw(Request $request, $id)
    {
        $adminId = $request->user()->id;
        $req = DB::table('point_withdraw_requests')->where('id', $id)->first();
        if (!$req || $req->status !== 'pending') {
            return response()->json(['success' => false, 'message' => 'Invalid request'], 400);
        }

        DB::beginTransaction();
        try {
            DB::table('point_withdraw_requests')->where('id', $id)->update([
                'status' => 'rejected',
                'admin_id' => $adminId,
                'admin_reply' => $request->get('note', ''),
                'reviewed_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => 'withdraw_reject',
                'table_name' => 'point_withdraw_requests',
                'record_id' => $id,
                'old_data' => json_encode(['status' => 'pending']),
                'new_data' => json_encode(['status' => 'rejected']),
                'created_at' => now(),
            ]);

            DB::table('user_active_log')->insert([
                'user_id' => $req->user_id,
                'actor_type' => 'admin',
                'actor_id' => $adminId,
                'action' => 'withdraw_reject',
                'field' => 'withdraw_status',
                'old_value' => 'pending',
                'new_value' => 'rejected',
                'reason' => $request->get('note', ''),
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => json_encode([
                    'request_id' => $id,
                    'amount_points' => (int) $req->amount_points,
                    'fee_points' => (int) $req->fee_points,
                    'total_deduct_points' => (int) $req->total_deduct_points,
                ]),
                'created_at' => now(),
            ]);

            DB::commit();
            return response()->json(['success' => true, 'message' => 'Withdraw request rejected']);
        } catch (\Throwable $e) {
            DB::rollBack();
            Log::error('Withdraw reject failed', [
                'withdraw_request_id' => $id,
                'admin_id' => $adminId,
                'note' => $request->get('note', ''),
                'error' => $e->getMessage(),
            ]);
            return response()->json(['success' => false, 'message' => 'Unable to reject the request right now.'], 500);
        }
    }

    /** POST /admin/payment/withdraw-requests/{id}/paid */
    public function markWithdrawPaid(Request $request, $id)
    {
        $adminId = $request->user()->id;
        $req = DB::table('point_withdraw_requests')->where('id', $id)->first();
        if (!$req || $req->status !== 'approved') {
            return response()->json(['success' => false, 'message' => 'Invalid request'], 400);
        }

        DB::beginTransaction();
        try {
            DB::table('point_withdraw_requests')->where('id', $id)->update([
                'status' => 'paid',
                'admin_id' => $adminId,
                'paid_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => 'withdraw_paid',
                'table_name' => 'point_withdraw_requests',
                'record_id' => $id,
                'old_data' => json_encode(['status' => 'approved']),
                'new_data' => json_encode(['status' => 'paid']),
                'created_at' => now(),
            ]);

            DB::table('user_active_log')->insert([
                'user_id' => $req->user_id,
                'actor_type' => 'admin',
                'actor_id' => $adminId,
                'action' => 'withdraw_paid',
                'field' => 'withdraw_status',
                'old_value' => 'approved',
                'new_value' => 'paid',
                'reason' => null,
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => json_encode([
                    'request_id' => $id,
                    'amount_points' => (int) $req->amount_points,
                    'fee_points' => (int) $req->fee_points,
                    'total_deduct_points' => (int) $req->total_deduct_points,
                ]),
                'created_at' => now(),
            ]);

            DB::commit();
            return response()->json(['success' => true, 'message' => 'Withdraw request marked as paid']);
        } catch (\Throwable $e) {
            DB::rollBack();
            Log::error('Withdraw mark paid failed', [
                'withdraw_request_id' => $id,
                'admin_id' => $adminId,
                'error' => $e->getMessage(),
            ]);
            return response()->json(['success' => false, 'message' => 'Unable to mark as paid right now.'], 500);
        }
    }

    /** GET/POST /admin/payment/fee-settings（唯一 active） */
    public function feeSettings(Request $request)
    {
        if ($request->isMethod('get')) {
            $items = DB::table('withdraw_fee_settings')
                ->orderBy('created_at', 'desc')
                ->get()
                ->map(function ($item) {
                    $rate = isset($item->rate) ? (float)$item->rate : null;
                    $item->rate = $rate;
                    $item->percentage = $rate !== null ? round($rate * 100, 4) : null;
                    return $item;
                });
            return response()->json(['success' => true, 'data' => ['items' => $items]]);
        }

        $validator = Validator::make($request->all(), [
            'percentage' => 'required|numeric|min:0|max:100',
            'min_withdraw_points' => 'required|integer|min:0',
            'description' => 'required|string|max:255',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        DB::beginTransaction();
        try {
            $adminId = $request->user()->id;
            $percentage = (float)$request->get('percentage');
            $rate = $percentage / 100;
            $minWithdrawPoints = (int)$request->get('min_withdraw_points');

            DB::table('withdraw_fee_settings')
                ->where('is_active', 1)
                ->update(['is_active' => 0]);

            $description = $request->get('description');
            $insertData = [
                'rate' => $rate,
                'is_active' => 1,
                'description' => $description,
                'updated_by' => $adminId,
                'min_withdraw_points' => $minWithdrawPoints,
                'created_at' => now(),
                'updated_at' => now(),
            ];

            DB::table('withdraw_fee_settings')->insert($insertData);

            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => 'update',
                'table_name' => 'withdraw_fee_settings',
                'record_id' => null,
                'old_data' => null,
                'new_data' => json_encode([
                    'rate' => $rate,
                    'percentage' => $percentage,
                    'min_withdraw_points' => $minWithdrawPoints,
                    'description' => $description,
                ]),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now(),
            ]);
            DB::commit();
            return response()->json(['success' => true, 'message' => 'Fee setting updated']);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json(['success' => false, 'message' => 'Update failed: ' . $e->getMessage()], 500);
        }
    }

    /** GET/POST /admin/payment/official-accounts（唯一 active） */
    public function officialAccounts(Request $request)
    {
        if ($request->isMethod('get')) {
            $items = DB::table('official_bank_accounts')->orderBy('created_at', 'desc')->get();
            return response()->json(['success' => true, 'data' => ['items' => $items]]);
        }

        $validator = Validator::make($request->all(), [
            'bank_name' => 'required|string|max:100',
            'account_number' => 'required|string|max:100',
            'account_name' => 'required|string|max:100',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        DB::beginTransaction();
        try {
            // 先將既有的非活動紀錄標記為 NULL，避免 UNIQUE KEY 衝突
            // DB::table('official_bank_accounts')
            //     ->where('is_active', 0)
            //     ->update([
            //         'is_active' => 0,
            //         'updated_at' => now(),
            //     ]);

            // 將目前的 active 帳戶關閉
            // DB::table('official_bank_accounts')
            //     ->where('is_active', 1)
            //     ->update([
            //         'is_active' => 0,
            //         'updated_at' => now(),
            //     ]);

            // 將所有的銀行帳戶資料設定為非活躍帳號
             DB::table('official_bank_accounts')
                ->whereIn('is_active', [1, null])
                ->update([
                    'is_active' => null,
                    'updated_at' => now(),
                ]);

            // 新增一筆 active 帳戶
            DB::table('official_bank_accounts')->insert([
                'bank_name' => $request->get('bank_name'),
                'account_number' => $request->get('account_number'),
                'account_holder' => $request->get('account_name'),
                'admin_id' => $request->user()->id,
                'is_active' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            
            // 記錄活動日誌
            DB::table('admin_activity_logs')->insert([
                'admin_id' => $request->user()->id,
                'action' => 'create',
                'table_name' => 'official_bank_accounts',
                'record_id' => null,
                'old_data' => null,
                'new_data' => json_encode([
                    'bank_name' => $request->get('bank_name'),
                    'account_number' => $request->get('account_number'),
                    'account_name' => $request->get('account_name')
                ]),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now(),
            ]);
            
            DB::commit();
            return response()->json(['success' => true, 'message' => 'Official account updated']);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json(['success' => false, 'message' => 'Update failed: ' . $e->getMessage()], 500);
        }
    }
}
