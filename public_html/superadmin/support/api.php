<?php
declare(strict_types=1);
require_once __DIR__ . '/../../../back/bootstrap.php';
function docker_superadmin_json($data,int $status=200): void { http_response_code($status);header('Content-Type: application/json; charset=utf-8');header('Cache-Control: no-store, max-age=0');header('X-Content-Type-Options: nosniff');echo json_encode($data,JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT); }
if(($_SERVER['REQUEST_METHOD']??'GET')!=='GET'){header('Allow: GET');docker_superadmin_json(['ok'=>false,'module'=>DOCKER_MODULE_NAME,'error'=>['code'=>'method_not_allowed']],405);exit;}
