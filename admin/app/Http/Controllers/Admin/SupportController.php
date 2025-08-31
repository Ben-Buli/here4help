<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class SupportController extends Controller
{
    /**
     * GET /admin/support/issues
     * type: all|support|dispute
     * status: open|in_progress|waiting_customer|resolved|closed
     */
    public function issues(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'type' => 'string|in:all,support,dispute',
            'status' => 'string|in:open,in_progress,waiting_customer,resolved,closed',
            'search' => 'string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $page = (int)$request->get('page', 1);
        $perPage = (int)$request->get('per_page', 20);
        $type = $request->get('type', 'all');
        $status = $request->get('status');
        $search = $request->get('search');

        $query = DB::table('chat_rooms as cr')
            ->leftJoin('support_events as se', 'se.chat_room_id', '=', 'cr.id')
            ->leftJoin('users as u', 'cr.creator_id', '=', 'u.id')
            ->select([
                'cr.id as room_id',
                'cr.type',
                'cr.creator_id',
                'cr.participant_id',
                'cr.created_at',
                'se.id as event_id',
                'se.title',
                'se.status',
                'se.admin_id as assignee_admin_id',
                'se.created_at as event_created_at',
                'se.updated_at as last_message_at',
                'u.id as user_id',
                'u.name as user_name',
                'u.email as user_email',
            ]);

        if ($type && $type !== 'all') {
            $query->where('cr.type', $type);
        } else {
            // 僅顯示 support 與 dispute 兩類
            $query->whereIn('cr.type', ['support', 'dispute']);
        }

        if ($status) {
            $query->where('se.status', $status);
        }

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('se.title', 'LIKE', "%{$search}%")
                  ->orWhere('u.name', 'LIKE', "%{$search}%")
                  ->orWhere('u.email', 'LIKE', "%{$search}%");
            });
        }

        $total = $query->count();
        $items = $query->orderBy('se.updated_at', 'desc')
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->get();

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
            ],
        ]);
    }

    /** POST /admin/support/issues/{roomId}/accept (claim) */
    public function accept(Request $request, $roomId)
    {
        $adminId = $request->user()->id;
        $exists = DB::table('chat_rooms')->where('id', $roomId)->exists();
        if (!$exists) {
            return response()->json(['success' => false, 'message' => 'Room not found'], 404);
        }

        DB::table('support_events')
            ->where('chat_room_id', $roomId)
            ->update([
                'admin_id' => $adminId,
                'status' => 'in_progress',
                'updated_at' => now(),
            ]);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'support_claim',
            'table_name' => 'chat_rooms',
            'record_id' => $roomId,
            'old_data' => json_encode(['status' => 'open']),
            'new_data' => json_encode(['status' => 'in_progress', 'assignee_admin_id' => $adminId]),
            'created_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Issue claimed']);
    }

    /** POST /admin/support/issues/{roomId}/transfer */
    public function transfer(Request $request, $roomId)
    {
        $validator = Validator::make($request->all(), [
            'target_admin_id' => 'required|integer',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $adminId = $request->user()->id;
        $targetId = (int)$request->get('target_admin_id');
        $exists = DB::table('chat_rooms')->where('id', $roomId)->exists();
        if (!$exists) {
            return response()->json(['success' => false, 'message' => 'Room not found'], 404);
        }

        DB::table('support_events')
            ->where('chat_room_id', $roomId)
            ->update([
                'admin_id' => $targetId,
                'updated_at' => now(),
            ]);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'support_transfer',
            'table_name' => 'chat_rooms',
            'record_id' => $roomId,
            'old_data' => json_encode(['assignee_admin_id' => $adminId]),
            'new_data' => json_encode(['assignee_admin_id' => $targetId]),
            'created_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Issue transferred']);
    }

    /** POST /admin/support/issues/{roomId}/status */
    public function updateStatus(Request $request, $roomId)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:open,in_progress,waiting_customer,resolved,closed',
        ]);
        if ($validator->fails()) {
            return response()->json(['success' => false, 'message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $adminId = $request->user()->id;
        $newStatus = $request->get('status');
        $event = DB::table('support_events')->where('chat_room_id', $roomId)->first();
        if (!$event) {
            return response()->json(['success' => false, 'message' => 'Event not found'], 404);
        }

        DB::table('support_events')
            ->where('chat_room_id', $roomId)
            ->update([
                'status' => $newStatus,
                'updated_at' => now(),
            ]);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'support_status_update',
            'table_name' => 'chat_rooms',
            'record_id' => $roomId,
            'old_data' => json_encode(['status' => $event->status]),
            'new_data' => json_encode(['status' => $newStatus]),
            'created_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Status updated']);
    }
}


