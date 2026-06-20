<?php
require_once __DIR__ . '/../support/api.php';
$s=new DockerStatusService(); $l=$s->latest(); docker_superadmin_json($l ?: $s->health(), $l?200:404);
