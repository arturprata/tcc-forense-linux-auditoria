#!/usr/bin/env python3
"""Une a timeline do Plaso (CSV l2tcsv) aos eventos normalizados (auditd e Osquery), restringe ao
intervalo do experimento e associa cada evento a acao do gabarito em execucao naquele instante.
Uso: python3 mesclar_timeline.py gabarito.csv super_timeline.csv --plaso timeline_plaso.csv \
         --extra audit_eventos.csv osquery_diff.csv [--margem 5] \
         [--excluir-auid <uid do pesquisador>] [--excluir-usuario pesquisador]"""
import argparse, bisect, csv, re, sys
from datetime import datetime, timedelta, timezone

csv.field_size_limit(sys.maxsize)
p = argparse.ArgumentParser()
p.add_argument("gabarito"); p.add_argument("saida")
p.add_argument("--plaso", nargs="*", default=[]); p.add_argument("--extra", nargs="*", default=[])
p.add_argument("--margem", type=float, default=5, help="minutos antes/depois do cenario")
p.add_argument("--excluir-auid", nargs="*", default=[], help="auids a descartar (conta pesquisador)")
p.add_argument("--excluir-usuario", nargs="*", default=[], help="usuarios cujas linhas do Plaso sao descartadas")
p.add_argument("--excluir-janela", nargs=2, action="append", default=[], metavar=("INI", "FIM"),
               help="intervalo UTC (ISO) cujos eventos do auditd/osquery sao descartados; pode repetir")
a = p.parse_args()

def iso(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)

with open(a.gabarito, encoding="utf-8") as f:
    acoes = sorted((iso(r["timestamp_utc"]), r["id"], r["fase"]) for r in csv.DictReader(f) if r["timestamp_utc"])
tempos = [t for t, _, _ in acoes]
ini, fim = tempos[0] - timedelta(minutes=a.margem), tempos[-1] + timedelta(minutes=a.margem)

eventos = []
for arq in a.plaso:
    with open(arq, encoding="utf-8", errors="replace") as f:
        for r in csv.DictReader(f):
            try:
                t = datetime.strptime(f'{r["date"]} {r["time"]}', "%m/%d/%Y %H:%M:%S").replace(tzinfo=timezone.utc)
            except (KeyError, ValueError):
                continue
            desc = r.get("desc") or r.get("short") or ""
            if any(re.search(rf"\b{re.escape(u)}\b", desc) for u in a.excluir_usuario):
                continue
            eventos.append((t, "plaso:" + r.get("source", ""), r.get("sourcetype", "") + " " + r.get("MACB", ""),
                            f'{desc} [{r.get("filename", "")}]'))
for arq in a.extra:
    with open(arq, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r.get("auid") in a.excluir_auid:
                continue
            eventos.append((iso(r["timestamp_utc"]), r["fonte"], r["tipo"], r["descricao"]))

JANELAS = [(iso(x), iso(y)) for x, y in a.excluir_janela]
eventos = sorted(e for e in eventos if ini <= e[0] <= fim
                 and not ((e[1] == "auditd" or e[1].startswith("plaso"))
                          and any(j0 <= e[0] <= j1 for j0, j1 in JANELAS)))
# Na janela excluida mantem-se apenas o Osquery: a propria captura intermediaria e evidencia.
with open(a.saida, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["timestamp_utc", "fonte", "tipo", "descricao", "acao_gabarito", "fase"])
    for t, fonte, tipo, desc in eventos:
        i = bisect.bisect_right(tempos, t) - 1
        acao, fase = (acoes[i][1], acoes[i][2]) if i >= 0 else ("antes_do_cenario", "")
        w.writerow([t.isoformat(timespec="milliseconds").replace("+00:00", "Z"), fonte, tipo, desc, acao, fase])
print(f"{len(eventos)} eventos entre {ini:%H:%M:%S} e {fim:%H:%M:%S} UTC gravados em {a.saida}")
