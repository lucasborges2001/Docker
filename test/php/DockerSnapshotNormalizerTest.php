<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$normalizer=new DockerSnapshotNormalizer();
$v2=json_decode((string)file_get_contents(__DIR__.'/../../var/sample-reports/latest/report.json'),true);
$api=$normalizer->normalizeForApi($v2);
if(($api['schema_version']??0)!==2||($api['status']['severity']??'')!=='ok'||($api['engine']['available']??false)!==true){throw new RuntimeException('schema v2 normalizer failed');}
if(array_key_exists('socket',$api['engine'])){throw new RuntimeException('socket leaked through API');}
if(count($api['containers']['items']??[])!==2||($api['aggregates']['memory_used_bytes']??0)!==201326592){throw new RuntimeException('resource telemetry missing');}
$v1=json_decode((string)file_get_contents(__DIR__.'/../fixtures/snapshot_v1.json'),true);
$legacy=$normalizer->normalizeForApi($v1);
if(($legacy['schema_version']??0)!==1||($legacy['containers']['running']??0)!==6||!isset($legacy['aggregates'])){throw new RuntimeException('schema v1 compatibility failed');}
echo "DockerSnapshotNormalizerTest OK\n";
