<?php
require_once __DIR__ . '/../../../back/bootstrap.php';
return (new DockerStatusService())->health();
