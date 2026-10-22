<?php
require_once __DIR__ . '/../support/api.php';
docker_superadmin_json(['ok'=>true,'module'=>'docker','schema_version'=>DOCKER_SCHEMA_VERSION,'health'=>(new DockerStatusService())->health()]);
