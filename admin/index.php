<?php
use Illuminate\Contracts\Http\Kernel;
use Illuminate\Http\Request;
require_once __DIR__ . '/../backend/utils/Response.php';

set_exception_handler(function ($e) {
    Response::serverError('Unhandled exception: ' . $e->getMessage());
});

set_error_handler(function ($errno, $errstr, $errfile, $errline) {
    Response::serverError("PHP error: $errstr in $errfile:$errline");
});

// /home/hero4helpdemofhs/public_html/admin/index.php

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/storage/framework/maintenance.php')) {
    require $maintenance;
}

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';

$kernel = $app->make(Kernel::class);

$response = $kernel->handle(
    $request = Request::capture()
)->send();

$kernel->terminate($request, $response);