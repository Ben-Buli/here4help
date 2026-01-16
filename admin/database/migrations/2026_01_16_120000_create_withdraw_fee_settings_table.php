<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('withdraw_fee_settings', function (Blueprint $table) {
            $table->id()->comment('主鍵');
            $table->decimal('rate', 6, 4)->comment('提領手續費率，0.1500 = 15%');
            $table->string('description')->nullable()->comment('設定說明');
            $table->boolean('is_active')->default(true)->comment('是否啟用（單一啟用）');
            $table->unsignedBigInteger('updated_by')->nullable()->comment('更新者管理員 ID');
            $table->timestamps();
            $table->comment('提領手續費設定');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('withdraw_fee_settings');
    }
};
