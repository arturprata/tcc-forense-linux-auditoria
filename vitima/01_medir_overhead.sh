#!/usr/bin/env bash
# Mede a sobrecarga da auditoria de comandos: mesma carga com e sem regras do auditd.
# Deve ser executado ANTES do 03_baseline.sh (depois dele as regras ficam imutaveis).
set -uo pipefail
source "$(dirname "$0")/comum.sh"; exige_root
N=${1:-5000}; REP=${2:-5}
OUT="$EVID/overhead.csv"; echo "condicao,repeticao,execucoes,segundos,bytes_audit_log" > "$OUT"

carga() { for ((i=0;i<N;i++)); do /bin/true; done; }
medir() {
  local cond=$1
  for ((r=1;r<=REP;r++)); do
    local b0; b0=$(bytes /var/log/audit/audit.log)
    local t0; t0=$(date +%s.%N); carga; local t1; t1=$(date +%s.%N)
    sleep 2
    local b1; b1=$(bytes /var/log/audit/audit.log)
    echo "$cond,$r,$N,$(echo "$t1 - $t0" | bc -l),$((b1-b0))" >> "$OUT"
  done
}
log "Medindo COM regras ($REP repeticoes de $N execucoes)"; medir com_regras
log "Removendo regras temporariamente"; auditctl -D >/dev/null
log "Medindo SEM regras"; medir sem_regras
log "Recarregando regras"; augenrules --load; auditctl -l | wc -l
awk -F, 'NR>1{s[$1]+=$4; b[$1]+=$5; n[$1]++} END{
  for(c in s) printf "%s: media %.3f s, %.0f bytes de log por repeticao\n", c, s[c]/n[c], b[c]/n[c];
  if (s["sem_regras"]>0) printf "Sobrecarga: %.1f%%\n", 100*(s["com_regras"]/n["com_regras"]-s["sem_regras"]/n["sem_regras"])/(s["sem_regras"]/n["sem_regras"]);
  if (n["com_regras"]>0) printf "Bytes de log por comando executado: %.0f\n", b["com_regras"]/n["com_regras"]/'"$N"';
}' "$OUT" | tee "$EVID/overhead_resumo.txt"
