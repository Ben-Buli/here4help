<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('point_withdraw_requests', function (Blueprint $table) {
            $table->id()->comment('主鍵');
            $table->unsignedBigInteger('user_id')->comment('申請人（users.id）');
            $table->unsignedInteger('amount_points')->comment('使用者欲提領點數');
            $table->decimal('fee_rate', 6, 4)->comment('手續費率快照');
            $table->unsignedInteger('fee_points')->comment('手續費點數');
            $table->unsignedInteger('total_deduct_points')->comment('實際凍結/扣除點數（提領+手續費）');
            $table->unsignedInteger('net_payout_points')->comment('實際匯出點數（提領）');
            $table->enum('status', ['pending', 'approved', 'rejected', 'cancelled', 'paid'])
                ->default('pending')
                ->comment('申請狀態');
            $table->unsignedBigInteger('admin_id')->nullable()->comment('處理管理員（admins.id）');
            $table->string('admin_reply', 500)->nullable()->comment('管理員回覆訊息');
            $table->timestamp('reviewed_at')->nullable()->comment('審核時間');
            $table->timestamp('paid_at')->nullable()->comment('完成打款時間');
            $table->timestamp('cancelled_at')->nullable()->comment('取消時間');
            $table->timestamps();
            $table->comment('點數提領申請');

            $table->index('user_id');
            $table->index('status');
            $table->index(['user_id', 'status', 'created_at']);
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('point_withdraw_requests');
    }
};
