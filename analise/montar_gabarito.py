#!/usr/bin/env python3
"""Une o plano de acoes ao horario registrado de cada acao, gerando gabarito.csv.
Uso: python3 montar_gabarito.py plano_acoes.tsv execucao.csv gabarito.csv"""
import csv, sys

plano, execucao, saida = sys.argv[1:4]
with open(plano, encoding="utf-8") as f:
    acoes = list(csv.DictReader(f, delimiter="\t"))
horarios = {}
with open(execucao, encoding="utf-8") as f:
    for r in csv.DictReader(f):
        horarios.setdefault(r["id"].removesuffix("-r"), r["timestamp_utc"])  # primeira marcacao vale
campos = ["id", "fase", "categoria", "descricao", "comando", "usuario", "timestamp_utc"] + \
         [c for c in acoes[0] if c.startswith("esperado_")]
faltando = []
with open(saida, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=campos, extrasaction="ignore")
    w.writeheader()
    for a in acoes:
        a["timestamp_utc"] = horarios.get(a["id"], "")
        if not a["timestamp_utc"]:
            faltando.append(a["id"])
        w.writerow(a)
print(f"{len(acoes)} acoes gravadas em {saida}")
if faltando:
    print("Acoes sem horario registrado:", ", ".join(faltando))
