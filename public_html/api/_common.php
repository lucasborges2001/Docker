<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
function docker_api_init(): void {
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store, max-age=0');
    header('X-Content-Type-Options: nosniff');
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        header('Allow: GET');
        docker_api_json(['ok'=>false,'module'=>DOCKER_MODULE_NAME,'error'=>['code'=>'method_not_allowed']],405);
        exit;
    }
}
function docker_api_json(array $payload,int $status=200): void {
    http_response_code($status);
    echo json_encode($payload,JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);
}
docker_api_init();
