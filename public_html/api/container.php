<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$ref=isset($_GET['container_ref'])?trim((string)$_GET['container_ref']):'';
if($ref===''||strlen($ref)>220){docker_api_json(['ok'=>false,'module'=>DOCKER_MODULE_NAME,'error'=>['code'=>'invalid_container_ref']],400);exit;}
$item=(new DockerStatusService())->container($ref);
docker_api_json($item??['ok'=>false,'module'=>DOCKER_MODULE_NAME,'error'=>['code'=>'container_not_found']],$item===null?404:200);
