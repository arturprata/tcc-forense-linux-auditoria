#!/usr/bin/env bash
# Captura o estado do sistema com o Osquery. Uso: ./snapshot_osquery.sh antes|durante|depois
set -uo pipefail
source "$(dirname "$0")/comum.sh"; exige_root
ROT=${1:?informe o rotulo: antes, durante ou depois}
D="$EVID/osquery/$ROT"; mkdir -p "$D"
agora_utc > "$D/timestamp_utc.txt"

declare -A Q=(
 [usuarios]="SELECT uid, gid, username, directory, shell FROM users;"
 [processos]="SELECT pid, parent, uid, name, path, cmdline FROM processes;"
 [portas_escuta]="SELECT pid, port, protocol, address FROM listening_ports;"
 [conexoes]="SELECT pid, family, protocol, local_address, local_port, remote_address, remote_port, state FROM process_open_sockets WHERE remote_port != 0;"
 [crontab]="SELECT event, minute, hour, day_of_month, month, day_of_week, command, path FROM crontab;"
 [chaves_ssh]="SELECT u.username, k.key_file, k.key FROM users u CROSS JOIN authorized_keys k USING (uid);"
 [sudoers]="SELECT source, header, rule_details FROM sudoers;"
 [modulos_kernel]="SELECT name, size, used_by, status FROM kernel_modules;"
 [ultimos_logins]="SELECT username, tty, pid, type, time, host FROM last;"
 [sessoes_ativas]="SELECT type, user, tty, host, time FROM logged_in_users;"
 [historico_shell]="SELECT u.username, h.command FROM users u CROSS JOIN shell_history h USING (uid);"
 [ocultos_home]="SELECT path, size, mode, uid FROM file WHERE path LIKE '/home/%/.%';"
 [ocultos_cache]="SELECT path, size, mode, uid FROM file WHERE path LIKE '/home/%/.cache/%';"
 [ocultos_tmp]="SELECT path, size, mode, uid FROM file WHERE path LIKE '/tmp/.%';"
)
TIMEFORMAT=%R
{ time for nome in "${!Q[@]}"; do
    echo "${Q[$nome]}" > "$D/$nome.sql"
    osqueryi --json "${Q[$nome]}" > "$D/$nome.json" 2> "$D/$nome.err" || echo "falha em $nome" >> "$D/falhas.txt"
  done; } 2> "$D/tempo_total_segundos.txt"
log "Snapshot Osquery '$ROT' salvo em $D ($(cat "$D/tempo_total_segundos.txt") s)"
