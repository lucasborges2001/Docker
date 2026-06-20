<?php
require_once __DIR__ . '/../support/api.php';
$limit=isset($_GET['limit'])?(int)$_GET['limit']:10; docker_superadmin_json(['history'=>(new DockerHistoryService())->recent($limit)]);
