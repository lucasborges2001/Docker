<?php
require_once __DIR__ . '/../support/api.php';
$limit=isset($_GET['limit'])?(int)$_GET['limit']:50; docker_superadmin_json(['events'=>(new DockerStatusService())->events($limit),'path'=>docker_events_log_path()]);
