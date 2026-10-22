<?php
declare(strict_types=1);

/** Only timestamp-named, regular Docker report files are history candidates. */
final class DockerHistoryFiles
{
    public static function candidates(string $reportsDir): array
    {
        if (!is_dir($reportsDir) || is_link($reportsDir)) {
            return [];
        }
        $paths = glob(rtrim($reportsDir, '/') . '/*/report.json') ?: [];
        $paths = array_values(array_filter($paths, static function (string $path): bool {
            $directory = dirname($path);
            return (bool)preg_match('/\A\d{8}T\d{6}Z\z/', basename($directory))
                && !is_link($directory) && !is_link($path) && is_file($path);
        }));
        rsort($paths, SORT_STRING);
        return $paths;
    }
}
