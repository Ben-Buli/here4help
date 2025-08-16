meta:
  purpose: 聊天室列表 + 未讀訊息設計完整規格
  focus: 欄位來源 / API 對應 / 更新策略
  note: 不含程式碼，專注邏輯與資料對應

entities:
  room:
    source: chat_rooms(id, task_id, creator_id, participant_id, type, created_at,…)
    desc: 1v1 聊天室
  message:
    source: chat_messages(id, room_id, from_user_id, content, created_at, kind,…)
    desc: 訊息記錄（id 自增即時間序）
  read_pointer:
    source: chat_reads(user_id, room_id, last_read_message_id, updated_at)
    unique: (user_id, room_id)
    desc: 已讀指標，每人每房一筆，只前進不後退
  user:
    source: users(id, name, avatar_url,…)
    desc: 聊天對象資訊
  task:
    source: tasks(id, title, creator_id, status_id, updated_at,…)
    desc: 可用於排序/篩選

roles:
  posted: 我=creator, 對方=participant
  myworks: 我=participant, 對方=creator
  global:
    conservative: 對方=from_user_id ≠ 我
    strict: 依房間角色判斷

unread_rule:
  condition:
    - from_user_id=對方
    - message.id > my.last_read_message_id(room)
    - 若無紀錄 → last_read_message_id=0

update_strategy:
  refresh:
    - condition_based: 只有搜尋/篩選/排序變化時刷新
    - delayed: addPostFrameCallback 避免 build 重刷
    - state_check: 更新前檢查 Provider 狀態是否變動
  persistence:
    - prefer_local: 優先讀本地快取
    - auto_save: API 成功回寫本地
    - incremental: 僅更新差異
  load:
    - first_load: 本地+API 全量
    - revisit: 本地快取，背景檢查 API
    - realtime: WebSocket（或輪詢）同步未讀

apis:
  get_unreads:
    method: GET
    path: /api/chat/unreads?scope=posted|myworks|all
    fields:
      total: sum(by_room[*])
      by_room: map(room_id→unread_count)
      scope: 查詢參數
      method: room_based_via_last_read_pointer
    note: 計算需 messages.id vs reads.last_read_message_id
  mark_read:
    method: POST
    path: /api/chat/rooms/{roomId}/read
    fields:
      room_id: 驗證呼叫者屬房
      last_read_message_id: max(現有, 最新訊息 id)
      unread_count: 0
      read_time: chat_reads.updated_at
      method: mark_read_to_latest
  get_rooms:
    method: GET
    path: /api/chat/rooms?scope=posted|myworks&with_unread=1
    fields:
      room_id: chat_rooms.id
      task_id: chat_rooms.task_id
      counterpart_user: users (依 scope 判斷)
      last_message: chat_messages(最後一則)
      unread_count: 計算同 get_unreads
      updated_at: last_message.created_at
  get_messages:
    method: GET
    path: /api/chat/rooms/{roomId}/messages?before_id=&after_id=&limit=
    fields:
      messages[]: chat_messages
      last_read_message_id: chat_reads
      can_load_older: 是否有更舊訊息
      can_load_newer: 是否有更新訊息
  get_total_unread:
    method: GET
    path: /api/chat/unreads/total
    fields:
      total_unread: 對方訊息且 id > 我的 last_read_message_id

websocket:
  events:
    - message.created:
        room_id: chat_messages.room_id
        payload: id, from_user_id, content, created_at, kind
    - room.read:
        room_id: chat_reads.room_id
        payload: user_id, last_read_message_id, read_time
    - unread.updated (optional):
        room_id: 更新後的未讀數

indexes:
  chat_reads: (user_id, room_id) UNIQUE
  chat_messages: (room_id, id), (room_id, from_user_id, id)
  chat_rooms: (creator_id), (participant_id), (task_id)

usage_guidelines:
  - 顯示列表：用 get_rooms
  - 只要 badge：用 get_unreads
  - 進房清零：用 mark_read
  - 全域紅點：用 get_total_unread
  - 對話頁「已讀線」：用 get_messages.last_read_message_id 判斷