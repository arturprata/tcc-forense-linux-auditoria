#!/usr/bin/env bash
# Funcoes e caminhos compartilhados pelos scripts da vitima.
export LC_NUMERIC=C
EVID=/root/tcc
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIDE_CONF=/etc/aide/aide.conf
ADMIN="${SUDO_USER:-pesquisador}"
mkdir -p "$EVID"

exige_root() { [ "$(id -u)" -eq 0 ] || { echo "Execute como root (sudo -i)."; exit 1; }; }
agora_utc() { date -u +%Y-%m-%dT%H:%M:%S.%3NZ; }
log() { echo "[$(agora_utc)] $*" | tee -a "$EVID/execucao_scripts.log"; }

# O audit.log pode ser rotacionado; somam-se todos os arquivos audit.log*
eventos_auditd() {
  cat /var/log/audit/audit.log* 2>/dev/null \
    | grep -ohE 'msg=audit\([0-9.]+:[0-9]+\)' | sort -u | wc -l
}
bytes() {
  if [ "$1" = /var/log/audit/audit.log ]; then
    cat /var/log/audit/audit.log* 2>/dev/null | wc -c
  else
    stat -c %s "$1" 2>/dev/null || echo 0
  fi
}
linhas() { wc -l < "$1" 2>/dev/null || echo 0; }
