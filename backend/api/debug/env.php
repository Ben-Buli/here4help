<?php
require_once __DIR__ . '/../bootstrap.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    Response::success(null, 'OK', 200);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Method not allowed');
}

EnvLoader::load();

$isDebug = EnvLoader::get('APP_DEBUG', 'false');
if (!EnvLoader::isDevelopment() && $isDebug !== 'true') {
    Response::forbidden('Debug endpoint is disabled');
}

$loadedPath = EnvLoader::getLoadedPath();

$username = EnvLoader::get('MAIL_USERNAME', '');
$maskedUsername = $username;
if ($username !== '' && strpos($username, '@') !== false) {
    $atPos = strpos($username, '@');
    $prefix = substr($username, 0, min(3, $atPos));
    $maskedUsername = $prefix . str_repeat('*', max(0, $atPos - strlen($prefix))) . substr($username, $atPos);
}

$data = [
    'loaded_env_path' => $loadedPath,
    'app_env' => EnvLoader::get('APP_ENV', 'development'),
    'app_debug' => $isDebug,
    'frontend_url' => EnvLoader::get('FRONTEND_URL', ''),
    'mail' => [
        'mailer' => EnvLoader::get('MAIL_MAILER', ''),
        'host' => EnvLoader::get('MAIL_HOST', ''),
        'host_ip' => EnvLoader::get('MAIL_HOST_IP', ''),
        'port' => EnvLoader::get('MAIL_PORT', ''),
        'username' => $maskedUsername,
        'encryption' => EnvLoader::get('MAIL_ENCRYPTION', ''),
        'from_address' => EnvLoader::get('MAIL_FROM_ADDRESS', ''),
        'from_name' => EnvLoader::get('MAIL_FROM_NAME', ''),
        'reply_to' => EnvLoader::get('MAIL_REPLY_TO', ''),
    ],
];

Response::success($data, 'OK', 200);
