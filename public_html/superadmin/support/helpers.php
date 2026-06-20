<?php
declare(strict_types=1);
function docker_h($v): string { return htmlspecialchars((string)$v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function docker_badge_class(string $s): string { return in_array($s,['ok','info'],true)?'ok':($s==='warning'?'warn':'error'); }
