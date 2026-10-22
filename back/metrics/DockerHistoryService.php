<?php
declare(strict_types=1);

final class DockerHistoryService
{
    private $reportsDir;
    private $normalizer;

    public function __construct(?string $reportsDir = null, ?DockerSnapshotNormalizer $normalizer = null)
    {
        $this->reportsDir = $reportsDir ?: docker_reports_dir();
        $this->normalizer = $normalizer ?: new DockerSnapshotNormalizer();
    }

    public function recent(int $limit = 10): array
    {
        $limit = max(1, min(100, $limit));
        $items = [];
        foreach (DockerHistoryFiles::candidates($this->reportsDir) as $path) {
            if (count($items) >= $limit) {
                break;
            }
            // Reject unusually large files before decoding untrusted on-disk content.
            $size = filesize($path);
            if ($size === false || $size > 2 * 1024 * 1024) {
                continue;
            }
            $content = @file_get_contents($path);
            $raw = $content === false ? null : json_decode($content, true);
            if (!is_array($raw) || ($raw['module'] ?? '') !== DOCKER_MODULE_NAME) {
                continue;
            }
            $items[] = $this->normalizer->normalizeForApi($raw);
        }
        return $items;
    }
}
