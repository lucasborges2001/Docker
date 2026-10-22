<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/metrics/DockerHistoryFiles.php';

$root = sys_get_temp_dir() . '/docker-history-test-' . bin2hex(random_bytes(6));
mkdir($root);
try {
    foreach (['20261022T170000Z', '20261022T180000Z', 'bogus'] as $folder) {
        mkdir($root . '/' . $folder);
        file_put_contents($root . '/' . $folder . '/report.json', '{}');
    }
    mkdir($root . '/latest');
    file_put_contents($root . '/latest/report.json', '{}');
    symlink($root . '/20261022T180000Z', $root . '/20261022T190000Z');
    $paths = DockerHistoryFiles::candidates($root);
    $names = array_map(static fn(string $path): string => basename(dirname($path)), $paths);
    if ($names !== ['20261022T180000Z', '20261022T170000Z']) {
        throw new RuntimeException('unsafe/unordered candidates: ' . json_encode($names));
    }
    if (DockerHistoryFiles::candidates($root . '/missing') !== []) {
        throw new RuntimeException('missing history directory should return empty candidates');
    }
} finally {
    unlink($root . '/20261022T190000Z');
    foreach (['20261022T170000Z', '20261022T180000Z', 'bogus', 'latest'] as $folder) {
        unlink($root . '/' . $folder . '/report.json');
        rmdir($root . '/' . $folder);
    }
    rmdir($root);
}
echo "DockerHistoryFilesTest OK\n";
