<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$service=new DockerStatusService();$latest=$service->latest();
docker_api_json($latest??$service->health(),$latest===null?404:200);
