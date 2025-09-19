<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Admin\TaskController;
use App\Http\Controllers\Admin\LogController;
use App\Http\Controllers\Admin\DisputeController;
use App\Http\Controllers\Admin\SupportController;
use App\Http\Controllers\Admin\PaymentController;
use App\Http\Controllers\Admin\UserActivityController;
use App\Http\Controllers\Admin\UserTransactionController;
use App\Http\Controllers\Admin\AdminPingController;

Route::prefix('admin')->group(function () {
    // 認證（無需 token）
    Route::post('/login', [AuthController::class, 'login']);


    Route::middleware(['auth:sanctum', 'admin'])->group(function () {
        // 認證
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/refresh', [AuthController::class, 'refresh']);

        // 用戶管理
        Route::prefix('users')->group(function () {
            Route::get('/', [UserController::class, 'index']);
            Route::get('/{id}', [UserController::class, 'show'])->middleware('admin:users.view');
            Route::patch('/{id}/status', [UserController::class, 'updateStatus'])->middleware('admin:users.edit');
        });

        // 任務管理
        Route::prefix('tasks')->group(function () {
            Route::get('/', [TaskController::class, 'index'])->middleware('admin:tasks.list');
            Route::get('/{id}', [TaskController::class, 'show'])->middleware('admin:tasks.view');
            Route::patch('/{id}/status', [TaskController::class, 'updateStatus'])->middleware('admin:tasks.edit');
        });

        // 日誌管理
        Route::get('/logs', [LogController::class, 'index'])->middleware('admin:logs.view');

        // 申訴管理
        Route::get('/disputes', [DisputeController::class, 'index'])->middleware('admin:disputes.list');

        // 客服
        Route::prefix('support')->group(function () {
            Route::get('/chat-rooms', [SupportController::class, 'chatRooms']);
            Route::post('/chat-rooms/{roomId}/messages', [SupportController::class, 'sendMessage']);
        });

        // 支付
        Route::prefix('payment')->group(function () {
            Route::get('/requests', [PaymentController::class, 'requests']);
            Route::post('/requests/{id}/approve', [PaymentController::class, 'approve']);
        });

        // 使用者活動 / 交易
        Route::get('/user-activities', [UserActivityController::class, 'index'])->middleware('admin:logs.view');
        Route::get('/user-transactions', [UserTransactionController::class, 'index'])->middleware('admin:logs.view');

        // 管理員列表 / 系統資訊
        Route::get('/admins', [AdminPingController::class, 'admins'])->middleware('admin:admins.list');
        Route::get('/dashboard', [AdminPingController::class, 'dashboard']);
    });
});