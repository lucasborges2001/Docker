<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$normalizer=new DockerSnapshotNormalizer();
$v2=json_decode((string)file_get_contents(__DIR__.'/../../var/sample-reports/latest/report.json'),true);
$api=$normalizer->normalizeForApi($v2);
if(($api['schema_version']??0)!==2||($api['status']['severity']??'')!=='ok'||($api['engine']['available']??false)!==true){throw new RuntimeException('schema v2 normalizer failed');}
$serialized=json_encode($api);
if(array_key_exists('socket',$api['engine'])||str_contains((string)$serialized,'/var/run/docker.sock')){throw new RuntimeException('socket leaked through API');}
if(count($api['containers']['items']??[])!==2||($api['aggregates']['memory_used_bytes']??0)!==201326592){throw new RuntimeException('resource telemetry missing');}
$v1=json_decode((string)file_get_contents(__DIR__.'/../fixtures/snapshot_v1.json'),true);
$legacy=$normalizer->normalizeForApi($v1);
if(($legacy['schema_version']??0)!==1||($legacy['containers']['running']??0)!==6||!isset($legacy['aggregates'])){throw new RuntimeException('schema v1 compatibility failed');}

$sample=$v2;
$sample['containers']['items']=[
    ['container_ref'=>'name:missing','state'=>'running','restart_count'=>null,'pids'=>null,'cpu_percent'=>null],
    ['container_ref'=>'name:zero','state'=>'running','restart_count'=>0,'pids'=>0,'cpu_percent'=>250.4],
    ['container_ref'=>'name:invalid','state'=>'running','restart_count'=>'-1','pids'=>'7','cpu_percent'=>'NaN',
     'network_rx_bytes_total'=>-5],
];
$detail=$normalizer->normalizeForApi($sample)['containers']['items']??[];
if(count($detail)!==3){throw new RuntimeException('nullable fixtures missing');}
if($detail[0]['restart_count']!==null||$detail[0]['pids']!==null){
    throw new RuntimeException('missing counter became zero');
}
if($detail[1]['restart_count']!==0||$detail[1]['pids']!==0||$detail[1]['cpu_percent']!==250.4){
    throw new RuntimeException('measured zero or multicore CPU lost');
}
foreach(['restart_count','pids','cpu_percent','network_rx_bytes_total'] as $field){
    if($detail[2][$field]!==null){throw new RuntimeException('invalid field accepted: '.$field);}
}
echo "DockerSnapshotNormalizerTest OK\n";
