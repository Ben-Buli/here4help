<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Log;

/*
|--------------------------------------------------------------------------
| Admin 測試路由 (/admintest/*)
|--------------------------------------------------------------------------
| 這些路由是為了測試 Laravel 是否正常運作，避免被前端 Vue SPA 吃掉。
|--------------------------------------------------------------------------
*/

Route::prefix('admintest')->group(function () {
    // 健康檢查
    Route::get('/ping', function () {
        return response()->json([
            'pong' => true,
            'time' => now(),
        ]);
    });

    // 基本測試
    Route::get('/test', function () {
        return response()->json([
            'check' => 'Laravel OK',
            'time' => now(),
        ]);
    });

    // 測試 log 寫入
    Route::get('/log', function () {
        Log::error('測試 log 寫入成功 at ' . now());
        return response()->json(['log' => 'ok']);
    });

    // 測試 view
    Route::get('/view', function () {
        return view('test'); // 確認 resources/views/test.blade.php 存在
    });

    // phpinfo
    Route::get('/phpinfo', function () {
        ob_start();
        phpinfo();
        $phpinfo = ob_get_clean();
        return response($phpinfo)->header('Content-Type', 'text/html');
    });
});

/*
|--------------------------------------------------------------------------
| Admin 前端路由 (Vue.js SPA)
|--------------------------------------------------------------------------
| Vue.js 會接管前端路由，Laravel 只需要回傳同一個入口檔。
|--------------------------------------------------------------------------
*/
Route::prefix('admin')->group(function () {
    Route::get('/{any?}', function () {
        // 直接回傳打包後的 SPA 入口檔，避免找不到 app.blade.php
        $indexPath = public_path('index.html');
        if (!file_exists($indexPath)) {
            abort(500, 'SPA index.html not found. Please run build_admin_frontend.sh first.');
        }
        return response()->file($indexPath);
    })->where('any', '.*');
});
