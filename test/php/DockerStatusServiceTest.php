<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$service=new DockerStatusService(new DockerSnapshotReader(__DIR__.'/../../var/sample-reports/latest/report.json'),new DockerEventReader(__DIR__.'/../../var/sample-reports/events.jsonl'),new DockerHistoryService(__DIR__.'/../../var/sample-reports'));
$health=$service->health();$summary=$service->summary();$resources=$service->resources();$container=$service->container('compose:demo/api/1');
if($health['ok']!==true||$summary['available']!==true||count($summary['events'])<1){throw new RuntimeException('status failed');}
if(($resources['aggregates']['cpu_percent']??0.0)!==15.75||count($resources['containers']['items']??[])!==2){throw new RuntimeException('resources failed');}
if(($container['container']['name']??'')!=='demo-api-1'||$service->container('name:missing')!==null){throw new RuntimeException('container lookup failed');}
echo "DockerStatusServiceTest OK\n";
