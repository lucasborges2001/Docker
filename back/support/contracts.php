<?php
declare(strict_types=1);
const DOCKER_MODULE_NAME = 'docker';
const DOCKER_SCHEMA_VERSION = 2;
const DOCKER_MINIMUM_COMPATIBLE_SCHEMA_VERSION = 1;
const DOCKER_DEFAULT_REPORTS_DIR = '/var/lib/docker-watch/reports';
const DOCKER_DEFAULT_STATE_DIR = '/var/lib/docker-watch';
const DOCKER_DEFAULT_EVENTS_LOG = '/var/log/docker-watch/events.jsonl';
const DOCKER_DEFAULT_MONITOR_LABEL = 'dockwatch.monitor=true';
