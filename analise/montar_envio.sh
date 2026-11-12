#!/usr/bin/env bash
# Junta em envio_tcc.zip os arquivos necessarios para escrever o Capitulo 4.
# Executar na pasta raiz do roteiro (onde estao hospedeiro/, analise/ e coleta/).
set -uo pipefail
E=envio_tcc; rm -rf "$E" "$E.zip"; mkdir -p "$E"
copia() { for f in "$@"; do [ -e "$f" ] && cp -r "$f" "$E/" || echo "AVISO: nao encontrado: $f"; done; }

# Anotacoes, gabarito e analises geradas no hospedeiro
copia caderno_de_campo.md hospedeiro/execucao.csv gabarito.csv osquery_diff.csv volume_por_fase.csv
copia hospedeiro/plaso/pinfo.txt hospedeiro/plaso/tempo_log2timeline.txt hospedeiro/plaso/versao_plaso.txt

# Evidencias da vitima (resumos, sem os logs brutos)
copia coleta/contas.txt coleta/versoes.txt coleta/auditd_conf_parametros.txt coleta/auditd_regras_carregadas.txt \
      coleta/auditd_status_baseline.txt coleta/auditd_status_preparacao.txt coleta/marcadores_baseline.txt \
      coleta/overhead.csv coleta/overhead_resumo.txt coleta/volume_total.csv coleta/hashes.sha256 \
      coleta/ruido coleta/auditd coleta/rsyslog coleta/aide coleta/historico coleta/sistema
mkdir -p "$E/osquery" && cp -r coleta/osquery/* "$E/osquery/" 2>/dev/null

# Eventos normalizados e super timeline restritos ao intervalo do cenario
python3 - "$E" <<'PY'
import csv, sys
from datetime import datetime, timedelta
d = sys.argv[1]
iso = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
ts = [iso(r["timestamp_utc"]) for r in csv.DictReader(open("gabarito.csv", encoding="utf-8")) if r["timestamp_utc"]]
ini, fim = min(ts) - timedelta(minutes=5), max(ts) + timedelta(minutes=5)
for nome in ("audit_eventos.csv", "super_timeline.csv"):
    try:
        with open(nome, encoding="utf-8") as f, open(f"{d}/{nome}", "w", newline="", encoding="utf-8") as g:
            r = csv.DictReader(f); w = csv.DictWriter(g, fieldnames=r.fieldnames); w.writeheader()
            n = 0
            for linha in r:
                if ini <= iso(linha["timestamp_utc"]) <= fim:
                    w.writerow(linha); n += 1
        print(f"{nome}: {n} linhas no intervalo do cenario")
    except FileNotFoundError:
        print(f"AVISO: {nome} nao encontrado")
PY

zip -qr "$E.zip" "$E"
echo "Pacote: $E.zip ($(du -h "$E.zip" | cut -f1))"
