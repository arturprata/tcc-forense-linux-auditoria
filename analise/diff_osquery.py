#!/usr/bin/env python3
"""Compara snapshots do Osquery (antes x durante, antes x depois) e lista o que surgiu ou sumiu.
Uso: python3 diff_osquery.py pasta_osquery osquery_diff.csv
(pasta_osquery contem as subpastas antes/, durante/ e depois/ geradas por snapshot_osquery.sh)"""
import csv, json, os, sys

CHAVES = {  # colunas usadas para identificar uma linha (ignora valores volateis como pid)
    "usuarios": ["username", "uid", "shell", "directory"],
    "processos": ["name", "cmdline", "uid"],
    "portas_escuta": ["port", "protocol", "address"],
    "conexoes": ["remote_address", "remote_port", "protocol"],
    "crontab": ["minute", "hour", "day_of_month", "month", "day_of_week", "command", "path"],
    "chaves_ssh": ["username", "key_file", "key"],
    "sudoers": ["source", "header", "rule_details"],
    "modulos_kernel": ["name"],
    "ultimos_logins": ["username", "tty", "type", "time", "host"],
    "sessoes_ativas": ["user", "tty", "host", "time"],
    "historico_shell": ["username", "command"],
    "ocultos_home": ["path"], "ocultos_cache": ["path"], "ocultos_tmp": ["path"],
}

def carrega(pasta, nome):
    caminho = os.path.join(pasta, nome + ".json")
    if not os.path.exists(caminho) or os.path.getsize(caminho) == 0:
        return None
    with open(caminho, encoding="utf-8") as f:
        linhas = json.load(f)
    cols = CHAVES.get(nome) or (sorted(linhas[0]) if linhas else [])
    return {tuple((c, r.get(c, "")) for c in cols) for r in linhas}

def ts(pasta):
    with open(os.path.join(pasta, "timestamp_utc.txt")) as f:
        return f.read().strip()

base, saida = sys.argv[1], sys.argv[2]
antes = os.path.join(base, "antes")
total = 0
with open(saida, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["timestamp_utc", "fonte", "tipo", "descricao", "comparacao"])
    for momento in ("durante", "depois"):
        pasta = os.path.join(base, momento)
        if not os.path.isdir(pasta):
            continue
        quando = ts(pasta)
        for nome in sorted(CHAVES):
            a, d = carrega(antes, nome), carrega(pasta, nome)
            if a is None or d is None:
                continue
            for sinal, conj in (("+", d - a), ("-", a - d)):
                for linha in sorted(conj):
                    desc = ", ".join(f"{k}={v}" for k, v in linha)
                    w.writerow([quando, "osquery", f"{nome}{sinal}", desc, f"antes->{momento}"])
                    total += 1
print(f"{total} diferencas gravadas em {saida}")
