<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once '../../config/database.php';
require_once '../../utils/Response.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $stmt = $pdo->prepare("SELECT id, zh_name, en_name, abbr FROM universities ORDER BY zh_name ASC");
    $stmt->execute();
    $universities = $stmt->fetchAll(PDO::FETCH_ASSOC);

    Response::success($universities, 'Universities retrieved successfully');

} catch (PDOException $e) {
    Response::error('Database error: ' . $e->getMessage(), 500);
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 