<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$r=new DockerEventReader(__DIR__.'/../../var/sample-reports/events.jsonl'); $e=$r->latest(10); if(count($e)<1||!isset($e[0]['type'])){throw new RuntimeException('events failed');} echo "DockerEventReaderTest OK\n";
