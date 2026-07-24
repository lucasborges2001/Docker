<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$limit=isset($_GET['limit'])?(int)$_GET['limit']:50;
docker_api_json(['events'=>(new DockerStatusService())->events($limit)]);
