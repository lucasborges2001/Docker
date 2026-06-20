<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
$raw=json_decode((string)file_get_contents(__DIR__.'/../../var/sample-reports/latest/report.json'),true); $api=(new DockerSnapshotNormalizer())->normalizeForApi($raw); if($api['status']['severity']!=='ok'||$api['engine']['available']!==true){throw new RuntimeException('normalizer failed');} echo "DockerSnapshotNormalizerTest OK\n";
