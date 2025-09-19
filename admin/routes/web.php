<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\WebController;

/*
|--------------------------------------------------------------------------
| Health Check / Ping
|--------------------------------------------------------------------------
| 這個路由用來測試 Laravel 是否運作正常
| 瀏覽 https://hero4help.demofhs.com/admin/ping
|--------------------------------------------------------------------------
*/
Route::get('/admin/ping', function () {
    return response()->json([
        'pong' => true,
        'time' => now()->toDateTimeString(),
        'app'  => config('app.name'),
        'env'  => config('app.env'),
    ]);
});

/*
|--------------------------------------------------------------------------
| Admin 前端路由 (Vue.js SPA)
|--------------------------------------------------------------------------
| Vue.js 會接管前端路由，Laravel 只需要回傳同一個入口檔。
| 注意：/admin/ping 已經在上面定義，這裡不會覆蓋它。
|--------------------------------------------------------------------------
*/
Route::prefix('admin')->group(function () {
    Route::get('/', [WebController::class, 'index']);
    Route::get('/login', [WebController::class, 'index']);
    Route::get('/dashboard', [WebController::class, 'index']);

    // Vue catch-all (必須放最後)
    Route::get('/{any}', [WebController::class, 'index'])->where('any', '.*');
});

/*
|--------------------------------------------------------------------------
| 根路由重定向 (已移除)
|--------------------------------------------------------------------------
| 原本會重定向到 /admin，但會與主站根目錄重定向衝突
| 已移除以避免路由衝突
|--------------------------------------------------------------------------
*/