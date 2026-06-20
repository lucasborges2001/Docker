<?php
declare(strict_types=1);
final class DockerHistoryService {
    private $reportsDir; private $normalizer;
    public function __construct(?string $reportsDir = null, ?DockerSnapshotNormalizer $normalizer = null) { $this->reportsDir = $reportsDir ?: docker_reports_dir(); $this->normalizer = $normalizer ?: new DockerSnapshotNormalizer(); }
    public function recent(int $limit = 10): array {
        $limit = max(1, min(100, $limit)); if (!is_dir($this->reportsDir)) return [];
        $items = [];
        foreach (glob($this->reportsDir . '/*/report.json') ?: [] as $path) {
            if (basename(dirname($path)) === 'latest') continue;
            $raw = json_decode((string)file_get_contents($path), true);
            if (!is_array($raw)) continue;
            $data = $this->normalizer->normalizeForApi($raw); $data['path'] = $path;
            $items[] = ['mtime'=>filemtime($path) ?: 0, 'data'=>$data];
        }
        usort($items, static fn($a,$b) => $b['mtime'] <=> $a['mtime']);
        return array_map(static fn($x) => $x['data'], array_slice($items, 0, $limit));
    }
}
