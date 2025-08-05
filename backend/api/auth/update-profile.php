<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once '../../config/database.php';
require_once '../../utils/Response.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
    exit;
}

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
        exit;
    }

    // 驗證必填欄位
    $required_fields = ['user_id', 'name'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || empty(trim($input[$field]))) {
            Response::error("Missing required field: $field", 400);
            exit;
        }
    }

    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // 準備更新欄位
    $update_fields = [];
    $params = [];

    // 可更新的欄位
    $allowed_fields = [
        'name', 'nickname', 'phone', 'date_of_birth', 'gender', 
        'country', 'address', 'is_permanent_address', 
        'primary_language', 'language_requirement', 'school'
    ];

    foreach ($allowed_fields as $field) {
        if (isset($input[$field])) {
            $update_fields[] = "$field = ?";
            $params[] = $input[$field];
        }
    }

    if (empty($update_fields)) {
        Response::error('No valid fields to update', 400);
        exit;
    }

    // 添加 user_id 到參數
    $params[] = $input['user_id'];

    $sql = "UPDATE users SET " . implode(', ', $update_fields) . ", updated_at = CURRENT_TIMESTAMP WHERE id = ?";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    if ($stmt->rowCount() > 0) {
        // 獲取更新後的用戶資料
        $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
        $stmt->execute([$input['user_id']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        Response::success($user, 'Profile updated successfully');
    } else {
        Response::error('User not found or no changes made', 404);
    }

} catch (PDOException $e) {
    Response::error('Database error: ' . $e->getMessage(), 500);
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 