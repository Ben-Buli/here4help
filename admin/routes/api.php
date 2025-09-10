<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Admin\TaskController;
use App\Http\Controllers\Admin\LogController;
use App\Http\Controllers\Admin\DisputeController;
use App\Http\Controllers\Admin\SupportController;
use App\Http\Controllers\Admin\PaymentController;
use App\Http\Controllers\Admin\UserActivityController;
use App\Http\Controllers\Admin\UserTransactionController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// 管理員認證路由（無需認證）
Route::prefix('admin')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    
    // 需要認證的路由
    Route::middleware(['auth:sanctum', 'admin'])->group(function () {
        // 認證相關
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/refresh', [AuthController::class, 'refresh']);
        
        // 用戶管理路由
        Route::prefix('users')->group(function () {
            Route::get('/', [UserController::class, 'index']);
            
            Route::middleware('admin:users.view')->group(function () {
                Route::get('/{id}', [UserController::class, 'show']);
                Route::get('/{id}/intro-referral-info', [UserController::class, 'introReferralInfo']);
                Route::get('/{id}/verification', [UserController::class, 'verification']);
            });
            
            Route::middleware('admin:users.edit')->group(function () {
                Route::patch('/{id}/status', [UserController::class, 'updateStatus']);
                Route::patch('/{id}/permission', [UserController::class, 'updatePermission']);
                Route::post('/batch-action', [UserController::class, 'batchAction']);
                Route::post('/{id}/review', [UserController::class, 'review']);
            });
        });
        
        // 任務管理路由
        Route::prefix('tasks')->group(function () {
            Route::middleware('admin:tasks.list')->group(function () {
                Route::get('/', [TaskController::class, 'index']);
            });
            
            Route::middleware('admin:tasks.view')->group(function () {
                Route::get('/{id}', [TaskController::class, 'show']);
            });
            
            Route::middleware('admin:tasks.edit')->group(function () {
                Route::patch('/{id}/status', [TaskController::class, 'updateStatus']);
            });
        });
        
        // 日誌管理路由
        Route::prefix('logs')->group(function () {
            Route::middleware('admin:logs.view')->group(function () {
                Route::get('/', [LogController::class, 'index']);
                Route::get('/activity', [LogController::class, 'activityLogs']);
                Route::get('/login', [LogController::class, 'loginLogs']);
                Route::get('/stats', [LogController::class, 'systemStats']);
            });
        });
        
        // 申訴管理路由
        Route::prefix('disputes')->group(function () {
            Route::middleware('admin:disputes.list')->group(function () {
                Route::get('/', [DisputeController::class, 'index']);
            });
            
            Route::middleware('admin:disputes.view')->group(function () {
                Route::get('/{id}', [DisputeController::class, 'show']);
            });
            
            Route::middleware('admin:disputes.edit')->group(function () {
                Route::patch('/{id}/status', [DisputeController::class, 'updateStatus']);
                Route::post('/batch-action', [DisputeController::class, 'batchAction']);
            });
        });

        // 客服/支援路由
        Route::prefix('support')->group(function () {
            Route::get('/issues', [SupportController::class, 'issues']);
            Route::post('/issues/{roomId}/accept', [SupportController::class, 'accept']);
            Route::post('/issues/{roomId}/transfer', [SupportController::class, 'transfer']);
            Route::post('/issues/{roomId}/status', [SupportController::class, 'updateStatus']);
        });

        // 支付/儲值路由
        Route::prefix('payment')->group(function () {
            Route::get('/requests', [PaymentController::class, 'requests']);
            Route::post('/requests/{id}/approve', [PaymentController::class, 'approve']);
            Route::post('/requests/{id}/reject', [PaymentController::class, 'reject']);
            Route::match(['get', 'post'], '/fee-settings', [PaymentController::class, 'feeSettings']);
            Route::match(['get', 'post'], '/official-accounts', [PaymentController::class, 'officialAccounts']);
        });

        // 使用者活動紀錄路由
        Route::prefix('user-activities')->group(function () {
            Route::middleware('admin:logs.view')->group(function () {
                Route::get('/', [UserActivityController::class, 'index']);
                Route::get('/{userId}', [UserActivityController::class, 'show']);
            });
        });

        // 使用者交易紀錄路由
        Route::prefix('user-transactions')->group(function () {
            Route::middleware('admin:logs.view')->group(function () {
                Route::get('/', [UserTransactionController::class, 'index']);
                Route::get('/{userId}', [UserTransactionController::class, 'show']);
            });
        });
        
        // 管理員管理路由（預留）
        Route::middleware('admin:admins.list')->group(function () {
            Route::get('/admins', function () {
                return response()->json(['message' => 'Admins management - coming soon']);
            });
        });
        
        // 系統資訊路由
        Route::get('/dashboard', function () {
            return response()->json([
                'message' => 'Admin dashboard data',
                'timestamp' => now(),
                'server_time' => now()->toDateTimeString(),
                'uptime' => 'System operational'
            ]);
        });
    });
});

// 測試路由（無需認證） 
Route::get('/test', function () {
    return response()->json([
        'message' => 'Admin API is working',
        'timestamp' => now(),
        'version' => '1.0.0'
    ]);
});
