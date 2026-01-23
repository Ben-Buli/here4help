<?php
// backend/api 端點共用的啟動引導（bootstrap）。
require_once __DIR__ . '/../config/php84_compatibility.php';
require_once __DIR__ . '/../config/env_loader.php';
require_once __DIR__ . '/../utils/Response.php';
require_once __DIR__ . '/../utils/JWTManager.php';
require_once __DIR__ . '/../auth_helper.php';
require_once __DIR__ . '/../utils/PermissionHelper.php';
