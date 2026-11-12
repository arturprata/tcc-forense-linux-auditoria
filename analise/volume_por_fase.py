#!/usr/bin/env python3
"""Conta eventos e bytes de cada fonte em cada fase do cenario, usando os horarios do gabarito.
Eventos do auditd cujo auid esteja em --excluir-auid e linhas do auth.log/syslog que citem
um usuario de --excluir-usuario (sessoes do pesquisador) sao desconsiderados.
Uso: python3 volume_por_fase.py gabarito.csv audit.log auth.log syslog volume_por_fase.csv \
         [--excluir-auid 1000] [--excluir-usuario pesquisador]"""
import argparse, csv, re
from datetime import datetime, timedelta, timezone

p = argparse.ArgumentParser()
p.add_argument("gabarito"); p.add_argument("audit"); p.add_argument("auth"); p.add_argument("syslog"); p.add_argument("saida")
p.add_argument("--excluir-auid", nargs="*", default=[])
p.add_argument("--excluir-usuario", nargs="*", default=[])
p.add_argument("--excluir-janela", nargs=2, action="append", default=[], metavar=("INI", "FIM"),
               help="intervalo UTC (ISO) cujos eventos sao descartados; pode repetir")
a = p.parse_args()

def iso(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))

with open(a.gabarito, encoding="utf-8") as f:
    acoes = [r for r in csv.DictReader(f) if r["timestamp_utc"] and r["fase"] in "abcdef"]
inicio_fase = {}
for r in sorted(acoes, key=lambda r: r["timestamp_utc"]):
    inicio_fase.setdefault(r["fase"], iso(r["timestamp_utc"]))
fases = sorted(inicio_fase)
fim = max(iso(r["timestamp_utc"]) for r in acoes) + timedelta(minutes=2)
limites = [(fz, inicio_fase[fz], inicio_fase[fases[i + 1]] if i + 1 < len(fases) else fim) for i, fz in enumerate(fases)]

JANELAS = [(iso(a_).astimezone(timezone.utc), iso(b_).astimezone(timezone.utc)) for a_, b_ in a.excluir_janela]
def na_janela(t):
    return any(ini <= t <= fim for ini, fim in JANELAS)

def fase_de(t):
    for fz, ini, fi in limites:
        if ini <= t < fi:
            return fz
    return None

# Primeira passada: agrupa os registros do auditd por evento (numero de serie)
RE_MSG = re.compile(r"msg=audit\((\d+\.\d+):(\d+)\)")
RE_AUID = re.compile(r"\bauid=(\d+)")
eventos = {}
with open(a.audit, encoding="utf-8", errors="replace") as f:
    for linha in f:
        m = RE_MSG.search(linha)
        if not m:
            continue
        ev = eventos.setdefault(m.group(2), {"ts": float(m.group(1)), "bytes": 0, "auid": None})
        ev["bytes"] += len(linha.encode())
        ma = RE_AUID.search(linha)
        if ma and ev["auid"] is None:
            ev["auid"] = ma.group(1)

cont = {(fz, fonte): [0, 0] for fz in fases for fonte in ("auditd", "auth.log", "syslog")}
excluidos = 0
for ev in eventos.values():
    t_ev = datetime.fromtimestamp(ev["ts"], tz=timezone.utc)
    fz = fase_de(t_ev)
    if not fz:
        continue
    if ev["auid"] in a.excluir_auid or na_janela(t_ev):
        excluidos += 1
        continue
    cont[(fz, "auditd")][0] += 1
    cont[(fz, "auditd")][1] += ev["bytes"]

RE_RFC = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:[+-]\d\d:\d\d|Z))")
linhas_excl = 0
for nome, caminho in (("auth.log", a.auth), ("syslog", a.syslog)):
    with open(caminho, encoding="utf-8", errors="replace") as f:
        for linha in f:
            m = RE_RFC.match(linha)
            if not m:
                continue
            t_l = iso(m.group(1)).astimezone(timezone.utc)
            fz = fase_de(t_l)
            if not fz:
                continue
            if na_janela(t_l) or any(re.search(rf"\b{re.escape(u)}\b", linha) for u in a.excluir_usuario):
                linhas_excl += 1
                continue
            cont[(fz, nome)][0] += 1
            cont[(fz, nome)][1] += len(linha.encode())

with open(a.saida, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["fase", "inicio_utc", "fim_utc", "duracao_s", "fonte", "eventos_ou_linhas", "bytes"])
    for fz, ini, fi in limites:
        for fonte in ("auditd", "auth.log", "syslog"):
            n, by = cont[(fz, fonte)]
            w.writerow([fz, ini.isoformat(), fi.isoformat(), round((fi - ini).total_seconds()), fonte, n, by])
print(f"Volume por fase gravado em {a.saida}")
print(f"Desconsiderados: {excluidos} eventos do auditd e {linhas_excl} linhas de auth.log/syslog do pesquisador")
