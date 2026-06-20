<?php
require_once __DIR__ . '/../support/api.php';
docker_superadmin_json(['ok'=>true,'module'=>'docker','paths'=>docker_config(),'health'=>(new DockerStatusService())->health()]);
