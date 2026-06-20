<?php
require_once __DIR__ . '/../../../back/bootstrap.php';
function docker_superadmin_json($d,int $s=200): void { http_response_code($s); header('Content-Type: application/json; charset=utf-8'); echo json_encode($d, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT); }
