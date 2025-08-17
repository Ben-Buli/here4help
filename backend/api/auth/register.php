<?php
require_once '../../config/database.php';
require_once '../../utils/TokenValidator.php';
require_once '../../utils/JWTManager.php';
require_once '../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
    exit;
}

try {
    $db = Database::getInstance();
    
    // 獲取 JSON 數據
    $input = json_decode(file_get_contents('php://input'), true);
    
    // 驗證必要欄位
    $requiredFields = [
        'full_name', 'nickname', 'gender', 'email', 'phone', 
        'country', 'address', 'password', 'date_of_birth', 
        'payment_password', 'is_permanent_address', 'primary_language'
    ];
    
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            Response::error("Missing required field: $field");
            exit;
        }
    }
    
    // 檢查 email 是否已存在
    $email = $input['email'];
    $existingUser = $db->fetch("SELECT id FROM users WHERE email = ?", [$email]);
    if ($existingUser) {
        Response::error('Email already exists');
        exit;
    }
    
    // 開始資料庫交易
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 建立用戶帳戶
        $hashedPassword = password_hash($input['password'], PASSWORD_DEFAULT);
        $hashedPaymentPassword = password_hash($input['payment_password'], PASSWORD_DEFAULT);
        
        $userSql = "INSERT INTO users (
            name, nickname, email, password, phone, points, status,
            payment_password, date_of_birth, gender, country,
            address, is_permanent_address, primary_language,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 0, 'active', ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
        
        $db->query($userSql, [
            $input['full_name'],
            $input['nickname'],
            $email,
            $hashedPassword,
            $input['phone'],
            $hashedPaymentPassword,
            $input['date_of_birth'],
            $input['gender'],
            $input['country'],
            $input['address'],
            $input['is_permanent_address'] ? 1 : 0,
            $input['primary_language']
        ]);
        
        $userId = $db->lastInsertId();
        
        // 提交交易
        $connection->commit();
        
        Response::success('User registered successfully', [
            'user_id' => $userId,
            'email' => $email,
            'status' => 'active'
        ]);
        
    } catch (Exception $e) {
        // 回滾交易
        $connection->rollback();
        Response::error('Database error: ' . $e->getMessage());
    }
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage());
}
?> 