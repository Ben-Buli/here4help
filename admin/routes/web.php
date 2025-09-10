<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// 添加登錄路由以解決認證中間件錯誤
Route::get('/login', function () {
    return response()->json(['message' => 'Please use API login endpoint'], 401);
})->name('login');
