<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$s=new DockerStatusService(new DockerSnapshotReader(__DIR__.'/../../var/sample-reports/latest/report.json'), new DockerEventReader(__DIR__.'/../../var/sample-reports/events.jsonl'), new DockerHistoryService(__DIR__.'/../../var/sample-reports')); $h=$s->health(); $sum=$s->summary(); if($h['ok']!==true||$sum['available']!==true||count($sum['events'])<1){throw new RuntimeException('status failed');} echo "DockerStatusServiceTest OK\n";
