#!/usr/bin/env bash
# Snapshot da VM em execucao, tirado do hospedeiro (nao gera registros na vitima).
# Uso: ./snapshot_vm.sh fase-a
set -euo pipefail
source "$(dirname "$0")/ambiente.conf"
VBoxManage snapshot "$NOME_VM" take "${1:?nome do snapshot}" --live --description "TCC $(date -u +%FT%TZ)"
VBoxManage snapshot "$NOME_VM" list
