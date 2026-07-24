<?php
declare(strict_types=1);
require_once __DIR__ . '/../support/api.php';
$ref=isset($_GET['container_ref'])?trim((string)$_GET['container_ref']):'';
if($ref===''||strlen($ref)>220){docker_superadmin_json(['ok'=>false,'module'=>DOCKER_MODULE_NAME,'error'=>['code'=>'invalid_container_ref']],400);exit;}
$item=(new DockerStatusService())->container($ref);
docker_superadmin_json($item??['ok'=>false,'module'=>DOCKER_MODULE_NAME,'error'=>['code'=>'container_not_found']],$item===null?404:200);
