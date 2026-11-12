#!/usr/bin/env bash
# Registra no hospedeiro o horario (UTC) de uma acao do plano e mostra o comando a digitar.
# Uso: ./registrar_acao.sh A02
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/ambiente.conf"
PLANO="$DIR/plano_acoes.tsv"; EXEC="$DIR/execucao.csv"
id="${1:?informe o ID da acao (ex.: A02)}"
linha=$(awk -F'\t' -v id="$id" '$1==id' "$PLANO")
[ -n "$linha" ] || { echo "ID $id nao existe em plano_acoes.tsv"; exit 1; }
desc=$(printf '%s' "$linha" | cut -f4)
cmd=$(printf '%s' "$linha" | cut -f5 | sed "s/IP_VITIMA/$IP_VITIMA/g; s/IP_HOSPEDEIRO/$IP_HOSPEDEIRO/g")
[ -f "$EXEC" ] || echo "id,timestamp_utc" > "$EXEC"
grep -q "^$id," "$EXEC" && { echo "Aviso: $id ja registrado, marcando repeticao."; id="$id-r"; }
ts=$(python3 -c 'import datetime as d;print(d.datetime.now(d.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00","Z"))')
echo "$id,$ts" >> "$EXEC"
printf '\n[%s] %s  (%s)\nComando:\n\n    %s\n\n' "$id" "$desc" "$ts" "$cmd"
