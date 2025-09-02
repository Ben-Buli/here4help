# 客服聊天室模組以及案件進度頁面


客服聊天室的 會以資料表 chat_rooms.type = support 區分客服聊天室
Type = application 是app內部任務相關而建裡的聊天室類別

## Admin Web （Vue＋Laravel):
架構 客服案件列表table >  每一則項目點擊進去後進入該案件的 聊天室`chat_rooms` 
support_events.room_id = chat_rooms.id

support_events.status =‘open’代表使用者剛從應用程式成立此案件，
support_events.admin_id 預設為空，代表尚未有管理員接手處理，
所以在客服案件列表table新增一個action欄位，[detail, 經手(英文)] 管理員可以透過detail 出現懸浮視窗顯示該客服案件詳細的id, user跟客服項目描述，只有點擊經手按鈕，才會進入該support_events.room_id ，流程是點擊經手，二次確認詢問”是否成為此案件的處理人員？（英文）“，同意後會在跑loading 
等待以下客服案件接手執行步驟完成或是過時解除loading
1. support_events.admin_id 寫入管理員id, 
2. status => ‘in_progress’, 
3. chat_rooms.id 新增participant_id (=admin_id)
4. `support_events_logs`寫入事件狀態、

客服案件列表`support_events`資料表取得所有客服相關案件紀錄
`support_events_logs`負責記錄管理員和使用者在此案件的相關行為紀錄

網頁的客服聊天室和我的 /chat/detail 任務聊天室的基本介面架構一致，包含appbar 
聊天氣泡訊息區塊，左側（他方訊息）包含頭像、跟氣泡訊息;右側，我方訊息（僅有氣泡訊息） 如果support_events.status為 solved則經手的管理員可以進入聊天室但沒有傳圖片、傳訊息的功能，該ui disable

上傳圖片邏輯（包含托盤）、訊息傳送、action bar收縮功能
客服的action bar只有 issue status 一個按鈕，點擊後會顯示dialog，顯示 該任務的進度條 submitted -> in progress -> solved  三個階段的連結進度條（ Stepper 或 Timeline），執行到對應的進度的時候讓進度條的UI配色到該位置，並且三個階段如果有`support_events_logs.created_at`紀錄的時間戳記，則顯示在該幾段的名稱下面

## flutter app 使用者申請客服需求的管道
/issue-status改用tabs呈現 
task_dispute_events(clone `support_events`結構) 跟 support_events兩個表的列表，每一個案件項目則顯示案件編號、timeline，只顯示status in (submitted, in_progress)不顯示solved狀態案件 
/contac-us頁面，如果沒有任何項目則顯示沒有執行中的項目，該頁面放一個support_events建立的按鈕，點擊後出現對應欄位的問題表單，成功完成可以建立客服事件（也會在support_event_logs寫入紀錄），但是該頁面限制最多三則同時 support_events.status in (submitted, in_progress) 達到上限的時候無法新增support事件，使用者可以在客服項目點擊進去的聊天室，action bar有可以點擊按鈕 將案件狀態轉為solved,  solved狀態的  submitted狀態的時候需要幫我檢查是否該聊天室有聊天對像 support_chat_rooms.participant_id 可能為空，因為客服案件尚未有管理員接手執行，所需要有對應的等待管理員接手的訊息

/issue-status 分頁中的 任務爭議進度列表
主要採用
task_dispute_events, task_dispute_event_logs 這些資料的來源: /chat/detail action bar action ‘dispute’按鈕 幫我將dispute按鈕對齊task_dispute_events欄位產生對應的任務爭議說明表單，當使用者填寫該表單後會在task_dispute_event_logs同步寫入該任務爭議事件建立的資料，並且在dispute按鈕成功建立案件之後，該聊天室的雙方點擊dispute按鈕會顯示該案件成立的進度timeline以及案件編號，說明可以去/issue-stauts頁面查看，另外dispute案件一旦成立成功，就會將該聊天室的狀態轉換成 tasks.status_id = task_statuses = ‘dispute’的狀態  在管理員後台需要一個頁面是爭議任務列表，包含提案人的users.id，爭議事件編號(task_dispute_events.id)、爭議任務列表table最後一欄位為action, 包含 兩個按鈕[’room’, ‘  opperation]
Opperation會出現dialog 包含兩個項目 包含管理員的決策結果(status)跟決策說明(description)
決策結果有三種方式
1. 此任務當作完成 tasks.status_id =5，直接走結案並且轉移點數跟扣除額外手續費（執行對應api)
2. 此任務視為尚未完成 task.status_id = 2(in progress)回到進行中狀態
3. 此任務重置，task.status_id = 1，移除現有的任務執行者tasks.participant_id = null, 原本的執行者 task_application會轉為task_applications.status = ‘cancelled’
 結構相同但用於不同頁面的資料表

任務聊天室 ｜ 客服聊天室
chat_rooms | support_chat_rooms
chat_reads | support_chat_reads
chat_messages | support_chat_messages

以下為 結構類似，用於不同頁面的資料表 客服事件及紀錄 ｜ 任務爭議狀態事件及紀錄
support_events｜task_dispute_events
support_event_logs｜task_dispute_event_logs


現有資料結構
    docs/優先執行/客服聊天模組及任務爭議(Dispute)模組需求說明.sql
