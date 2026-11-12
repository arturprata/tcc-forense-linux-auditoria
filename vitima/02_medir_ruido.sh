#!/usr/bin/env bash
# Mede o crescimento dos registros e o ruido do AIDE em uso normal, sem acoes de ataque.
# Uso: ./02_medir_ruido.sh [minutos]   (padrao: 60, conforme a metodologia)
set -uo pipefail
source "$(dirname "$0")/comum.sh"; exige_root
MIN=${1:-60}; D="$EVID/ruido"; mkdir -p "$D"

log "Criando base temporaria do AIDE"
TIMEFORMAT=%R
{ time aide --config "$AIDE_CONF" --init >/dev/null; } 2> "$D/tempo_aide_init.txt"
cp -p /var/lib/aide/aide.db.new /var/lib/aide/aide.db

e0=$(eventos_auditd); b0=$(bytes /var/log/audit/audit.log)
a0=$(linhas /var/log/auth.log); s0=$(linhas /var/log/syslog)
sb0=$(bytes /var/log/syslog); ab0=$(bytes /var/log/auth.log)
log "Aguardando $MIN minutos sem acoes de ataque (uso normal ou ocioso)"
sleep $((MIN*60))
e1=$(eventos_auditd); b1=$(bytes /var/log/audit/audit.log)
a1=$(linhas /var/log/auth.log); s1=$(linhas /var/log/syslog)
sb1=$(bytes /var/log/syslog); ab1=$(bytes /var/log/auth.log)

log "Executando aide --check para medir ruido"
{ time aide --config "$AIDE_CONF" --check > "$D/aide_check_ruido.txt"; } 2> "$D/tempo_aide_check.txt"
grep -E '^(f|d|l)[^:]*: ' "$D/aide_check_ruido.txt" | sed -E 's/^[^:]+: //' | sort -u > "$D/caminhos_alterados_sem_ataque.txt"

maxmb=$(awk -F= '/^max_log_file *=/{gsub(/ /,"",$2);print $2}' /etc/audit/auditd.conf)
nlogs=$(awk -F= '/^num_logs *=/{gsub(/ /,"",$2);print $2}' /etc/audit/auditd.conf)
awk -v m="$MIN" -v e=$((e1-e0)) -v b=$((b1-b0)) -v a=$((a1-a0)) -v s=$((s1-s0)) \
    -v sb=$((sb1-sb0)) -v ab=$((ab1-ab0)) -v mx="$maxmb" -v nl="$nlogs" 'BEGIN{
  h=m/60;
  printf "Periodo: %d min\n", m;
  printf "auditd: %d eventos, %d bytes (%.0f eventos/h, %.2f MB/dia)\n", e, b, e/h, b/h*24/1048576;
  printf "auth.log: %d linhas, %d bytes; syslog: %d linhas, %d bytes\n", a, ab, s, sb;
  if (b>0) printf "Retencao estimada do auditd (%s MB x %s arquivos): %.1f dias em uso normal\n", mx, nl, (mx*nl)/(b/h*24/1048576);
}' | tee "$D/resumo_ruido.txt"
echo "Caminhos alterados sem ataque: $(wc -l < "$D/caminhos_alterados_sem_ataque.txt") (lista em $D/caminhos_alterados_sem_ataque.txt)" | tee -a "$D/resumo_ruido.txt"
log "Se houver caminhos dinamicos irrelevantes, acrescente-os em /etc/aide/aide.conf.d/99_tcc_exclusoes e repita."
