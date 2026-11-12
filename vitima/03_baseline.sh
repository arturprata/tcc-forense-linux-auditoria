#!/usr/bin/env bash
# Cria a baseline final (AIDE e Osquery) e ativa a imutabilidade do auditd.
# Depois deste script: tirar o snapshot "02-baseline" no VirtualBox e iniciar o cenario.
set -uo pipefail
source "$(dirname "$0")/comum.sh"; exige_root

log "Baseline final do AIDE"
TIMEFORMAT=%R
{ time aide --config "$AIDE_CONF" --init >/dev/null; } 2> "$EVID/tempo_aide_init_baseline.txt"
cp -p /var/lib/aide/aide.db.new /var/lib/aide/aide.db
sha256sum /var/lib/aide/aide.db | tee "$EVID/aide_db_baseline.sha256"

log "Snapshot Osquery 'antes'"
"$SCRIPTS/snapshot_osquery.sh" antes

log "Ativando imutabilidade do auditd (-e 2)"
cp "$SCRIPTS/config/99-imutavel.rules" /etc/audit/rules.d/99-imutavel.rules
augenrules --load
auditctl -s | tee "$EVID/auditd_status_baseline.txt"
grep -q "enabled 2" "$EVID/auditd_status_baseline.txt" && log "auditd imutavel (enabled 2)" || log "ATENCAO: enabled != 2"

{
  echo "baseline_utc=$(agora_utc)"
  echo "audit_log_bytes=$(bytes /var/log/audit/audit.log)"
  echo "audit_eventos=$(eventos_auditd)"
  echo "auth_log_linhas=$(linhas /var/log/auth.log)"
  echo "syslog_linhas=$(linhas /var/log/syslog)"
} | tee "$EVID/marcadores_baseline.txt"
log "Pronto. Tire agora o snapshot 02-baseline no hospedeiro."
