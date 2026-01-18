<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 將 record_id 從 INT 改為 VARCHAR(36) 以支援 UUID 格式
     */
    public function up(): void
    {
        // 使用原生 SQL 修改欄位類型，保留現有資料
        DB::statement('ALTER TABLE admin_activity_logs MODIFY COLUMN record_id VARCHAR(36) NULL COMMENT "操作資料ID (支援整數和UUID)"');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // 還原為 INT 類型（注意：如果有 UUID 資料會被截斷）
        DB::statement('ALTER TABLE admin_activity_logs MODIFY COLUMN record_id INT NULL COMMENT "操作資料ID"');
    }
};
