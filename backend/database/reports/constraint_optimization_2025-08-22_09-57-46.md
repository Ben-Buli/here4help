# 外鍵約束與索引最佳化報告

**分析日期**: 2025-08-22 09:57:46
**資料庫**: hero4helpdemofhs_hero4help

## 📊 摘要

| 優先級 | 問題數量 |
|--------|----------|
| 高 | 37 |
| 中 | 1 |
| 低 | 21 |
| **總計** | **59** |

## 🚨 發現的問題

### 1. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: admin_role_permissions
- **欄位**: role_id

### 2. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: application_questions
- **欄位**: task_id

### 3. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: chat_rooms
- **欄位**: creator_id

### 4. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: chat_rooms
- **欄位**: participant_id

### 5. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: chat_rooms
- **欄位**: task_id

### 6. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: discarded_support_chat_messages
- **欄位**: chat_room_id

### 7. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: discarded_support_chat_rooms
- **欄位**: user_id

### 8. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: dispute_chats
- **欄位**: task_id

### 9. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: dispute_chats
- **欄位**: user_id

### 10. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: dispute_status_logs
- **欄位**: dispute_id

### 11. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: email_verification_tokens
- **欄位**: user_id

### 12. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: point_deposit_requests
- **欄位**: user_id

### 13. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: referral_codes
- **欄位**: user_id

### 14. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: referral_events
- **欄位**: referrer_id

### 15. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: service_chats
- **欄位**: user_id

### 16. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: student_verifications
- **欄位**: user_id

### 17. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: support_event_logs
- **欄位**: event_id

### 18. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: support_events
- **欄位**: chat_room_id

### 19. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: support_events
- **欄位**: user_id

### 20. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_applications
- **欄位**: task_id

### 21. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_applications
- **欄位**: user_id

### 22. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_dispute_chat_messages
- **欄位**: chat_room_id

### 23. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_dispute_chat_rooms
- **欄位**: user_id

### 24. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_disputes
- **欄位**: task_id

### 25. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_disputes
- **欄位**: user_id

### 26. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_ratings
- **欄位**: rater_id

### 27. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_ratings
- **欄位**: task_id

### 28. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_reports
- **欄位**: reporter_id

### 29. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_reports
- **欄位**: task_id

### 30. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: task_status_logs_legacy_20250820
- **欄位**: task_id

### 31. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: user_identities
- **欄位**: user_id

### 32. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: user_point_reviews
- **欄位**: user_id

### 33. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: user_tokens
- **欄位**: user_id

### 34. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: user_verification_rejections
- **欄位**: admin_id

### 35. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: user_verification_rejections
- **欄位**: user_id

### 36. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: verification_rejections
- **欄位**: admin_id

### 37. 🔴 CASCADE DELETE 可能造成意外的數據刪除

- **類型**: dangerous_cascade_delete
- **嚴重程度**: high
- **表格**: verification_rejections
- **欄位**: user_id

### 38. 🟡 缺失外鍵約束

- **類型**: missing_foreign_key
- **嚴重程度**: medium
- **表格**: tasks
- **欄位**: status_id

### 39. 🟢 常用查詢欄位建議添加索引

- **類型**: missing_query_index
- **嚴重程度**: low
- **表格**: task_applications
- **欄位**: status

### 40. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: admins

### 41. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: admins

### 42. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: languages

### 43. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: orders

### 44. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: referral_codes

### 45. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: tasks

### 46. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: universities

### 47. 🟢 重複索引浪費存儲空間

- **類型**: duplicate_index
- **嚴重程度**: low
- **表格**: user_tokens

### 48. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: languages

### 49. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: chat_rooms

### 50. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: tasks

### 51. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: universities

### 52. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: tasks_backup

### 53. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: admin_login_logs

### 54. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: admin_activity_logs

### 55. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: student_verifications

### 56. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: service_chats

### 57. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: orders

### 58. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: admins

### 59. 🟢 索引大小相對於數據過大，可能有冗餘索引

- **類型**: oversized_indexes
- **嚴重程度**: low
- **表格**: user_identities

## 🔧 最佳化計劃

### 1. 🟡 添加外鍵約束: tasks.status_id

- **表格**: tasks
- **風險等級**: medium
- **SQL**: 
```sql
ALTER TABLE `tasks` ADD CONSTRAINT `fk_tasks_status_id` FOREIGN KEY (`status_id`) REFERENCES `task_statuses`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
```

### 2. 🟢 為常用查詢欄位添加索引: task_applications.status

- **表格**: task_applications
- **風險等級**: low
- **SQL**: 
```sql
CREATE INDEX `idx_task_applications_status` ON `task_applications`(`status`);
```

### 3. 🟢 刪除重複索引: admins.email

- **表格**: admins
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `email` ON `admins`;
```

### 4. 🟢 刪除重複索引: admins.idx_username

- **表格**: admins
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `idx_username` ON `admins`;
```

### 5. 🟢 刪除重複索引: languages.code

- **表格**: languages
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `code` ON `languages`;
```

### 6. 🟢 刪除重複索引: orders.idx_order_number

- **表格**: orders
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `idx_order_number` ON `orders`;
```

### 7. 🟢 刪除重複索引: referral_codes.idx_referral_code

- **表格**: referral_codes
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `idx_referral_code` ON `referral_codes`;
```

### 8. 🟢 刪除重複索引: tasks.idx_acceptor_id

- **表格**: tasks
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `idx_acceptor_id` ON `tasks`;
```

### 9. 🟢 刪除重複索引: universities.abbr

- **表格**: universities
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `abbr` ON `universities`;
```

### 10. 🟢 刪除重複索引: user_tokens.idx_token

- **表格**: user_tokens
- **風險等級**: low
- **SQL**: 
```sql
DROP INDEX `idx_token` ON `user_tokens`;
```

## 📋 建議

1. **備份資料庫**: 在執行任何最佳化之前，請先完整備份資料庫
2. **測試環境**: 先在測試環境執行最佳化腳本
3. **分階段執行**: 按優先級分階段執行最佳化
4. **監控性能**: 最佳化後監控查詢性能變化
5. **定期檢查**: 建議每季度執行一次約束和索引分析

