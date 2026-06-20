<?php
declare(strict_types=1);
function docker_config(): array {
    return [
        'module' => DOCKER_MODULE_NAME,
        'schema_version' => DOCKER_SCHEMA_VERSION,
        'reports_dir' => docker_reports_dir(),
        'latest_report' => docker_effective_latest_report_path(),
        'latest_summary' => docker_effective_latest_summary_path(),
        'state_dir' => docker_state_dir(),
        'events_log' => docker_events_log_path(),
        'monitor_label' => docker_env_or_default('MONITOR_LABEL', DOCKER_DEFAULT_MONITOR_LABEL),
    ];
}
