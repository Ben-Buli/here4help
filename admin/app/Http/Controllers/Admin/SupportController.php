<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
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
        
        // 獲取當前管理員 ID
        $adminId = $request->user()->id;

        $query = DB::table('support_chat_rooms as cr')
            ->leftJoin('support_events as se', 'se.support_chat_room_id', '=', 'cr.id')
            ->leftJoin('users as u', 'cr.user_id', '=', 'u.id')
            ->leftJoin('admins as a', 'cr.admin_id', '=', 'a.id')
            ->select([
                'cr.id as room_id',
                'cr.type',
                'cr.user_id',
                'cr.admin_id',
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
                'a.id as admin_id',
                'a.full_name as admin_name',
                'a.email as admin_email',
            ]);

        // Issues 頁面顯示所有 support_events，不過濾管理員

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

    /**
     * GET /admin/support/chat-rooms
     * 顯示當前管理員負責的聊天室列表
     */
    public function chatRooms(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
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
        $status = $request->get('status');
        $search = $request->get('search');
        
        // 獲取當前管理員 ID
        $adminId = $request->user()->id;

        $query = DB::table('support_chat_rooms as cr')
            ->leftJoin('support_events as se', 'se.support_chat_room_id', '=', 'cr.id')
            ->leftJoin('users as u', 'cr.user_id', '=', 'u.id')
            ->select([
                'cr.id as room_id',
                'cr.type',
                'cr.user_id',
                'cr.admin_id',
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
                'u.avatar_url as user_avatar_url',
            ]);

        // 🔥 關鍵：只顯示當前管理員負責的聊天室
        $query->where('cr.admin_id', $adminId);

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

    /**
     * GET /admin/support/chat-rooms/{roomId}
     * 獲取單個聊天室詳情
     */
    public function getChatRoom(Request $request, $roomId)
    {
        $adminId = $request->user()->id;

        $query = DB::table('support_chat_rooms as cr')
            ->leftJoin('support_events as se', 'se.support_chat_room_id', '=', 'cr.id')
            ->leftJoin('users as u', 'cr.user_id', '=', 'u.id')
            ->leftJoin('admins as a', 'cr.admin_id', '=', 'a.id')
            ->select([
                'cr.id as room_id',
                'cr.type',
                'cr.user_id',
                'cr.admin_id',
                'cr.created_at',
                'se.id as event_id',
                'se.title',
                'se.status',
                'se.admin_id as assignee_admin_id',
                'se.created_at as event_created_at',
                'se.updated_at as last_message_at',
                'u.id as user_id',
                'u.name as user_name',
                'u.nickname as user_nickname',
                'u.email as user_email',
                'u.avatar_url as user_avatar_url',
                'a.id as admin_id',
                'a.full_name as admin_name',
                'a.email as admin_email',
            ])
            ->where('cr.id', $roomId);

        // 檢查權限：只有負責該聊天室的管理員或超級管理員可以查看
        $room = $query->first();
        
        if (!$room) {
            return response()->json(['success' => false, 'message' => 'Chat room not found'], 404);
        }

        // 檢查權限：只有負責該聊天室的管理員可以查看
        if ($room->admin_id && $room->admin_id != $adminId) {
            return response()->json(['success' => false, 'message' => 'Access denied'], 403);
        }

        return response()->json([
            'success' => true,
            'data' => $room,
        ]);
    }

    /**
     * GET /admin/support/chat-rooms/{roomId}/messages
     * 獲取聊天室訊息
     */
    public function getMessages(Request $request, $roomId)
    {
        $adminId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'limit' => 'integer|min:1|max:100',
            'before_id' => 'integer|min:1',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $limit = (int)$request->get('limit', 50);
        $beforeId = $request->get('before_id');

        // 檢查管理員是否有權限訪問此聊天室
        $room = DB::table('support_chat_rooms')
            ->where('id', $roomId)
            ->where('admin_id', $adminId)
            ->first();

        if (!$room) {
            return response()->json(['success' => false, 'message' => 'Chat room not found or access denied'], 404);
        }

        // 構建查詢條件
        $query = DB::table('support_chat_messages as scm')
            ->leftJoin('users as u', function($join) {
                $join->on('scm.user_id', '=', 'u.id')
                     ->where('scm.role', '=', 'user');
            })
            ->leftJoin('admins as a', function($join) {
                $join->on('scm.admin_id', '=', 'a.id')
                     ->where('scm.role', '=', 'admin');
            })
            ->select([
                'scm.id',
                'scm.room_id',
                'scm.user_id',
                'scm.admin_id',
                'scm.content',
                'scm.kind',
                'scm.role',
                'scm.media_url',
                'scm.mime_type',
                'scm.created_at',
                DB::raw('COALESCE(a.full_name, u.name) as sender_name'),
                DB::raw('COALESCE(u.avatar_url, NULL) as sender_avatar'),
                DB::raw("CASE WHEN scm.admin_id = {$adminId} THEN 1 ELSE 0 END as is_own")
            ])
            ->where('scm.room_id', $roomId)
            ->orderBy('scm.created_at', 'desc');

        if ($beforeId) {
            $query->where('scm.id', '<', $beforeId);
        }

        $messages = $query->limit($limit)->get();

        // 反轉順序，讓最新的訊息在最後
        $messages = $messages->reverse()->values();

        // 獲取未讀訊息數量
        $unreadCount = DB::table('support_chat_messages as scm')
            ->leftJoin('support_chat_reads as scr', function($join) use ($adminId) {
                $join->on('scm.room_id', '=', 'scr.room_id')
                     ->where('scr.admin_id', '=', $adminId)
                     ->where('scr.role', '=', 'admin');
            })
            ->where('scm.room_id', $roomId)
            ->where('scm.role', '=', 'user')
            ->whereRaw('scm.id > COALESCE(scr.last_read_message_id, 0)')
            ->count();

        return response()->json([
            'success' => true,
            'data' => [
                'messages' => $messages,
                'unread_count' => $unreadCount,
                'has_more' => $messages->count() === $limit,
            ],
        ]);
    }

    /**
     * POST /admin/support/chat-rooms/{roomId}/messages
     * 發送訊息
     */
    public function sendMessage(Request $request, $roomId)
    {
        $adminId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'content' => 'required|string|max:2000',
            'kind' => 'string|in:text,image,system',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $content = $request->get('content');
        $kind = $request->get('kind', 'text');

        // 檢查管理員是否有權限訪問此聊天室
        $room = DB::table('support_chat_rooms')
            ->where('id', $roomId)
            ->where('admin_id', $adminId)
            ->first();

        if (!$room) {
            return response()->json(['success' => false, 'message' => 'Chat room not found or access denied'], 404);
        }

        DB::beginTransaction();
        
        try {
            // 插入訊息
            $messageId = DB::table('support_chat_messages')->insertGetId([
                'room_id' => $roomId,
                'admin_id' => $adminId,
                'user_id' => null,
                'content' => $content,
                'kind' => $kind,
                'role' => 'admin',
                'created_at' => now(),
            ]);

            // 更新已讀記錄（管理員使用 admin_id，user_id 為 NULL）
            DB::table('support_chat_reads')->updateOrInsert(
                ['admin_id' => $adminId, 'room_id' => $roomId, 'role' => 'admin'],
                ['last_read_message_id' => $messageId, 'admin_id' => $adminId, 'updated_at' => now()]
            );

            DB::commit();

            // 發送 Socket 通知
            $this->sendSocketMessage($roomId, $messageId, $adminId, $content, $kind);

            return response()->json([
                'success' => true,
                'data' => [
                    'message_id' => $messageId,
                    'content' => $content,
                    'kind' => $kind,
                    'created_at' => now()->toISOString(),
                ],
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Send message error: ' . $e->getMessage());
            return response()->json(['success' => false, 'message' => 'Failed to send message'], 500);
        }
    }

    /**
     * POST /admin/support/chat-rooms/{roomId}/read
     * 標記訊息為已讀
     */
    public function markAsRead(Request $request, $roomId)
    {
        $adminId = $request->user()->id;
        
        $validator = Validator::make($request->all(), [
            'message_id' => 'required|integer|min:1',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $messageId = $request->get('message_id');

        // 檢查管理員是否有權限訪問此聊天室
        $room = DB::table('support_chat_rooms')
            ->where('id', $roomId)
            ->where('admin_id', $adminId)
            ->first();

        if (!$room) {
            return response()->json(['success' => false, 'message' => 'Chat room not found or access denied'], 404);
        }

        // 更新已讀記錄（管理員使用 admin_id，user_id 為 NULL）
        DB::table('support_chat_reads')->updateOrInsert(
            ['admin_id' => $adminId, 'room_id' => $roomId, 'role' => 'admin'],
            ['last_read_message_id' => $messageId, 'admin_id' => $adminId, 'updated_at' => now()]
        );

        return response()->json([
            'success' => true,
            'data' => [
                'message_id' => $messageId,
                'read_at' => now()->toISOString(),
            ],
        ]);
    }

    /** POST /admin/support/issues/{roomId}/accept (claim) */
    public function accept(Request $request, $roomId)
    {
        $adminId = $request->user()->id;
        
        // 開始資料庫事務
        DB::beginTransaction();
        
        try {
            // 1. 驗證聊天室存在且為支援類型
            $room = DB::table('support_chat_rooms')
                ->where('id', $roomId)
                ->where('type', 'support')
                ->first();
                
            if (!$room) {
                return response()->json(['success' => false, 'message' => 'Support chat room not found'], 404);
            }
            
            // 2. 檢查是否已被其他管理員接手
            if (!empty($room->admin_id) && $room->admin_id != $adminId) {
                return response()->json(['success' => false, 'message' => 'This support case has already been claimed by another admin'], 409);
            }
            
            // 3. 獲取該聊天室的最新事件
            $latestEvent = DB::table('support_events')
                ->where('support_chat_room_id', $roomId)
                ->orderBy('created_at', 'desc')
                ->first();
                
            if (!$latestEvent) {
                return response()->json(['success' => false, 'message' => 'No support event found for this room'], 404);
            }
            
            // 4. 檢查事件是否已結案
            
            if ($latestEvent->status === 'resolved') {
                return response()->json(['success' => false, 'message' => 'Cannot claim a resolved support case'], 400);
            }
            
            // 5. 檢查是否已被同一管理員接手
            if ($latestEvent->admin_id == $adminId && $latestEvent->status === 'in_progress') {
                return response()->json(['success' => false, 'message' => 'You have already claimed this support case'], 400);
            }
            
            $eventId = $latestEvent->id;
            $oldStatus = $latestEvent->status;
            
            // 6. 更新事件：設定管理員ID和狀態
            DB::table('support_events')
                ->where('id', $eventId)
                ->update([
                    'admin_id' => $adminId,
                    'status' => 'in_progress',
                    'updated_at' => now()
                ]);
            
            // 7. 更新聊天室：設定參與者為管理員
            DB::table('support_chat_rooms')
                ->where('id', $roomId)
                ->update(['admin_id' => $adminId]);
            
            // 8. 新增事件日誌
            DB::table('support_event_logs')->insert([
                'event_id' => $eventId,
                'admin_id' => $adminId,
                'old_status' => $oldStatus,
                'new_status' => 'in_progress',
                'created_at' => now()
            ]);
            
            // 9. 插入系統訊息通知客戶
            $systemMessage = "Admin has joined the chat and is now handling your support case.";
            DB::table('support_chat_messages')->insert([
                'room_id' => $roomId,
                'admin_id' => $adminId,
                'user_id' => null,
                'content' => $systemMessage,
                'kind' => 'system',
                'role' => 'admin',
                'created_at' => now()
            ]);
            
            // 10. 記錄管理員操作日誌
            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => 'support_claim',
                'table_name' => 'support_chat_rooms',
                'record_id' => $roomId,
                'old_data' => json_encode(['status' => $oldStatus]),
                'new_data' => json_encode(['status' => 'in_progress', 'assignee_admin_id' => $adminId]),
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
                'created_at' => now(),
            ]);
            
            // 提交事務
            DB::commit();
            
            // 11. 觸發 Socket 事件通知
            $this->sendSocketNotification($roomId, $eventId, $oldStatus, 'in_progress', $adminId);
            
            return response()->json([
                'success' => true,
                'data' => [
                    'room_id' => (string)$roomId,
                    'event_id' => (string)$eventId,
                    'admin_id' => (string)$adminId,
                    'status' => 'in_progress',
                    'old_status' => $oldStatus,
                    'message' => 'Support case claimed successfully',
                    'redirect_url' => '/support-chat-list?room_id=' . $roomId
                ]
            ]);
            
        } catch (\Exception $e) {
            // 回滾事務
            DB::rollBack();
            Log::error('Support Claim Error: ' . $e->getMessage());
            return response()->json(['success' => false, 'message' => 'Internal server error: ' . $e->getMessage()], 500);
        }
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
            ->where('support_chat_room_id', $roomId)
            ->update([
                'admin_id' => $targetId,
                'updated_at' => now(),
            ]);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'support_transfer',
            'table_name' => 'support_chat_rooms',
            'record_id' => $roomId,
            'old_data' => json_encode(['assignee_admin_id' => $adminId]),
            'new_data' => json_encode(['assignee_admin_id' => $targetId]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
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
        $event = DB::table('support_events')->where('support_chat_room_id', $roomId)->first();
        if (!$event) {
            return response()->json(['success' => false, 'message' => 'Event not found'], 404);
        }

        DB::table('support_events')
            ->where('support_chat_room_id', $roomId)
            ->update([
                'status' => $newStatus,
                'updated_at' => now(),
            ]);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'support_status_update',
            'table_name' => 'support_chat_rooms',
            'record_id' => $roomId,
            'old_data' => json_encode(['status' => $event->status]),
            'new_data' => json_encode(['status' => $newStatus]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now(),
        ]);

        return response()->json(['success' => true, 'message' => 'Status updated']);
    }
    
    /**
     * POST /admin/support/upload-image
     * 管理員上傳圖片到客服聊天室
     */
    public function uploadImage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'room_id' => 'required|integer|min:1',
            'image' => 'required|image|mimes:png,jpg,jpeg,gif,webp|max:5120', // 5MB
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $adminId = $request->user()->id;
        $roomId = $request->get('room_id');

        // 檢查管理員是否有權限訪問此聊天室
        $room = DB::table('support_chat_rooms')
            ->where('id', $roomId)
            ->where('admin_id', $adminId)
            ->first();

        if (!$room) {
            return response()->json(['success' => false, 'message' => 'Chat room not found or access denied'], 404);
        }

        try {
            $file = $request->file('image');
            
            // 創建上傳目錄 - 使用與 PHP 後端相同的路徑
            $uploadDir = base_path('../backend/uploads/support_chat');
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0755, true);
            }
            
            // 生成唯一檔案名
            $fileName = uniqid('admin_support_') . '.' . $file->getClientOriginalExtension();
            $filePath = $uploadDir . '/' . $fileName;
            
            // 移動檔案
            $file->move($uploadDir, $fileName);
            
            // 生成公開路徑
            $publicPath = 'uploads/support_chat/' . $fileName;
            
            return response()->json([
                'success' => true,
                'data' => [
                    'filename' => $file->getClientOriginalName(),
                    'saved_as' => $fileName,
                    'path' => $publicPath,
                    'url' => $publicPath,
                    'size' => filesize($filePath), // 使用 filesize() 而不是 $file->getSize()
                    'mime_type' => $file->getMimeType()
                ]
            ], 'Image uploaded successfully');
            
        } catch (\Exception $e) {
            Log::error('Admin Support Image Upload Error: ' . $e->getMessage());
            return response()->json(['success' => false, 'message' => 'Failed to upload image'], 500);
        }
    }
    
    /**
     * 發送 Socket 事件通知
     */
    private function sendSocketNotification($chatRoomId, $eventId, $oldStatus, $newStatus, $adminId)
    {
        try {
            $socketUrl = 'http://localhost:3001/support/event/update';
            $socketData = [
                'chatRoomId' => $chatRoomId,
                'eventId' => $eventId,
                'oldStatus' => $oldStatus,
                'newStatus' => $newStatus,
                'adminId' => $adminId
            ];
            
            // 非阻塞式 Socket 通知
            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => 'Content-Type: application/json',
                    'content' => json_encode($socketData),
                    'timeout' => 1
                ]
            ]);
            
            @file_get_contents($socketUrl, false, $context);
        } catch (\Exception $e) {
            Log::error("Support Event Socket notification failed: " . $e->getMessage());
        }
    }

    /**
     * 發送 Socket 訊息通知
     */
    private function sendSocketMessage($roomId, $messageId, $fromUserId, $content, $kind)
    {
        try {
            $socketUrl = 'http://localhost:3001/support/message';
            $socketData = [
                'roomId' => (string)$roomId,
                'messageId' => $messageId,
                'fromUserId' => $fromUserId,
                'content' => $content,
                'kind' => $kind,
                'createdAt' => now()->toISOString(),
                // 保持向後兼容
                'room_id' => $roomId,
                'message_id' => $messageId,
                'from_user_id' => $fromUserId,
                'created_at' => now()->toISOString(),
            ];
            
            // 非阻塞式 Socket 通知
            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => 'Content-Type: application/json',
                    'content' => json_encode($socketData),
                    'timeout' => 1
                ]
            ]);
            
            @file_get_contents($socketUrl, false, $context);
        } catch (\Exception $e) {
            Log::error("Support Message Socket notification failed: " . $e->getMessage());
        }
    }
}


