<?php
declare(strict_types=1);
function docker_env_or_default(string $name, string $default): string { $v = getenv($name); return is_string($v) && $v !== '' ? $v : $default; }
function docker_module_root(): string { return dirname(__DIR__, 2); }
function docker_sample_reports_dir(): string { return docker_module_root() . '/var/sample-reports'; }
function docker_reports_dir(): string {
    $configured = rtrim(docker_env_or_default('DOCKER_WATCH_REPORTS_DIR', DOCKER_DEFAULT_REPORTS_DIR), '/');
    if (is_file($configured . '/latest/report.json')) return $configured;
    $sample = docker_sample_reports_dir();
    if (is_file($sample . '/latest/report.json')) return $sample;
    return $configured;
}
function docker_effective_latest_report_path(): string { return docker_reports_dir() . '/latest/report.json'; }
function docker_effective_latest_summary_path(): string { return docker_reports_dir() . '/latest/summary.txt'; }
function docker_state_dir(): string { return docker_env_or_default('DOCKER_WATCH_STATE_DIR', DOCKER_DEFAULT_STATE_DIR); }
function docker_events_log_path(): string {
    $configured = docker_env_or_default('DOCKER_WATCH_EVENTS_LOG', DOCKER_DEFAULT_EVENTS_LOG);
    if (is_file($configured)) return $configured;
    $sample = docker_sample_reports_dir() . '/events.jsonl';
    if (is_file($sample)) return $sample;
    return $configured;
}
