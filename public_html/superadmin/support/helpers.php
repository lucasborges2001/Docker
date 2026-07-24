<?php
declare(strict_types=1);
function docker_h($v): string { return htmlspecialchars((string)$v,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8'); }
function docker_badge_class(string $s): string { return in_array($s,['ok','info'],true)?'ok':($s==='warning'?'warn':'error'); }
function docker_format_bytes($value): string { if($value===null||$value==='')return 'N/D';$bytes=max(0,(float)$value);$units=['B','KiB','MiB','GiB','TiB'];$index=0;while($bytes>=1024&&$index<count($units)-1){$bytes/=1024;$index++;}return ($index===0?(string)(int)$bytes:number_format($bytes,1,',','.')).' '.$units[$index]; }
function docker_format_percent($value): string { return $value===null||$value===''?'N/D':number_format((float)$value,2,',','.').' %'; }
function docker_format_duration($seconds): string { if($seconds===null||$seconds==='')return 'N/D';$seconds=max(0,(int)$seconds);$days=intdiv($seconds,86400);$hours=intdiv($seconds%86400,3600);$minutes=intdiv($seconds%3600,60);return $days>0?"{$days}d {$hours}h":($hours>0?"{$hours}h {$minutes}m":"{$minutes}m"); }
