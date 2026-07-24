<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$limit=isset($_GET['limit'])?(int)$_GET['limit']:10;
docker_api_json(['history'=>(new DockerHistoryService())->recent($limit)]);
