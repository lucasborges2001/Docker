<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$r=new DockerSnapshotReader(__DIR__.'/../../var/sample-reports/latest/report.json'); $l=$r->latestForApi(); if(!is_array($l)||$l['module']!=='docker'||$l['containers']['running']!==6){throw new RuntimeException('reader failed');} echo "DockerSnapshotReaderTest OK\n";
